import Foundation
import Network

/// Exercises the real client and framer without a robot, Keychain, or TLS identity.
/// Only this fixture uses loopback TCP; production continues to use pinned QUIC.
@main
struct ROBControlHandshakeIntegrationTests {
    enum Scenario: CaseIterable {
        case noChallenge, noAcceptance, rejectHello, rejectProof, sessionInUse, invalidProof, accepted
    }

    static func parameters() -> NWParameters {
        let parameters = NWParameters.tcp
        parameters.defaultProtocolStack.applicationProtocols.insert(
            NWProtocolFramer.Options(definition: ROBV2ControlFramer.definition), at: 0
        )
        return parameters
    }

    static func main() throws {
        for scenario in Scenario.allCases {
            try run(scenario)
        }
        print("ROBController handshake integration tests passed (7 scenarios)")
    }

    static func run(_ scenario: Scenario) throws {
        let credential = ROBControlCredential(
            version: 2, robotID: UUID(), controllerID: UUID(),
            serviceType: ROBControlPairing.serviceType,
            applicationProtocol: ROBControlPairing.applicationProtocol,
            certificateSHA256: Data(repeating: 0xA5, count: 32),
            sharedSecret: Data((0..<32).map(UInt8.init))
        )
        let challenge = try ROBControlAuthenticator.makeChallenge(robotID: credential.robotID)
        let serverQueue = DispatchQueue(label: "rob.handshake.fixture")
        let ready = DispatchSemaphore(value: 0)
        let finished = DispatchSemaphore(value: 0)
        let releaseReadinessCallback = DispatchSemaphore(value: 0)
        let stopped = DispatchSemaphore(value: 0)
        let listenerParameters = parameters()
        listenerParameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        let listener = try NWListener(using: listenerParameters)
        var server: NWConnection?
        listener.stateUpdateHandler = { state in
            if case .ready = state { ready.signal() }
            if case .failed(let error) = state { fatalError("Listener failed: \(error)") }
        }
        listener.newConnectionHandler = { connection in
            server = connection
            connection.start(queue: serverQueue)
            receive(connection, type: .pairingHello) { hello in
                precondition(String(data: hello.prefix(36), encoding: .utf8)
                    == credential.controllerID.uuidString.lowercased())
                if scenario == .noChallenge { return }
                if scenario == .rejectHello {
                    send(connection, type: .pairingRejected, data: Data([1]))
                    return
                }
                send(connection, type: .pairingChallenge, data: challenge.encoded)
                receive(connection, type: .pairingProof) { data in
                    guard let proof = ROBControlAuthProof(data) else {
                        fatalError("Client sent malformed proof")
                    }
                    precondition(ROBControlAuthenticator.validate(
                        proof, challenge: challenge, credential: credential))
                    if scenario == .noAcceptance { return }
                    if scenario == .rejectProof {
                        send(connection, type: .pairingRejected, data: Data([1]))
                        return
                    }
                    if scenario == .sessionInUse {
                        send(connection, type: .pairingRejected,
                             data: ROBControlPairingRejectionReason.sessionInUse.encoded)
                        return
                    }
                    var accepted = ROBControlAuthenticator.accepted(
                        for: proof, challenge: challenge, credential: credential).encoded
                    if scenario == .invalidProof { accepted[accepted.count - 1] ^= 0xFF }
                    send(connection, type: .pairingAccepted, data: accepted)
                }
            }
        }
        listener.start(queue: serverQueue)
        precondition(ready.wait(timeout: .now() + 10) == .success, "Listener did not start")
        let transport = NWConnection(host: "127.0.0.1", port: listener.port!, using: parameters())
        var client: AutoNetClientConnection? = AutoNetClientConnection(
            nwConnection: transport,
            transportMode: .v2, credential: credential
        )
        client?.readinessDidChangeCallback = { [weak client] isReady in
            guard isReady else { return }
            precondition(scenario == .accepted, "Failed handshake became authenticated")
            precondition(client?.authenticatedSessionUUID != nil)
            finished.signal()
            // Hold the transport queue while the facade queues stop() and
            // releases its connection, exactly as Reconnect does in the app.
            precondition(releaseReadinessCallback.wait(timeout: .now() + 5) == .success)
        }
        client?.didStopCallback = { [weak client] error in
            if scenario == .accepted {
                precondition(error == nil)
                precondition(client?.authenticatedSessionUUID == nil)
                stopped.signal()
                return
            }
            switch (scenario, error as? AutoNetTransportError) {
            case (.noChallenge, .authenticationTimedOut(.awaitingChallenge)),
                 (.noAcceptance, .authenticationTimedOut(.awaitingAcceptance)),
                 (.rejectHello, .pairingRejected),
                 (.rejectProof, .pairingRejected),
                 (.sessionInUse, .pairingSessionInUse),
                 (.invalidProof, .authenticationFailed):
                break
            default:
                fatalError("Unexpected result for \(scenario): \(String(describing: error))")
            }
            precondition(client?.authenticatedSessionUUID == nil)
            finished.signal()
        }
        client?.start()
        precondition(finished.wait(timeout: .now() + 12) == .success, "Handshake never completed")
        client?.stop()
        client = nil
        if scenario == .accepted {
            releaseReadinessCallback.signal()
            precondition(stopped.wait(timeout: .now() + 5) == .success,
                         "Reconnect must finish session cleanup after releasing the connection")
            // NWConnection publishes its cancelled state asynchronously, after
            // the application cleanup callback has returned on the queue.
            let cancellationDeadline = Date().addingTimeInterval(2)
            while transport.state != .cancelled && Date() < cancellationDeadline {
                Thread.sleep(forTimeInterval: 0.01)
            }
            precondition(transport.state == .cancelled,
                         "Reconnect must cancel its old transport after releasing the connection")
        }
        serverQueue.sync {
            server?.cancel()
            listener.cancel()
        }
        print("Passed: \(scenario)")
    }

    static func send(_ connection: NWConnection, type: DataMessageType, data: Data) {
        let context = NWConnection.ContentContext(
            identifier: "fixture", metadata: [AutoNetTransportMode.v2.makeMessage(type: type)])
        connection.send(content: data, contentContext: context, isComplete: true,
                        completion: .contentProcessed { error in
            precondition(error == nil, "Fixture send failed: \(String(describing: error))")
        })
    }

    static func receive(_ connection: NWConnection, type: DataMessageType,
                        completion: @escaping (Data) -> Void) {
        connection.receiveMessage { data, context, _, error in
            precondition(error == nil)
            precondition(AutoNetTransportMode.v2.messageType(from: context) == type)
            guard let data else { fatalError("Missing fixture message") }
            completion(data)
        }
    }
}
