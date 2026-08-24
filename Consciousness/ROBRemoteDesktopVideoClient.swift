import CryptoKit
import Foundation
import Network
import Security

protocol ROBRemoteDesktopVideoClientDelegate: AnyObject {
    func remoteDesktopVideoClient(_ client: ROBRemoteDesktopVideoClient, didReceiveJPEG data: Data)
    func remoteDesktopVideoClient(_ client: ROBRemoteDesktopVideoClient, didChangeStatus status: String)
}

/// A narrow robvideo/1 client dedicated to Cerebro's Administrator desktop.
/// JPEG media remains on its own QUIC connection so it cannot head-of-line
/// block steering, stop, terminal, or synthesized-input messages.
final class ROBRemoteDesktopVideoClient {
    private enum Phase {
        case idle
        case awaitingChallenge
        case awaitingAccepted(DesktopAuthChallenge, DesktopAuthProof)
        case awaitingCapabilities
        case awaitingSubscription
        case streaming
        case stopped
    }

    private static let serviceType = "_robvideo._udp"
    private static let applicationProtocol = "robvideo/1"
    private static let protocolVersion: UInt8 = 1
    private static let maximumFrameBytes = (2 * 1_024 * 1_024) + 92
    private static let verifyQueue = DispatchQueue(
        label: "com.orbitusrobotics.robcontroller.desktop.tls-verify"
    )

    weak var delegate: ROBRemoteDesktopVideoClientDelegate?

    private let queue = DispatchQueue(
        label: "com.orbitusrobotics.robcontroller.desktop-video",
        qos: .userInitiated
    )
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var credential: ROBControlCredential?
    private var controlSessionID: UUID?
    private var subscriptionID: UUID?
    private var phase: Phase = .idle
    private var wantsStarted = false
    private var reconnectAttempt = 0
    private var reconnectWorkItem: DispatchWorkItem?
    private var lastMediaSequence: UInt64 = 0

    func start(controlSessionID: UUID) {
        queue.async { [weak self] in
            guard let self else { return }
            self.stopLocked(publish: false)
            do {
                self.credential = try ROBControlPairing.clientAuthenticationMaterial()
            } catch {
                self.publish("Desktop pairing unavailable: \(error.localizedDescription)")
                return
            }
            self.controlSessionID = controlSessionID
            self.subscriptionID = UUID()
            self.wantsStarted = true
            self.reconnectAttempt = 0
            self.beginBrowsing()
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.wantsStarted = false
            self?.stopLocked(publish: true)
        }
    }

    private func beginBrowsing() {
        guard wantsStarted, connection == nil, browser == nil else { return }
        phase = .idle
        publish("Finding Cerebro desktop…")
        let parameters = NWParameters.udp
        parameters.includePeerToPeer = true
        let browser = NWBrowser(
            for: .bonjour(type: Self.serviceType, domain: nil),
            using: parameters
        )
        self.browser = browser
        browser.stateUpdateHandler = { [weak self, weak browser] state in
            guard let self, let browser, self.browser === browser else { return }
            switch state {
            case .failed(let error): self.fail("Desktop discovery failed: \(error.localizedDescription)")
            case .waiting(let error): self.publish("Waiting for desktop video: \(error.localizedDescription)")
            default: break
            }
        }
        browser.browseResultsChangedHandler = { [weak self, weak browser] results, _ in
            guard let self, let browser, self.browser === browser,
                  self.connection == nil,
                  let pairedRobotID = self.credential?.robotID else { return }
            let matches = results.filter {
                ROBControlPairing.robotID(fromBonjourMetadata: $0.metadata) == pairedRobotID
            }
            let selected = matches
                .sorted { $0.endpoint.debugDescription < $1.endpoint.debugDescription }
                .first
                ?? (results.count == 1 ? results.first : nil)
            guard let selected else { return }
            browser.stateUpdateHandler = nil
            browser.browseResultsChangedHandler = nil
            browser.cancel()
            self.browser = nil
            self.connect(to: selected.endpoint)
        }
        browser.start(queue: queue)
    }

    private func connect(to endpoint: NWEndpoint) {
        guard wantsStarted, let credential else { return }
        do {
            let connection = NWConnection(
                to: endpoint,
                using: try Self.makeParameters(credential: credential)
            )
            self.connection = connection
            phase = .idle
            publish("Authenticating desktop video…")
            connection.stateUpdateHandler = { [weak self, weak connection] state in
                guard let self, let connection, self.connection === connection else { return }
                switch state {
                case .ready: self.connectionBecameReady()
                case .failed(let error): self.fail("Desktop video disconnected: \(error.localizedDescription)")
                case .waiting(let error): self.publish("Desktop video waiting: \(error.localizedDescription)")
                case .cancelled:
                    if self.wantsStarted { self.fail("Desktop video connection ended.") }
                default: break
                }
            }
            connection.start(queue: queue)
        } catch {
            fail("Desktop video could not start: \(error.localizedDescription)")
        }
    }

    private func connectionBecameReady() {
        guard let credential, let controlSessionID else {
            fail("Desktop authorization session is unavailable.")
            return
        }
        phase = .awaitingChallenge
        var hello = Data([Self.protocolVersion])
        hello.append(credential.controllerID.desktopUUIDBytes)
        hello.append(controlSessionID.desktopUUIDBytes)
        send(type: .authenticationHello, data: hello) { [weak self] error in
            guard let self else { return }
            if let error { self.fail(error) } else { self.receiveNext() }
        }
    }

    private func receiveNext() {
        guard wantsStarted, let connection else { return }
        connection.receiveMessage { [weak self, weak connection] data, context, _, error in
            guard let self, let connection, self.connection === connection else { return }
            if let error {
                self.fail("Desktop video receive failed: \(error.localizedDescription)")
                return
            }
            guard let data,
                  let metadata = context?.protocolMetadata(
                    definition: ROBRemoteDesktopVideoFramer.definition
                  ) as? NWProtocolFramer.Message else {
                self.fail("Desktop video sent an invalid frame.")
                return
            }
            self.consume(type: metadata.remoteDesktopVideoMessageType, data: data)
        }
    }

    private func consume(type: DesktopVideoMessageType, data: Data) {
        do {
            switch phase {
            case .awaitingChallenge:
                guard type == .authenticationChallenge, let credential else {
                    throw DesktopVideoError.invalidMessage
                }
                let challenge = try DesktopAuthChallenge(data)
                let proof = try DesktopAuthProof.make(challenge: challenge, credential: credential)
                phase = .awaitingAccepted(challenge, proof)
                send(type: .authenticationProof, data: proof.encoded) { [weak self] error in
                    guard let self else { return }
                    if let error { self.fail(error) } else { self.receiveNext() }
                }
                return

            case .awaitingAccepted(let challenge, let proof):
                guard type == .authenticationAccepted,
                      let credential,
                      let controlSessionID,
                      DesktopAuthAccepted.validate(
                        data,
                        challenge: challenge,
                        proof: proof,
                        credential: credential,
                        controlSessionID: controlSessionID
                      ) else { throw DesktopVideoError.authentication }
                phase = .awaitingCapabilities

            case .awaitingCapabilities:
                guard type == .capabilities,
                      let capabilities = try? JSONDecoder().decode(
                        DesktopVideoCapabilities.self,
                        from: data
                      ),
                      capabilities.protocolVersion == Self.protocolVersion,
                      capabilities.cameras.contains(where: {
                        $0.id == "desktop"
                            && $0.supportedCodecs.contains("jpeg")
                            && $0.supportedDeliveryModes.contains("jpegFrames")
                      }) else { throw DesktopVideoError.unavailable }
                try sendSubscription()
                return

            case .awaitingSubscription:
                guard type == .subscriptionResponse,
                      let response = try? JSONDecoder().decode(
                        DesktopSubscriptionResponse.self,
                        from: data
                      ),
                      let controlSessionID,
                      let subscriptionID else { throw DesktopVideoError.invalidMessage }
                guard response.type == "accepted",
                      let stream = response.stream,
                      stream.sessionID == controlSessionID,
                      stream.id == subscriptionID,
                      stream.cameraID == "desktop",
                      stream.codec == "jpeg",
                      stream.delivery == "jpegFrames" else {
                    let reason = response.reason ?? "desktop stream rejected"
                    throw DesktopVideoError.rejected(reason)
                }
                phase = .streaming
                reconnectAttempt = 0
                lastMediaSequence = 0
                publish("LIVE • \(stream.width)×\(stream.height) • secure desktop")

            case .streaming:
                switch type {
                case .accessUnit:
                    guard let controlSessionID, let subscriptionID else {
                        throw DesktopVideoError.invalidMessage
                    }
                    let unit = try DesktopJPEGAccessUnit(
                        data,
                        expectedSessionID: controlSessionID,
                        expectedSubscriptionID: subscriptionID,
                        after: lastMediaSequence
                    )
                    lastMediaSequence = unit.sequence
                    publishJPEG(unit.jpeg)
                case .streamEnded:
                    let ended = try JSONDecoder().decode(DesktopStreamEnded.self, from: data)
                    throw DesktopVideoError.rejected(ended.reason)
                default:
                    throw DesktopVideoError.invalidMessage
                }

            case .idle, .stopped:
                throw DesktopVideoError.invalidMessage
            }
        } catch {
            fail(error.localizedDescription)
            return
        }
        receiveNext()
    }

    private func sendSubscription() throws {
        guard let controlSessionID, let subscriptionID else {
            throw DesktopVideoError.authentication
        }
        let request = DesktopSubscriptionRequest(
            protocolVersion: Self.protocolVersion,
            sessionID: controlSessionID,
            id: subscriptionID,
            cameraID: "desktop",
            preferredCodecs: ["jpeg"],
            constraints: .init(
                maximumWidth: 960,
                maximumHeight: 540,
                maximumFramesPerSecond: 6,
                maximumBitrate: 1_500_000
            ),
            delivery: "jpegFrames"
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(request)
        phase = .awaitingSubscription
        send(type: .subscribe, data: data) { [weak self] error in
            guard let self else { return }
            if let error { self.fail(error) } else { self.receiveNext() }
        }
    }

    private func send(
        type: DesktopVideoMessageType,
        data: Data,
        completion: @escaping (String?) -> Void
    ) {
        guard let connection,
              !data.isEmpty,
              data.count <= (type.isMedia ? Self.maximumFrameBytes : 64 * 1_024) else {
            completion("Desktop video frame is invalid.")
            return
        }
        let message = NWProtocolFramer.Message(definition: ROBRemoteDesktopVideoFramer.definition)
        message.remoteDesktopVideoMessageType = type
        let context = NWConnection.ContentContext(
            identifier: "ROBDesktop.\(type.rawValue).\(UUID().uuidString)",
            metadata: [message]
        )
        connection.send(
            content: data,
            contentContext: context,
            isComplete: true,
            completion: .contentProcessed { error in
                completion(error?.localizedDescription)
            }
        )
    }

    private func fail(_ detail: String) {
        publish(detail)
        browser?.stateUpdateHandler = nil
        browser?.browseResultsChangedHandler = nil
        browser?.cancel()
        browser = nil
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        phase = .stopped
        guard wantsStarted else { return }
        reconnectWorkItem?.cancel()
        reconnectAttempt = min(reconnectAttempt + 1, 5)
        let delay = min(8.0, pow(2.0, Double(reconnectAttempt - 1)))
        let work = DispatchWorkItem { [weak self] in self?.beginBrowsing() }
        reconnectWorkItem = work
        queue.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func stopLocked(publish shouldPublish: Bool) {
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        browser?.stateUpdateHandler = nil
        browser?.browseResultsChangedHandler = nil
        browser?.cancel()
        browser = nil
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        phase = .stopped
        lastMediaSequence = 0
        if shouldPublish { publish("Desktop offline") }
    }

    private func publish(_ status: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.remoteDesktopVideoClient(self, didChangeStatus: status)
        }
    }

    private func publishJPEG(_ data: Data) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.remoteDesktopVideoClient(self, didReceiveJPEG: data)
        }
    }

    private static func makeParameters(credential: ROBControlCredential) throws -> NWParameters {
        guard credential.isValid else { throw DesktopVideoError.authentication }
        let quic = NWProtocolQUIC.Options(alpn: [applicationProtocol])
        quic.direction = .bidirectional
        quic.idleTimeout = 10_000
        let securityOptions = quic.securityProtocolOptions
        sec_protocol_options_set_min_tls_protocol_version(securityOptions, .TLSv13)
        let fingerprint = credential.certificateSHA256
        sec_protocol_options_set_verify_block(
            securityOptions,
            { _, trust, complete in
                let reference = sec_trust_copy_ref(trust).takeRetainedValue()
                guard let chain = SecTrustCopyCertificateChain(reference) as? [SecCertificate],
                      let leaf = chain.first else {
                    complete(false)
                    return
                }
                complete(Data(SHA256.hash(data: SecCertificateCopyData(leaf) as Data)) == fingerprint)
            },
            verifyQueue
        )
        let parameters = NWParameters(quic: quic)
        parameters.includePeerToPeer = true
        parameters.serviceClass = .responsiveData
        parameters.defaultProtocolStack.applicationProtocols.insert(
            NWProtocolFramer.Options(definition: ROBRemoteDesktopVideoFramer.definition),
            at: 0
        )
        return parameters
    }
}

private enum DesktopVideoError: LocalizedError {
    case authentication
    case unavailable
    case invalidMessage
    case rejected(String)

    var errorDescription: String? {
        switch self {
        case .authentication: return "Desktop video authentication failed."
        case .unavailable: return "Cerebro did not advertise an available desktop stream."
        case .invalidMessage: return "Cerebro sent an invalid desktop video message."
        case .rejected(let reason): return "Desktop video unavailable: \(reason)."
        }
    }
}

private struct DesktopAuthChallenge {
    let channelID: Data
    let serverNonce: Data
    let robotID: UUID

    init(_ data: Data) throws {
        guard data.count == 65, data[0] == 1,
              let robotID = UUID(desktopBytes: Data(data[49..<65])) else {
            throw DesktopVideoError.authentication
        }
        channelID = Data(data[1..<17])
        serverNonce = Data(data[17..<49])
        self.robotID = robotID
    }

    var encoded: Data {
        Data([1]) + channelID + serverNonce + robotID.desktopUUIDBytes
    }
}

private struct DesktopAuthProof {
    let channelID: Data
    let controllerID: UUID
    let clientNonce: Data
    let mac: Data

    var encoded: Data {
        Data([1]) + channelID + controllerID.desktopUUIDBytes + clientNonce + mac
    }

    static func make(
        challenge: DesktopAuthChallenge,
        credential: ROBControlCredential
    ) throws -> DesktopAuthProof {
        guard challenge.robotID == credential.robotID else { throw DesktopVideoError.authentication }
        var nonce = Data(count: 32)
        let status = nonce.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, $0.count, $0.baseAddress!)
        }
        guard status == errSecSuccess else { throw DesktopVideoError.authentication }
        var transcript = Data("robvideo/1\0".utf8)
        transcript.append(challenge.encoded)
        transcript.append(credential.controllerID.desktopUUIDBytes)
        transcript.append(nonce)
        var input = Data("ROBVIDEO-AUTH-V1/CLIENT-PROOF\0".utf8)
        input.append(transcript)
        return DesktopAuthProof(
            channelID: challenge.channelID,
            controllerID: credential.controllerID,
            clientNonce: nonce,
            mac: Data(HMAC<SHA256>.authenticationCode(
                for: input,
                using: SymmetricKey(data: credential.sharedSecret)
            ))
        )
    }
}

private enum DesktopAuthAccepted {
    static func validate(
        _ data: Data,
        challenge: DesktopAuthChallenge,
        proof: DesktopAuthProof,
        credential: ROBControlCredential,
        controlSessionID: UUID
    ) -> Bool {
        guard [49, 65].contains(data.count), data[0] == 1,
              Data(data[1..<17]) == challenge.channelID,
              UUID(desktopBytes: Data(data[17..<33])) == credential.controllerID else { return false }
        if data.count == 49 {
            return UUID(desktopBytes: Data(data[33..<49])) == controlSessionID
        }
        var transcript = Data("robvideo/1\0".utf8)
        transcript.append(challenge.encoded)
        transcript.append(proof.controllerID.desktopUUIDBytes)
        transcript.append(proof.clientNonce)
        var input = Data("ROBVIDEO-AUTH-V1/SERVER-ACCEPTED\0".utf8)
        input.append(transcript)
        input.append(proof.mac)
        return HMAC<SHA256>.isValidAuthenticationCode(
            Data(data[33..<65]),
            authenticating: input,
            using: SymmetricKey(data: credential.sharedSecret)
        )
    }
}

private struct DesktopVideoCapabilities: Decodable {
    struct Camera: Decodable {
        let id: String
        let supportedCodecs: [String]
        let supportedDeliveryModes: [String]
    }
    let protocolVersion: UInt8
    let cameras: [Camera]
}

private struct DesktopSubscriptionRequest: Encodable {
    struct Constraints: Encodable {
        let maximumWidth: UInt16
        let maximumHeight: UInt16
        let maximumFramesPerSecond: UInt16
        let maximumBitrate: UInt32
    }
    let protocolVersion: UInt8
    let sessionID: UUID
    let id: UUID
    let cameraID: String
    let preferredCodecs: [String]
    let constraints: Constraints
    let delivery: String
}

private struct DesktopSubscriptionResponse: Decodable {
    struct Stream: Decodable {
        let sessionID: UUID
        let id: UUID
        let cameraID: String
        let codec: String
        let width: UInt16
        let height: UInt16
        let framesPerSecond: UInt16
        let bitrate: UInt32
        let delivery: String
    }
    let type: String
    let stream: Stream?
    let sessionID: UUID?
    let id: UUID?
    let reason: String?
}

private struct DesktopStreamEnded: Decodable {
    let sessionID: UUID
    let id: UUID
    let reason: String
}

private struct DesktopJPEGAccessUnit {
    let sequence: UInt64
    let jpeg: Data

    init(
        _ data: Data,
        expectedSessionID: UUID,
        expectedSubscriptionID: UUID,
        after previousSequence: UInt64
    ) throws {
        guard data.count >= 92,
              data.desktopUInt32(at: 0) == 0x5242_5644,
              data[4] == 1,
              data[5] == 2,
              data[6] == 1,
              data[7] & 0x01 == 0x01,
              data.desktopUInt16(at: 8) == 92,
              data.desktopUInt16(at: 10) == 0,
              Int(data.desktopUInt32(at: 12)) == data.count - 92,
              UUID(desktopBytes: Data(data[16..<32])) == expectedSessionID,
              UUID(desktopBytes: Data(data[32..<48])) == expectedSubscriptionID,
              data.desktopUInt32(at: 80) > 0,
              data.desktopUInt32(at: 84) == 0,
              data.desktopUInt32(at: 88) == 0 else {
            throw DesktopVideoError.invalidMessage
        }
        let sequence = data.desktopUInt64(at: 48)
        let jpeg = Data(data.dropFirst(92))
        guard sequence > previousSequence,
              jpeg.count <= 2 * 1_024 * 1_024,
              jpeg.prefix(2) == Data([0xff, 0xd8]),
              jpeg.suffix(2) == Data([0xff, 0xd9]) else {
            throw DesktopVideoError.invalidMessage
        }
        self.sequence = sequence
        self.jpeg = jpeg
    }
}

private enum DesktopVideoMessageType: UInt16 {
    case invalid = 0
    case authenticationChallenge = 1
    case authenticationProof = 2
    case authenticationAccepted = 3
    case authenticationRejected = 4
    case capabilities = 5
    case subscribe = 6
    case subscriptionResponse = 7
    case unsubscribe = 8
    case feedback = 9
    case codecConfiguration = 10
    case accessUnit = 11
    case streamEnded = 12
    case authenticationHello = 13

    var isMedia: Bool { self == .codecConfiguration || self == .accessUnit }
}

private final class ROBRemoteDesktopVideoFramer: NWProtocolFramerImplementation {
    static let definition = NWProtocolFramer.Definition(implementation: ROBRemoteDesktopVideoFramer.self)
    static var label: String { "ROBRemoteDesktopVideoV1" }

    private var nextOutputSequence: UInt64 = 1
    private var lastInputSequence: UInt64 = 0

    required init(framer: NWProtocolFramer.Instance) {}
    func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult { .ready }
    func wakeup(framer: NWProtocolFramer.Instance) {}
    func stop(framer: NWProtocolFramer.Instance) -> Bool { true }
    func cleanup(framer: NWProtocolFramer.Instance) {}

    func handleOutput(
        framer: NWProtocolFramer.Instance,
        message: NWProtocolFramer.Message,
        messageLength: Int,
        isComplete: Bool
    ) {
        let type = message.remoteDesktopVideoMessageType
        guard type != .invalid,
              nextOutputSequence < UInt64.max,
              messageLength >= 0,
              messageLength <= (type.isMedia ? (2 * 1_024 * 1_024) + 92 : 64 * 1_024) else {
            framer.markFailed(error: NWError.posix(.EMSGSIZE))
            return
        }
        var header = Data()
        header.desktopAppend(0x5256_4944 as UInt32)
        header.append(1)
        header.append(32)
        header.desktopAppend(type.rawValue)
        header.desktopAppend(UInt32(messageLength))
        header.desktopAppend(0 as UInt16)
        header.desktopAppend(0 as UInt16)
        header.desktopAppend(nextOutputSequence)
        header.desktopAppend(0 as UInt64)
        nextOutputSequence &+= 1
        framer.writeOutput(data: header)
        do { try framer.writeOutputNoCopy(length: messageLength) }
        catch { framer.markFailed(error: NWError.posix(.EIO)) }
    }

    func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        while true {
            var header: Data?
            let parsed = framer.parseInput(minimumIncompleteLength: 32, maximumLength: 32) {
                buffer, _ in
                guard let buffer, buffer.count >= 32 else { return 0 }
                header = Data(buffer)
                return 32
            }
            guard parsed else { return 32 }
            guard let header,
                  header.desktopUInt32(at: 0) == 0x5256_4944,
                  header[4] == 1,
                  header[5] == 32,
                  let type = DesktopVideoMessageType(rawValue: header.desktopUInt16(at: 6)),
                  type != .invalid,
                  header.desktopUInt16(at: 12) == 0,
                  header.desktopUInt16(at: 14) == 0,
                  header.desktopUInt64(at: 24) == 0,
                  header.desktopUInt64(at: 16) > lastInputSequence else {
                framer.markFailed(error: NWError.posix(.EPROTO))
                return 0
            }
            let length = Int(header.desktopUInt32(at: 8))
            let limit = type.isMedia ? (2 * 1_024 * 1_024) + 92 : 64 * 1_024
            guard length <= limit else {
                framer.markFailed(error: NWError.posix(.EMSGSIZE))
                return 0
            }
            lastInputSequence = header.desktopUInt64(at: 16)
            let message = NWProtocolFramer.Message(definition: Self.definition)
            message.remoteDesktopVideoMessageType = type
            if !framer.deliverInputNoCopy(length: length, message: message, isComplete: true) {
                return 0
            }
        }
    }
}

private extension NWProtocolFramer.Message {
    var remoteDesktopVideoMessageType: DesktopVideoMessageType {
        get { self["ROBRemoteDesktopVideoMessageType"] as? DesktopVideoMessageType ?? .invalid }
        set { self["ROBRemoteDesktopVideoMessageType"] = newValue }
    }
}

private extension UUID {
    var desktopUUIDBytes: Data {
        var value = uuid
        return withUnsafeBytes(of: &value) { Data($0) }
    }

    init?(desktopBytes data: Data) {
        guard data.count == 16 else { return nil }
        var value: uuid_t = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        _ = withUnsafeMutableBytes(of: &value) { data.copyBytes(to: $0) }
        self.init(uuid: value)
    }
}

private extension Data {
    mutating func desktopAppend<T: FixedWidthInteger>(_ value: T) {
        var bigEndian = value.bigEndian
        Swift.withUnsafeBytes(of: &bigEndian) { append(contentsOf: $0) }
    }

    func desktopUInt16(at offset: Int) -> UInt16 {
        (UInt16(self[offset]) << 8) | UInt16(self[offset + 1])
    }

    func desktopUInt32(at offset: Int) -> UInt32 {
        var value: UInt32 = 0
        for byte in self[offset..<(offset + 4)] { value = (value << 8) | UInt32(byte) }
        return value
    }

    func desktopUInt64(at offset: Int) -> UInt64 {
        var value: UInt64 = 0
        for byte in self[offset..<(offset + 8)] { value = (value << 8) | UInt64(byte) }
        return value
    }
}
