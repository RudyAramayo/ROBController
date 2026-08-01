import Foundation

private enum FixtureFailure: Error {
    case failed(String)
}

@main
struct ROBWatchCommandProtocolFixtureTests {
    static func main() throws {
        try testVoiceRoundTrip()
        try testDriveValidationAndReplayFields()
        try testInvalidCommands()
        try testMixer()
        try testDriveEnvelope()
        print("ROB Watch command protocol fixtures passed")
    }

    private static func testInvalidCommands() throws {
        let oversizedVoice = ROBWatchCommand.voice(
            text: String(repeating: "x", count: ROBWatchCommand.maximumVoiceLength + 1),
            senderID: "watch:test",
            sequence: 2
        )
        try expect(oversizedVoice.validationError != nil, "Oversized voice input was accepted")

        let oversizedUTF8Voice = ROBWatchCommand.voice(
            text: String(repeating: "🤖", count: 700),
            senderID: "watch:test",
            sequence: 3
        )
        try expect(oversizedUTF8Voice.validationError != nil, "Oversized UTF-8 voice input was accepted")

        let outOfRangeDrive = ROBWatchCommand(
            schema: ROBWatchCommand.schema,
            version: ROBWatchCommand.currentVersion,
            kind: .driveUpdate,
            messageID: UUID().uuidString,
            senderID: "watch:test",
            sessionID: UUID().uuidString,
            sequence: 4,
            sentAtMilliseconds: ROBWatchCommand.nowMilliseconds,
            joystickX: 1.01,
            joystickY: 0,
            text: nil
        )
        try expect(outOfRangeDrive.validationError != nil, "Out-of-range joystick input was accepted")
    }

    private static func testVoiceRoundTrip() throws {
        let command = ROBWatchCommand.voice(text: "Hey Rob, look over here", senderID: "watch:test", sequence: 1)
        let decoded = try ROBWatchCommand.decode(command.encoded())
        try expect(decoded == command, "Voice command did not round-trip")
        try expect(decoded.validationError == nil, "Valid voice command was rejected")
    }

    private static func testDriveValidationAndReplayFields() throws {
        let sessionID = UUID().uuidString
        let command = ROBWatchCommand.drive(
            kind: .driveUpdate,
            sessionID: sessionID,
            senderID: "watch:test",
            sequence: 42,
            joystickX: 0.25,
            joystickY: -0.5
        )
        let decoded = try ROBWatchCommand.decode(command.encoded())
        try expect(decoded.sessionID == sessionID, "Drive session ID changed")
        try expect(decoded.sequence == 42, "Drive sequence changed")
        try expect(decoded.sentAtMilliseconds > 0, "Drive timestamp is missing")
    }

    private static func testMixer() throws {
        try expect(ROBWatchTreadMixer.mix(x: 0, y: 0) == .neutral, "Centered stick is not neutral")
        let forward = ROBWatchTreadMixer.mix(x: 0, y: 1)
        try expect(forward.left == 1 && forward.right == 1, "Forward mix is incorrect")
        let reverse = ROBWatchTreadMixer.mix(x: 0, y: -1)
        try expect(reverse.left == -1 && reverse.right == -1, "Reverse mix is incorrect")
        let right = ROBWatchTreadMixer.mix(x: 1, y: 0)
        try expect(right.left == 1 && right.right == -1, "Right-turn mix is incorrect")
        let diagonal = ROBWatchTreadMixer.mix(x: 1, y: 1)
        try expect(abs(diagonal.left) <= 1 && abs(diagonal.right) <= 1, "Mixer did not normalize")
    }

    private static func testDriveEnvelope() throws {
        let moving = try ROBWatchRobotWireCodec.archiveDriveSnapshot(
            mix: ROBWatchTreadMix(left: 1, right: -1),
            brake: false,
            senderID: "watch:test"
        )
        let allowedClasses: [AnyClass] = [NSDictionary.self, NSString.self]
        let movingEnvelope = try NSKeyedUnarchiver.unarchivedObject(
            ofClasses: allowedClasses,
            from: moving
        ) as? [String: String]
        try expect(movingEnvelope?["message"] == ROBWatchRobotWireCodec.driveMessageMarker, "Drive marker changed")
        try expect(movingEnvelope?[ROBWatchRobotWireCodec.driveLeftKey] == "1.00000", "Left tread encoding changed")
        try expect(movingEnvelope?[ROBWatchRobotWireCodec.driveRightKey] == "-1.00000", "Right tread encoding changed")
        try expect(movingEnvelope?[ROBWatchRobotWireCodec.driveBrakeKey] == "0", "Moving envelope unexpectedly brakes")

        let stopped = try ROBWatchRobotWireCodec.archiveDriveSnapshot(
            mix: .neutral,
            brake: true,
            senderID: "watch:test"
        )
        let stoppedEnvelope = try NSKeyedUnarchiver.unarchivedObject(
            ofClasses: allowedClasses,
            from: stopped
        ) as? [String: String]
        try expect(stoppedEnvelope?[ROBWatchRobotWireCodec.driveLeftKey] == "0.00000", "Stop envelope has tread motion")
        try expect(stoppedEnvelope?[ROBWatchRobotWireCodec.driveBrakeKey] == "1", "Stop envelope lacks tread brake")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw FixtureFailure.failed(message) }
    }
}
