//
//  ROBWatchCommandProtocol.swift
//  ROBController
//
//  Small, versioned messages sent only between the companion Watch app and
//  ROBController. ROBController validates them before forwarding a bounded
//  controller snapshot over the authenticated ROBControl v2 connection.
//

import Foundation

enum ROBWatchCommandKind: String, Codable {
    case voiceText = "voice_text"
    case driveBegin = "drive_begin"
    case driveUpdate = "drive_update"
    case driveEnd = "drive_end"
}

struct ROBWatchCommand: Codable, Equatable {
    static let schema = "com.orbitusrobotics.rob-watch-command"
    static let currentVersion = 1
    static let maximumEncodedSize = 4_096
    static let maximumVoiceLength = 1_024
    static let maximumVoiceUTF8Size = 2_048

    let schema: String
    let version: Int
    let kind: ROBWatchCommandKind
    let messageID: String
    let senderID: String
    let sessionID: String?
    let sequence: UInt64
    let sentAtMilliseconds: Int64
    let joystickX: Double?
    let joystickY: Double?
    let text: String?

    static func voice(text: String, senderID: String, sequence: UInt64) -> ROBWatchCommand {
        ROBWatchCommand(
            schema: schema,
            version: currentVersion,
            kind: .voiceText,
            messageID: UUID().uuidString,
            senderID: senderID,
            sessionID: nil,
            sequence: sequence,
            sentAtMilliseconds: nowMilliseconds,
            joystickX: nil,
            joystickY: nil,
            text: text
        )
    }

    static func drive(
        kind: ROBWatchCommandKind,
        sessionID: String,
        senderID: String,
        sequence: UInt64,
        joystickX: Double? = nil,
        joystickY: Double? = nil
    ) -> ROBWatchCommand {
        precondition(kind == .driveBegin || kind == .driveUpdate || kind == .driveEnd)
        return ROBWatchCommand(
            schema: schema,
            version: currentVersion,
            kind: kind,
            messageID: UUID().uuidString,
            senderID: senderID,
            sessionID: sessionID,
            sequence: sequence,
            sentAtMilliseconds: nowMilliseconds,
            joystickX: joystickX,
            joystickY: joystickY,
            text: nil
        )
    }

    var validationError: String? {
        guard schema == Self.schema, version == Self.currentVersion else {
            return "unsupported Watch command schema or version"
        }
        guard !messageID.isEmpty, messageID.count <= 128,
              !senderID.isEmpty, senderID.count <= 128,
              sequence > 0,
              sentAtMilliseconds > 0 else {
            return "invalid Watch command identity or sequence"
        }

        switch kind {
        case .voiceText:
            guard sessionID == nil, joystickX == nil, joystickY == nil,
                  let text,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  text.count <= Self.maximumVoiceLength,
                  text.utf8.count <= Self.maximumVoiceUTF8Size else {
                return "invalid Watch voice text"
            }

        case .driveBegin, .driveUpdate:
            guard let sessionID,
                  UUID(uuidString: sessionID) != nil,
                  let joystickX,
                  let joystickY,
                  joystickX.isFinite,
                  joystickY.isFinite,
                  (-1.0 ... 1.0).contains(joystickX),
                  (-1.0 ... 1.0).contains(joystickY),
                  text == nil else {
                return "invalid Watch joystick snapshot"
            }

        case .driveEnd:
            guard let sessionID,
                  UUID(uuidString: sessionID) != nil,
                  joystickX == nil,
                  joystickY == nil,
                  text == nil else {
                return "invalid Watch drive-end command"
            }
        }
        return nil
    }

    func encoded() throws -> Data {
        guard let validationError = validationError else {
            let data = try JSONEncoder().encode(self)
            guard data.count <= Self.maximumEncodedSize else {
                throw ROBWatchCommandError.invalid("Watch command exceeds 4 KiB")
            }
            return data
        }
        throw ROBWatchCommandError.invalid(validationError)
    }

    static func decode(_ data: Data) throws -> ROBWatchCommand {
        guard !data.isEmpty, data.count <= maximumEncodedSize else {
            throw ROBWatchCommandError.invalid("Watch command payload is empty or oversized")
        }
        let command = try JSONDecoder().decode(ROBWatchCommand.self, from: data)
        if let validationError = command.validationError {
            throw ROBWatchCommandError.invalid(validationError)
        }
        return command
    }

    static var nowMilliseconds: Int64 {
        Int64((Date().timeIntervalSince1970 * 1_000).rounded())
    }
}

struct ROBWatchTreadMix: Equatable {
    let left: Double
    let right: Double

    static let neutral = ROBWatchTreadMix(left: 0, right: 0)
}

enum ROBWatchTreadMixer {
    static let deadZone = 0.12

    /// Converts one normalized stick into two differential tread values.
    /// Positive y is forward and positive x turns right.
    static func mix(x: Double, y: Double) -> ROBWatchTreadMix {
        guard x.isFinite, y.isFinite else { return .neutral }
        let limitedX = max(-1, min(1, x))
        let limitedY = max(-1, min(1, y))
        let magnitude = hypot(limitedX, limitedY)
        guard magnitude > deadZone else { return .neutral }

        let radialScale = min(1, magnitude)
        let normalizedX = limitedX / magnitude * radialScale
        let normalizedY = limitedY / magnitude * radialScale
        let activeScale = (radialScale - deadZone) / (1 - deadZone)
        let turn = normalizedX * activeScale / radialScale
        let forward = normalizedY * activeScale / radialScale

        var left = forward + turn
        var right = forward - turn
        let normalization = max(1, abs(left), abs(right))
        left /= normalization
        right /= normalization
        return ROBWatchTreadMix(left: left, right: right)
    }
}

enum ROBWatchRobotWireCodec {
    static let connectivityCommandKey = "rob.watch.command"
    static let replyAcceptedKey = "accepted"
    static let replyStatusKey = "status"
    static let voiceMessageMarker = "ROBWatchVoiceText"
    static let voiceTextKey = "watch.text"
    static let driveMessageMarker = "ROBWatchDriveSnapshotV1"
    static let driveVersionKey = "watch.drive.version"
    static let driveLeftKey = "watch.drive.left"
    static let driveRightKey = "watch.drive.right"
    static let driveSpeedKey = "watch.drive.speed"
    static let driveBrakeKey = "watch.drive.brake"
    static let requestControlMessage = "RequestToBeMasterController"
    static let releaseControlMessage = "ReleaseMasterController"

    static func archive(message: String, senderID: String, extra: [String: String] = [:]) throws -> Data {
        var envelope = extra
        envelope["message"] = message
        envelope["sender"] = senderID
        return try NSKeyedArchiver.archivedData(
            withRootObject: envelope as NSDictionary,
            requiringSecureCoding: false
        )
    }

    /// Creates a dedicated Watch-drive envelope. Cerebro validates every field
    /// before constructing a controller model, avoiding its legacy line parser.
    static func archiveDriveSnapshot(
        mix: ROBWatchTreadMix,
        brake: Bool,
        senderID: String,
        maximumSpeedPercent: Double = 35
    ) throws -> Data {
        let left = brake ? 0.0 : max(-1, min(1, mix.left))
        let right = brake ? 0.0 : max(-1, min(1, mix.right))
        let speed = max(5, min(35, maximumSpeedPercent))
        let locale = Locale(identifier: "en_US_POSIX")
        return try archive(
            message: driveMessageMarker,
            senderID: senderID,
            extra: [
                driveVersionKey: "1",
                driveLeftKey: String(format: "%.5f", locale: locale, left),
                driveRightKey: String(format: "%.5f", locale: locale, right),
                driveSpeedKey: String(format: "%.1f", locale: locale, speed),
                driveBrakeKey: brake ? "1" : "0"
            ]
        )
    }
}

private enum ROBWatchCommandError: LocalizedError {
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .invalid(let detail): return "Invalid Watch command: \(detail)"
        }
    }
}
