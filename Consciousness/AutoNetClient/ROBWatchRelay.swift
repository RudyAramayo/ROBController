//
//  ROBWatchRelay.swift
//  ROBController
//

#if os(iOS)
import Foundation
import UIKit
import WatchConnectivity

/// Validates immediate Watch commands and forwards them through the iPhone's
/// already paired ROBControl v2 connection. Motion is never queued for later.
@objcMembers public final class ROBWatchRelay: NSObject, WCSessionDelegate {
    private weak var autoNetClient: AutoNetClient?
    private let session: WCSession?
    private var activeDriveSessionID: String?
    private var activeDriveSenderID: String?
    private var lastDriveSequence: UInt64 = 0
    private var lastAcceptedDriveSequenceBySender: [String: UInt64] = [:]
    private var lastAcceptedVoiceSequenceBySender: [String: UInt64] = [:]
    private var lastDriveReceivedAt: TimeInterval = 0
    private var driveWatchdog: Timer?
    private var applicationObserver: NSObjectProtocol?

    private static let maximumDriveAgeMilliseconds: Int64 = 400
    private static let maximumVoiceAgeMilliseconds: Int64 = 30_000
    private static let driveWatchdogInterval: TimeInterval = 0.45

    @objc(initWithAutoNetClient:)
    public init(autoNetClient: AutoNetClient) {
        self.autoNetClient = autoNetClient
        self.session = WCSession.isSupported() ? WCSession.default : nil
        super.init()

        session?.delegate = self
        session?.activate()
        applicationObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopDrive(reason: "ROBController entered the background")
        }
    }

    deinit {
        stopDrive(reason: "Watch relay shut down")
        if let applicationObserver {
            NotificationCenter.default.removeObserver(applicationObserver)
        }
        driveWatchdog?.invalidate()
    }

    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("Watch relay activation failed: \(error.localizedDescription)")
        }
    }

    public func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.stopDrive(reason: "Watch session became inactive")
        }
    }

    public func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.stopDrive(reason: "Watch session deactivated")
            session.activate()
        }
    }

    public func sessionReachabilityDidChange(_ session: WCSession) {
        guard !session.isReachable else { return }
        DispatchQueue.main.async { [weak self] in
            self?.stopDrive(reason: "Apple Watch became unreachable")
        }
    }

    public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        receive(message, replyHandler: nil)
    }

    public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        receive(message, replyHandler: replyHandler)
    }

    private func receive(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)?
    ) {
        guard let payload = message[ROBWatchRobotWireCodec.connectivityCommandKey] as? Data,
              let command = try? ROBWatchCommand.decode(payload) else {
            replyHandler?([
                ROBWatchRobotWireCodec.replyAcceptedKey: false,
                ROBWatchRobotWireCodec.replyStatusKey: "Invalid Watch command"
            ])
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                replyHandler?([
                    ROBWatchRobotWireCodec.replyAcceptedKey: false,
                    ROBWatchRobotWireCodec.replyStatusKey: "ROBController is unavailable"
                ])
                return
            }
            let result = self.handle(command)
            replyHandler?([
                ROBWatchRobotWireCodec.replyAcceptedKey: result.accepted,
                ROBWatchRobotWireCodec.replyStatusKey: result.status
            ])
        }
    }

    private func handle(_ command: ROBWatchCommand) -> (accepted: Bool, status: String) {
        guard let autoNetClient, autoNetClient.isConnected else {
            if command.kind != .voiceText {
                stopDrive(reason: "Cerebro connection is unavailable")
            }
            return (false, "Open ROBController and connect to Cerebro")
        }

        switch command.kind {
        case .voiceText:
            guard isFresh(command, maximumAgeMilliseconds: Self.maximumVoiceAgeMilliseconds),
                  command.sequence > (lastAcceptedVoiceSequenceBySender[command.senderID] ?? 0),
                  let text = command.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else {
                return (false, "Voice text is stale, empty, or already received")
            }
            do {
                let data = try ROBWatchRobotWireCodec.archive(
                    message: ROBWatchRobotWireCodec.voiceMessageMarker,
                    senderID: command.senderID,
                    extra: [ROBWatchRobotWireCodec.voiceTextKey: text]
                )
                autoNetClient.send(data: data)
                lastAcceptedVoiceSequenceBySender[command.senderID] = command.sequence
                return (true, "Voice text sent")
            } catch {
                return (false, error.localizedDescription)
            }

        case .driveBegin:
            guard UIApplication.shared.applicationState == .active,
                  isFresh(command, maximumAgeMilliseconds: Self.maximumDriveAgeMilliseconds),
                  command.sequence > (lastAcceptedDriveSequenceBySender[command.senderID] ?? 0),
                  let sessionID = command.sessionID,
                  let x = command.joystickX,
                  let y = command.joystickY else {
                return (false, "Drive command is stale or ROBController is not active")
            }
            if activeDriveSessionID != nil {
                stopDrive(reason: "Replaced by a fresh Watch touch")
            }
            activeDriveSessionID = sessionID
            activeDriveSenderID = command.senderID
            lastDriveSequence = command.sequence
            lastAcceptedDriveSequenceBySender[command.senderID] = command.sequence
            lastDriveReceivedAt = ProcessInfo.processInfo.systemUptime
            sendRobotMessage(ROBWatchRobotWireCodec.requestControlMessage, senderID: command.senderID)
            sendDriveSnapshot(x: x, y: y, senderID: command.senderID)
            startDriveWatchdog()
            return (true, "Watch has tread control while the joystick is held")

        case .driveUpdate:
            guard UIApplication.shared.applicationState == .active,
                  isFresh(command, maximumAgeMilliseconds: Self.maximumDriveAgeMilliseconds),
                  command.sessionID == activeDriveSessionID,
                  command.senderID == activeDriveSenderID,
                  command.sequence > lastDriveSequence,
                  let x = command.joystickX,
                  let y = command.joystickY else {
                return (false, "Stale or out-of-order drive snapshot")
            }
            lastDriveSequence = command.sequence
            lastAcceptedDriveSequenceBySender[command.senderID] = command.sequence
            lastDriveReceivedAt = ProcessInfo.processInfo.systemUptime
            sendDriveSnapshot(x: x, y: y, senderID: command.senderID)
            return (true, "Driving")

        case .driveEnd:
            guard command.sessionID == activeDriveSessionID,
                  command.senderID == activeDriveSenderID,
                  command.sequence > lastDriveSequence else {
                return (false, "Drive session is no longer active")
            }
            lastAcceptedDriveSequenceBySender[command.senderID] = command.sequence
            stopDrive(reason: "Watch joystick released")
            return (true, "Treads stopped")
        }
    }

    private func startDriveWatchdog() {
        driveWatchdog?.invalidate()
        driveWatchdog = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, self.activeDriveSessionID != nil else { return }
            if ProcessInfo.processInfo.systemUptime - self.lastDriveReceivedAt > Self.driveWatchdogInterval {
                self.stopDrive(reason: "Watch joystick heartbeat expired")
            }
        }
    }

    private func sendDriveSnapshot(x: Double, y: Double, senderID: String) {
        let mix = ROBWatchTreadMixer.mix(x: x, y: y)
        guard let data = try? ROBWatchRobotWireCodec.archiveDriveSnapshot(
            mix: mix,
            brake: mix == .neutral,
            senderID: senderID
        ) else { return }
        autoNetClient?.send(data: data)
    }

    private func isFresh(_ command: ROBWatchCommand, maximumAgeMilliseconds: Int64) -> Bool {
        let now = ROBWatchCommand.nowMilliseconds
        return command.sentAtMilliseconds >= now - maximumAgeMilliseconds
            && command.sentAtMilliseconds <= now + maximumAgeMilliseconds
    }

    private func stopDrive(reason: String) {
        guard let senderID = activeDriveSenderID else { return }
        driveWatchdog?.invalidate()
        driveWatchdog = nil
        if let data = try? ROBWatchRobotWireCodec.archiveDriveSnapshot(
            mix: .neutral,
            brake: true,
            senderID: senderID
        ) {
            autoNetClient?.send(data: data)
        }
        sendRobotMessage(ROBWatchRobotWireCodec.releaseControlMessage, senderID: senderID)
        activeDriveSessionID = nil
        activeDriveSenderID = nil
        lastDriveSequence = 0
        lastDriveReceivedAt = 0
        print("Watch drive stopped: \(reason)")
    }

    private func sendRobotMessage(_ message: String, senderID: String) {
        guard let data = try? ROBWatchRobotWireCodec.archive(message: message, senderID: senderID) else {
            return
        }
        autoNetClient?.send(data: data)
    }
}
#endif
