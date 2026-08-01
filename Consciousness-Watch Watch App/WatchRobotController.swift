//
//  WatchRobotController.swift
//  Consciousness-Watch Watch App
//

import Combine
import Foundation
import WatchConnectivity

final class WatchRobotController: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var phoneReachable = false
    @Published private(set) var status = "Connecting to iPhone…"
    @Published private(set) var isDriving = false
    @Published private(set) var joystickX = 0.0
    @Published private(set) var joystickY = 0.0
    @Published private(set) var lastVoiceText = ""

    private let session: WCSession?
    private let senderID: String
    private var commandSequence: UInt64
    private var commandSequenceReservationEnd: UInt64
    private var driveSessionID: String?
    private var lastEndedDriveSessionID: String?
    private var driveTimer: Timer?

    override init() {
        self.session = WCSession.isSupported() ? WCSession.default : nil
        self.senderID = Self.loadOrCreateSenderID()
        let reservation = Self.reserveCommandSequenceRange()
        self.commandSequence = reservation.start
        self.commandSequenceReservationEnd = reservation.end
        super.init()
        session?.delegate = self
        session?.activate()
        refreshReachability()
    }

    deinit {
        driveTimer?.invalidate()
    }

    func sendVoiceText(_ input: String) {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= ROBWatchCommand.maximumVoiceLength else {
            status = "Dictate a shorter message"
            return
        }
        guard phoneReachable else {
            status = "Open ROBController on iPhone"
            return
        }

        lastVoiceText = text
        let command = ROBWatchCommand.voice(
            text: text,
            senderID: senderID,
            sequence: nextSequence()
        )
        send(command, expectsReply: true)
    }

    func updateJoystick(x: Double, y: Double) {
        guard phoneReachable else {
            stopDriving(sendEnd: false, status: "Open ROBController on iPhone")
            return
        }
        joystickX = max(-1, min(1, x))
        joystickY = max(-1, min(1, y))

        if driveSessionID == nil {
            driveSessionID = UUID().uuidString
            lastEndedDriveSessionID = nil
            isDriving = true
            let begin = ROBWatchCommand.drive(
                kind: .driveBegin,
                sessionID: driveSessionID!,
                senderID: senderID,
                sequence: nextSequence(),
                joystickX: joystickX,
                joystickY: joystickY
            )
            send(begin, expectsReply: true)
            startDriveTimer()
        }
    }

    func endJoystickTouch() {
        stopDriving(sendEnd: true, status: "Treads stopped")
    }

    func applicationBecameInactive() {
        stopDriving(sendEnd: true, status: "Treads stopped")
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async { [weak self] in
            if let error {
                self?.status = "iPhone link: \(error.localizedDescription)"
            }
            self?.refreshReachability()
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.refreshReachability()
            if !session.isReachable {
                self?.stopDriving(sendEnd: false, status: "iPhone unreachable; treads stopped")
            }
        }
    }

    private func startDriveTimer() {
        driveTimer?.invalidate()
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self,
                  let driveSessionID = self.driveSessionID,
                  self.phoneReachable else { return }
            let update = ROBWatchCommand.drive(
                kind: .driveUpdate,
                sessionID: driveSessionID,
                senderID: self.senderID,
                sequence: self.nextSequence(),
                joystickX: self.joystickX,
                joystickY: self.joystickY
            )
            self.send(update, expectsReply: true)
        }
        driveTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopDriving(sendEnd: Bool, status: String) {
        let endingSessionID = driveSessionID
        driveTimer?.invalidate()
        driveTimer = nil
        driveSessionID = nil
        if let endingSessionID {
            lastEndedDriveSessionID = endingSessionID
        }
        isDriving = false
        joystickX = 0
        joystickY = 0
        self.status = status

        guard sendEnd, phoneReachable, let endingSessionID else { return }
        let end = ROBWatchCommand.drive(
            kind: .driveEnd,
            sessionID: endingSessionID,
            senderID: senderID,
            sequence: nextSequence()
        )
        send(end, expectsReply: true)
    }

    private func send(_ command: ROBWatchCommand, expectsReply: Bool) {
        guard let session,
              session.activationState == .activated,
              session.isReachable else {
            status = "Open ROBController on iPhone"
            return
        }

        let payload: Data
        do {
            payload = try command.encoded()
        } catch {
            status = error.localizedDescription
            if isCurrentDriveCommand(command) {
                stopDriving(sendEnd: false, status: "Invalid drive command; treads stopped")
            }
            return
        }

        let message: [String: Any] = [ROBWatchRobotWireCodec.connectivityCommandKey: payload]
        let errorHandler: (Error) -> Void = { [weak self] error in
            DispatchQueue.main.async {
                guard let self, self.shouldApplyStatus(for: command) else { return }
                if self.isCurrentDriveCommand(command) {
                    self.stopDriving(sendEnd: false, status: "iPhone link lost; treads stopped")
                } else {
                    self.status = error.localizedDescription
                }
            }
        }

        if expectsReply {
            session.sendMessage(message, replyHandler: { [weak self] reply in
                DispatchQueue.main.async {
                    guard let self, self.shouldApplyStatus(for: command) else { return }
                    let accepted = reply[ROBWatchRobotWireCodec.replyAcceptedKey] as? Bool ?? false
                    let replyStatus = reply[ROBWatchRobotWireCodec.replyStatusKey] as? String
                        ?? (accepted ? "Sent" : "Command rejected")
                    if !accepted, self.isCurrentDriveCommand(command) {
                        self.stopDriving(sendEnd: false, status: replyStatus)
                    } else {
                        self.status = replyStatus
                    }
                }
            }, errorHandler: errorHandler)
        } else {
            session.sendMessage(message, replyHandler: nil, errorHandler: errorHandler)
        }
    }

    private func refreshReachability() {
        let reachable = session?.activationState == .activated && session?.isReachable == true
        phoneReachable = reachable
        if !isDriving {
            status = reachable ? "ROBController ready" : "Open ROBController on iPhone"
        }
    }

    private func nextSequence() -> UInt64 {
        if commandSequence >= commandSequenceReservationEnd {
            let reservation = Self.reserveCommandSequenceRange(startingAfter: commandSequence)
            commandSequence = reservation.start
            commandSequenceReservationEnd = reservation.end
        }
        commandSequence &+= 1
        if commandSequence == 0 { commandSequence = 1 }
        return commandSequence
    }

    private func isCurrentDriveCommand(_ command: ROBWatchCommand) -> Bool {
        (command.kind == .driveBegin || command.kind == .driveUpdate)
            && command.sessionID == driveSessionID
    }

    private func shouldApplyStatus(for command: ROBWatchCommand) -> Bool {
        switch command.kind {
        case .voiceText:
            return !isDriving
        case .driveBegin, .driveUpdate:
            return command.sessionID == driveSessionID
        case .driveEnd:
            return driveSessionID == nil && command.sessionID == lastEndedDriveSessionID
        }
    }

    private static func reserveCommandSequenceRange(
        startingAfter floor: UInt64 = 0
    ) -> (start: UInt64, end: UInt64) {
        let key = "ROBWatchCommandSequence"
        let stored = UserDefaults.standard.string(forKey: key).flatMap(UInt64.init) ?? 0
        let start = max(stored, floor)
        let reservationSize: UInt64 = 1_000_000
        let end = start <= UInt64.max - reservationSize
            ? start + reservationSize
            : UInt64.max
        UserDefaults.standard.set(String(end), forKey: key)
        return (start, end)
    }

    private static func loadOrCreateSenderID() -> String {
        let key = "ROBWatchControllerSenderID"
        if let existing = UserDefaults.standard.string(forKey: key),
           UUID(uuidString: existing.replacingOccurrences(of: "watch:", with: "")) != nil {
            return existing
        }
        let senderID = "watch:\(UUID().uuidString.lowercased())"
        UserDefaults.standard.set(senderID, forKey: key)
        return senderID
    }
}
