//
//  AutoNetDataTransferProtocol.swift
//  Cerebro
//
//  The v2 control plane is a reliable QUIC stream over UDP. Cerebro presents a
//  persistent P-256 identity, ROBController pins its leaf certificate during
//  pairing, and both sides prove possession of the pairing secret before any
//  application data is accepted. The original plaintext UDP framing remains
//  here only so the explicit legacy adapter can interoperate with older builds.
//

import CryptoKit
import Foundation
import Network
import Security

enum DataMessageType: UInt32 {
  case invalid = 0
  case sendData = 1
  case setAutomationScript = 2
  case pairingChallenge = 3
  case pairingProof = 4
  case pairingAccepted = 5
  case pairingRejected = 6
  case pairingHello = 8
}

// MARK: - Administrator terminal

/// A deliberately separate binary protocol for administrator PTY traffic.
/// The fixed discriminator lets both ends claim malformed terminal frames so
/// shell bytes can never fall through to the historical robot command parser.
enum ROBAdministratorTerminalMessageKind: UInt8, CaseIterable {
  case open = 1
  case input = 2
  case resize = 3
  case close = 4
  case output = 5
  case ready = 6
  case title = 7
  case exited = 8
  case error = 9
}

struct ROBAdministratorTerminalMessage: Equatable {
  let kind: ROBAdministratorTerminalMessageKind
  let terminalID: UUID
  let sequence: UInt64
  let columns: UInt16
  let rows: UInt16
  let payload: Data
}

enum ROBAdministratorTerminalProtocolError: LocalizedError {
  case invalid(String)

  var errorDescription: String? {
    switch self {
    case .invalid(let detail): return "Invalid administrator terminal message: \(detail)"
    }
  }
}

enum ROBAdministratorTerminalProtocol {
  static let formatVersion: UInt8 = 1
  static let maximumTabs = 8
  static let maximumPayloadBytes = 65_536
  static let maximumMessageBytes = headerLength + maximumPayloadBytes
  static let minimumColumns: UInt16 = 20
  static let maximumColumns: UInt16 = 500
  static let minimumRows: UInt16 = 5
  static let maximumRows: UInt16 = 250

  private static let magic = Data("ROBTPTY1".utf8)
  private static let terminalIDLength = 36
  private static let headerLength = 8 + 1 + 1 + terminalIDLength + 8 + 2 + 2 + 4

  static func claimsProtocol(_ data: Data) -> Bool {
    data.count >= magic.count && data.prefix(magic.count) == magic
  }

  static func encode(_ message: ROBAdministratorTerminalMessage) throws -> Data {
    try validate(message)
    let identifier = Data(message.terminalID.uuidString.lowercased().utf8)
    guard identifier.count == terminalIDLength else {
      throw ROBAdministratorTerminalProtocolError.invalid("terminal identifier")
    }

    var data = Data(capacity: headerLength + message.payload.count)
    data.append(magic)
    data.append(formatVersion)
    data.append(message.kind.rawValue)
    data.append(identifier)
    append(message.sequence, to: &data)
    append(message.columns, to: &data)
    append(message.rows, to: &data)
    append(UInt32(message.payload.count), to: &data)
    data.append(message.payload)
    return data
  }

  static func decode(_ data: Data) throws -> ROBAdministratorTerminalMessage {
    guard claimsProtocol(data) else {
      throw ROBAdministratorTerminalProtocolError.invalid("discriminator")
    }
    guard data.count >= headerLength, data.count <= maximumMessageBytes else {
      throw ROBAdministratorTerminalProtocolError.invalid("length")
    }
    guard data[8] == formatVersion,
          let kind = ROBAdministratorTerminalMessageKind(rawValue: data[9]) else {
      throw ROBAdministratorTerminalProtocolError.invalid("version or message kind")
    }
    let identifierRange = 10 ..< (10 + terminalIDLength)
    guard let identifierText = String(data: data.subdata(in: identifierRange), encoding: .utf8),
          let terminalID = UUID(uuidString: identifierText) else {
      throw ROBAdministratorTerminalProtocolError.invalid("terminal identifier")
    }
    var offset = identifierRange.upperBound
    let sequence: UInt64 = readInteger(from: data, at: &offset)
    let columns: UInt16 = readInteger(from: data, at: &offset)
    let rows: UInt16 = readInteger(from: data, at: &offset)
    let payloadLength: UInt32 = readInteger(from: data, at: &offset)
    guard payloadLength <= maximumPayloadBytes,
          offset + Int(payloadLength) == data.count else {
      throw ROBAdministratorTerminalProtocolError.invalid("payload length")
    }
    let message = ROBAdministratorTerminalMessage(
      kind: kind,
      terminalID: terminalID,
      sequence: sequence,
      columns: columns,
      rows: rows,
      payload: data.subdata(in: offset ..< data.count)
    )
    try validate(message)
    return message
  }

  static func acknowledgementPayload(_ sequence: UInt64) -> Data {
    var payload = Data(capacity: 8)
    append(sequence, to: &payload)
    return payload
  }

  static func acknowledgement(from payload: Data) -> UInt64? {
    guard payload.count == 8 else { return nil }
    var offset = 0
    return readInteger(from: payload, at: &offset) as UInt64
  }

  private static func validate(_ message: ROBAdministratorTerminalMessage) throws {
    guard message.sequence > 0 else {
      throw ROBAdministratorTerminalProtocolError.invalid("sequence")
    }
    let hasValidSize = (minimumColumns ... maximumColumns).contains(message.columns)
      && (minimumRows ... maximumRows).contains(message.rows)
    switch message.kind {
    case .open:
      guard hasValidSize, acknowledgement(from: message.payload) != nil else {
        throw ROBAdministratorTerminalProtocolError.invalid("open request")
      }
    case .input:
      guard !message.payload.isEmpty, message.payload.count <= maximumPayloadBytes,
            message.columns == 0, message.rows == 0 else {
        throw ROBAdministratorTerminalProtocolError.invalid("terminal input")
      }
    case .resize:
      guard hasValidSize, message.payload.isEmpty else {
        throw ROBAdministratorTerminalProtocolError.invalid("terminal size")
      }
    case .close:
      guard message.columns == 0, message.rows == 0, message.payload.isEmpty else {
        throw ROBAdministratorTerminalProtocolError.invalid("close request")
      }
    case .output:
      guard !message.payload.isEmpty, message.payload.count <= maximumPayloadBytes,
            message.columns == 0, message.rows == 0 else {
        throw ROBAdministratorTerminalProtocolError.invalid("terminal output")
      }
    case .ready, .exited, .error:
      guard message.columns == 0, message.rows == 0,
            message.payload.count <= 1_024,
            String(data: message.payload, encoding: .utf8) != nil else {
        throw ROBAdministratorTerminalProtocolError.invalid("terminal state")
      }
    case .title:
      guard message.columns == 0, message.rows == 0,
            message.payload.count <= 512,
            String(data: message.payload, encoding: .utf8) != nil else {
        throw ROBAdministratorTerminalProtocolError.invalid("terminal title")
      }
    }
  }

  private static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
    var bigEndian = value.bigEndian
    withUnsafeBytes(of: &bigEndian) { data.append(contentsOf: $0) }
  }

  private static func readInteger<T: FixedWidthInteger>(from data: Data, at offset: inout Int) -> T {
    let width = MemoryLayout<T>.size
    var value: T = 0
    for byte in data[offset ..< (offset + width)] {
      value = (value << 8) | T(byte)
    }
    offset += width
    return value
  }
}

// MARK: - Visually authorized person following

enum ROBFollowTargetKind: String, Codable, CaseIterable {
  case previewRequest
  case preview
  case authorize
  case stop
  case status
}

enum ROBFollowTargetState: String, Codable, CaseIterable {
  case idle
  case previewReady
  case following
  case targetLost
  case blocked
  case stopped
}

struct ROBFollowTargetCandidate: Codable, Equatable {
  let id: UUID
  /// Vision-normalized rectangle, encoded as 0...10,000 fixed-point values.
  let x: UInt16
  let y: UInt16
  let width: UInt16
  let height: UInt16
  let confidencePermille: UInt16
  let distanceMillimeters: UInt16?
}

struct ROBFollowTargetMessage: Codable, Equatable {
  let kind: ROBFollowTargetKind
  let requestID: UUID
  let controllerID: UUID
  let sessionID: UUID
  let sequence: UInt64
  let sentAtMilliseconds: UInt64
  let state: ROBFollowTargetState?
  let detail: String?
  let previewJPEG: Data?
  let candidates: [ROBFollowTargetCandidate]
  let selectedCandidateID: UUID?
  let minimumDistanceCentimeters: UInt16
  let preferredDistanceCentimeters: UInt16
  let maximumDistanceCentimeters: UInt16
  let maximumSpeedPermille: UInt16

  init(
    kind: ROBFollowTargetKind,
    requestID: UUID,
    controllerID: UUID,
    sessionID: UUID,
    sequence: UInt64,
    sentAtMilliseconds: UInt64,
    state: ROBFollowTargetState? = nil,
    detail: String? = nil,
    previewJPEG: Data? = nil,
    candidates: [ROBFollowTargetCandidate] = [],
    selectedCandidateID: UUID? = nil,
    minimumDistanceCentimeters: UInt16 = 120,
    preferredDistanceCentimeters: UInt16 = 180,
    maximumDistanceCentimeters: UInt16 = 280,
    maximumSpeedPermille: UInt16 = 120
  ) {
    self.kind = kind
    self.requestID = requestID
    self.controllerID = controllerID
    self.sessionID = sessionID
    self.sequence = sequence
    self.sentAtMilliseconds = sentAtMilliseconds
    self.state = state
    self.detail = detail
    self.previewJPEG = previewJPEG
    self.candidates = candidates
    self.selectedCandidateID = selectedCandidateID
    self.minimumDistanceCentimeters = minimumDistanceCentimeters
    self.preferredDistanceCentimeters = preferredDistanceCentimeters
    self.maximumDistanceCentimeters = maximumDistanceCentimeters
    self.maximumSpeedPermille = maximumSpeedPermille
  }
}

enum ROBFollowTargetProtocolError: LocalizedError {
  case invalid(String)

  var errorDescription: String? {
    switch self {
    case .invalid(let detail): return "Invalid follow-target message: \(detail)"
    }
  }
}

enum ROBFollowTargetProtocol {
  static let maximumMessageBytes = 524_288
  static let previewLifetimeMilliseconds: UInt64 = 15_000
  private static let magic = Data("ROBFOLLOW1".utf8)

  static func claimsProtocol(_ data: Data) -> Bool {
    data.count >= magic.count && data.prefix(magic.count) == magic
  }

  static func encode(_ message: ROBFollowTargetMessage) throws -> Data {
    try validate(message)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let body = try encoder.encode(message)
    guard magic.count + body.count <= maximumMessageBytes else {
      throw ROBFollowTargetProtocolError.invalid("length")
    }
    return magic + body
  }

  static func decode(_ data: Data) throws -> ROBFollowTargetMessage {
    guard claimsProtocol(data), data.count <= maximumMessageBytes else {
      throw ROBFollowTargetProtocolError.invalid("discriminator or length")
    }
    let message: ROBFollowTargetMessage
    do {
      message = try JSONDecoder().decode(
        ROBFollowTargetMessage.self,
        from: Data(data.dropFirst(magic.count))
      )
    } catch {
      throw ROBFollowTargetProtocolError.invalid("JSON")
    }
    try validate(message)
    return message
  }

  static func isFresh(_ message: ROBFollowTargetMessage, nowMilliseconds: UInt64) -> Bool {
    nowMilliseconds >= message.sentAtMilliseconds
      && nowMilliseconds - message.sentAtMilliseconds <= previewLifetimeMilliseconds
  }

  private static func validate(_ message: ROBFollowTargetMessage) throws {
    guard message.sequence > 0,
          message.minimumDistanceCentimeters >= 100,
          message.minimumDistanceCentimeters <= 180,
          message.preferredDistanceCentimeters >= message.minimumDistanceCentimeters + 20,
          message.maximumDistanceCentimeters >= message.preferredDistanceCentimeters + 20,
          message.maximumDistanceCentimeters <= 400,
          message.maximumSpeedPermille >= 40,
          message.maximumSpeedPermille <= 200,
          (message.detail?.utf8.count ?? 0) <= 1_024,
          message.candidates.count <= 8,
          (message.previewJPEG?.count ?? 0) <= 360_000 else {
      throw ROBFollowTargetProtocolError.invalid("bounds")
    }
    for candidate in message.candidates {
      guard candidate.x <= 10_000, candidate.y <= 10_000,
            candidate.width > 0, candidate.height > 0,
            Int(candidate.x) + Int(candidate.width) <= 10_000,
            Int(candidate.y) + Int(candidate.height) <= 10_000,
            candidate.confidencePermille <= 1_000 else {
        throw ROBFollowTargetProtocolError.invalid("candidate")
      }
    }
    switch message.kind {
    case .previewRequest:
      guard message.previewJPEG == nil, message.candidates.isEmpty,
            message.selectedCandidateID == nil, message.state == nil else {
        throw ROBFollowTargetProtocolError.invalid("preview request")
      }
    case .preview:
      guard message.previewJPEG?.isEmpty == false, !message.candidates.isEmpty,
            message.selectedCandidateID == nil, message.state == .previewReady else {
        throw ROBFollowTargetProtocolError.invalid("preview")
      }
    case .authorize:
      guard message.previewJPEG == nil, message.candidates.isEmpty,
            message.selectedCandidateID != nil, message.state == nil else {
        throw ROBFollowTargetProtocolError.invalid("authorization")
      }
    case .stop:
      guard message.previewJPEG == nil, message.candidates.isEmpty,
            message.selectedCandidateID == nil else {
        throw ROBFollowTargetProtocolError.invalid("stop")
      }
    case .status:
      guard message.previewJPEG == nil, message.candidates.isEmpty,
            message.selectedCandidateID == nil, message.state != nil else {
        throw ROBFollowTargetProtocolError.invalid("status")
      }
    }
  }
}

// MARK: - Administrator remote desktop input

enum ROBRemoteDesktopControlKind: String, Codable, CaseIterable {
  case start
  case stop
  case pointerMoved
  case primaryDown
  case primaryUp
  case secondaryClick
  case scroll
  case text
  case key
  case status
}

enum ROBRemoteDesktopKey: String, Codable, CaseIterable {
  case returnKey
  case tab
  case delete
  case escape
  case leftArrow
  case rightArrow
  case upArrow
  case downArrow
  case letterA
  case letterC
  case letterV
}

struct ROBRemoteDesktopControlMessage: Codable, Equatable {
  let kind: ROBRemoteDesktopControlKind
  let sequence: UInt64
  let normalizedX: UInt16
  let normalizedY: UInt16
  let scrollX: Int16
  let scrollY: Int16
  let modifiers: UInt8
  let key: ROBRemoteDesktopKey?
  let payload: Data

  init(
    kind: ROBRemoteDesktopControlKind,
    sequence: UInt64,
    normalizedX: UInt16 = 0,
    normalizedY: UInt16 = 0,
    scrollX: Int16 = 0,
    scrollY: Int16 = 0,
    modifiers: UInt8 = 0,
    key: ROBRemoteDesktopKey? = nil,
    payload: Data = Data()
  ) {
    self.kind = kind
    self.sequence = sequence
    self.normalizedX = normalizedX
    self.normalizedY = normalizedY
    self.scrollX = scrollX
    self.scrollY = scrollY
    self.modifiers = modifiers
    self.key = key
    self.payload = payload
  }

  private enum CodingKeys: String, CodingKey, CaseIterable {
    case kind
    case sequence
    case normalizedX
    case normalizedY
    case scrollX
    case scrollY
    case modifiers
    case key
    case payload
  }

  init(from decoder: Decoder) throws {
    let dynamic = try decoder.container(keyedBy: ROBRemoteDesktopCodingKey.self)
    let allowed = Set(CodingKeys.allCases.map(\.stringValue))
    guard dynamic.allKeys.allSatisfy({ allowed.contains($0.stringValue) }) else {
      throw ROBRemoteDesktopProtocolError.invalid("unexpected field")
    }
    let values = try decoder.container(keyedBy: CodingKeys.self)
    kind = try values.decode(ROBRemoteDesktopControlKind.self, forKey: .kind)
    sequence = try values.decode(UInt64.self, forKey: .sequence)
    normalizedX = try values.decode(UInt16.self, forKey: .normalizedX)
    normalizedY = try values.decode(UInt16.self, forKey: .normalizedY)
    scrollX = try values.decode(Int16.self, forKey: .scrollX)
    scrollY = try values.decode(Int16.self, forKey: .scrollY)
    modifiers = try values.decode(UInt8.self, forKey: .modifiers)
    key = try values.decodeIfPresent(ROBRemoteDesktopKey.self, forKey: .key)
    payload = try values.decode(Data.self, forKey: .payload)
  }
}

private struct ROBRemoteDesktopCodingKey: CodingKey {
  let stringValue: String
  let intValue: Int?
  init?(stringValue: String) { self.stringValue = stringValue; intValue = nil }
  init?(intValue: Int) { stringValue = String(intValue); self.intValue = intValue }
}

enum ROBRemoteDesktopProtocolError: LocalizedError {
  case invalid(String)

  var errorDescription: String? {
    switch self {
    case .invalid(let detail): return "Invalid administrator remote-desktop message: \(detail)"
    }
  }
}

enum ROBRemoteDesktopControlProtocol {
  static let maximumTextBytes = 4_096
  static let maximumStatusBytes = 1_024
  static let maximumMessageBytes = 8_192
  static let modifierShift: UInt8 = 1 << 0
  static let modifierControl: UInt8 = 1 << 1
  static let modifierOption: UInt8 = 1 << 2
  static let modifierCommand: UInt8 = 1 << 3

  private static let magic = Data("ROBDESK1".utf8)

  static func claimsProtocol(_ data: Data) -> Bool {
    data.count >= magic.count && data.prefix(magic.count) == magic
  }

  static func encode(_ message: ROBRemoteDesktopControlMessage) throws -> Data {
    try validate(message)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let body = try encoder.encode(message)
    guard magic.count + body.count <= maximumMessageBytes else {
      throw ROBRemoteDesktopProtocolError.invalid("length")
    }
    return magic + body
  }

  static func decode(_ data: Data) throws -> ROBRemoteDesktopControlMessage {
    guard claimsProtocol(data), data.count <= maximumMessageBytes else {
      throw ROBRemoteDesktopProtocolError.invalid("discriminator or length")
    }
    let message: ROBRemoteDesktopControlMessage
    do {
      message = try JSONDecoder().decode(
        ROBRemoteDesktopControlMessage.self,
        from: Data(data.dropFirst(magic.count))
      )
    } catch let error as ROBRemoteDesktopProtocolError {
      throw error
    } catch {
      throw ROBRemoteDesktopProtocolError.invalid("JSON")
    }
    try validate(message)
    return message
  }

  private static func validate(_ message: ROBRemoteDesktopControlMessage) throws {
    guard message.sequence > 0, message.modifiers & 0xf0 == 0 else {
      throw ROBRemoteDesktopProtocolError.invalid("sequence or modifiers")
    }
    let noKey = message.key == nil
    let noPayload = message.payload.isEmpty
    let noScroll = message.scrollX == 0 && message.scrollY == 0
    switch message.kind {
    case .start, .stop:
      guard noKey, noPayload, noScroll, message.modifiers == 0 else {
        throw ROBRemoteDesktopProtocolError.invalid("lifecycle message")
      }
    case .pointerMoved, .primaryDown, .primaryUp, .secondaryClick:
      guard noKey, noPayload, noScroll, message.modifiers == 0 else {
        throw ROBRemoteDesktopProtocolError.invalid("pointer message")
      }
    case .scroll:
      guard noKey, noPayload, message.modifiers == 0,
            message.scrollX != 0 || message.scrollY != 0 else {
        throw ROBRemoteDesktopProtocolError.invalid("scroll message")
      }
    case .text:
      guard noKey, !noPayload, message.payload.count <= maximumTextBytes,
            noScroll, message.modifiers == 0,
            String(data: message.payload, encoding: .utf8) != nil else {
        throw ROBRemoteDesktopProtocolError.invalid("text message")
      }
    case .key:
      guard message.key != nil, noPayload, noScroll else {
        throw ROBRemoteDesktopProtocolError.invalid("key message")
      }
    case .status:
      guard noKey, message.payload.count <= maximumStatusBytes, noScroll,
            message.modifiers == 0,
            String(data: message.payload, encoding: .utf8) != nil else {
        throw ROBRemoteDesktopProtocolError.invalid("status message")
      }
    }
  }
}

enum AutoNetTransportError: LocalizedError {
  case unsupportedService(String)
  case legacyDisabled
  case pairingRequired
  case invalidPairingCode
  case keychain(OSStatus)
  case randomGeneration(OSStatus)
  case identityUnavailable(String)
  case authenticationFailed
  case listenerUnavailable

  var errorDescription: String? {
    switch self {
    case .unsupportedService(let service):
      return "Unsupported robot-control Bonjour service: \(service)"
    case .legacyDisabled:
      return
        "Legacy plaintext AutoNet is disabled. Set ROB_CONTROL_ALLOW_LEGACY_AUTONET=1 only for a deliberate compatibility session."
    case .pairingRequired:
      return "No ROBController pairing key is installed."
    case .invalidPairingCode:
      return "The ROBController pairing code is invalid or incomplete."
    case .keychain(let status):
      return "Unable to access the robot-control pairing key in Keychain (OSStatus \(status))."
    case .randomGeneration(let status):
      return "Unable to create a robot-control pairing key (OSStatus \(status))."
    case .identityUnavailable(let detail):
      return "Unable to load the robot-control TLS identity: \(detail)"
    case .authenticationFailed:
      return "The ROBController pairing proof was rejected."
    case .listenerUnavailable:
      return "The robot-control listener could not be created."
    }
  }
}

struct ROBControlCredential: Codable, Equatable {
  let version: Int
  let robotID: UUID
  let controllerID: UUID
  let serviceType: String
  let applicationProtocol: String
  let certificateSHA256: Data
  let sharedSecret: Data

  var isValid: Bool {
    version == 2 && serviceType == ROBControlPairing.serviceType
      && applicationProtocol == ROBControlPairing.applicationProtocol
      && certificateSHA256.count == 32 && sharedSecret.count == 32
  }
}

/// Keychain-backed pairing material transferred out-of-band from Cerebro to a
/// trusted controller. Bonjour contains only routing metadata; the certificate
/// pin and shared secret exist only in this code and the two devices' Keychains.
@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
@objcMembers public final class ROBControlPairing: NSObject {
  public static let serviceType = "_robctl._udp"
  public static let legacyServiceType = "_roboNet._tcp"
  public static let applicationProtocol = "robctl/2"

  private static let keychainService = "com.orbitusrobotics.robctl.v2"
  private static let serverProfileAccount = "cerebro-server-profile"
  private static let clientProfileAccount = "paired-cerebro-profile"
  private static let legacySecretAccount = "tls-psk"
  private static let environmentKey = "ROB_CONTROL_PAIRING_SECRET"
  private static let pairingPrefix = "ROBCTL2:"
  private static let requiredSecretLength = 32
  private static let verifyQueue = DispatchQueue(label: "com.orbitusrobotics.robctl.v2.verify")

  public static var isPaired: Bool {
    guard let credential = try? loadCredential(account: clientProfileAccount) else { return false }
    return credential.isValid
  }

  /// Returns the already-installed code. This is intended only for a local,
  /// explicit pairing UI; callers must not log, persist, or advertise it.
  public static func currentPairingCode() -> String? {
    return try? ensurePairingCode()
  }

  /// Cerebro calls this once to create its persistent local pairing secret.
  /// ROBController should instead install the code shown by Cerebro.
  public static func ensurePairingCode() throws -> String {
    let credential = try serverCredential()
    let payload = try JSONEncoder().encode(credential)
    return pairingPrefix + payload.base64EncodedString()
  }

  /// Installs a code transferred directly from Cerebro. Replacing a code
  /// intentionally revokes the previous pairing on this device.
  public static func installPairingCode(_ code: String) throws {
    let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.range(of: pairingPrefix, options: [.anchored, .caseInsensitive]) != nil else {
      throw AutoNetTransportError.invalidPairingCode
    }
    let normalized =
      trimmed
      .replacingOccurrences(of: pairingPrefix, with: "", options: [.anchored, .caseInsensitive])
      .replacingOccurrences(of: " ", with: "")
    guard let payload = Data(base64Encoded: normalized),
      payload.count <= 4_096,
      let credential = try? JSONDecoder().decode(ROBControlCredential.self, from: payload),
      credential.isValid
    else {
      throw AutoNetTransportError.invalidPairingCode
    }
    try storeCredential(credential, account: clientProfileAccount)
  }

  public static func removePairing() throws {
    let status = SecItemDelete(genericQuery(account: clientProfileAccount) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw AutoNetTransportError.keychain(status)
    }
  }

  public static func legacyTransportIsEnabled() -> Bool {
    let environmentValue = ProcessInfo.processInfo.environment["ROB_CONTROL_ALLOW_LEGACY_AUTONET"]?
      .lowercased()
    if ["1", "true", "yes"].contains(environmentValue ?? "") {
      return true
    }
    return UserDefaults.standard.bool(forKey: "ROBControlAllowLegacyAutoNet")
  }

  static func serverAuthenticationMaterial() throws -> ROBControlCredential {
    try serverCredential()
  }

  static func clientAuthenticationMaterial() throws -> ROBControlCredential {
    if let code = ProcessInfo.processInfo.environment[environmentKey],
      !code.isEmpty,
      code.uppercased().hasPrefix(pairingPrefix)
    {
      try installPairingCode(code)
    }
    guard let credential = try loadCredential(account: clientProfileAccount), credential.isValid
    else {
      throw AutoNetTransportError.pairingRequired
    }
    return credential
  }

  static func makeV2ServerParameters() throws -> NWParameters {
    #if os(macOS)
      let loadedIdentity = try ROBControlIdentityStore.loadOrCreate()
      let quic = NWProtocolQUIC.Options(alpn: [applicationProtocol])
      quic.direction = .bidirectional
      quic.idleTimeout = 10_000
      let securityOptions = quic.securityProtocolOptions
      sec_protocol_options_set_min_tls_protocol_version(securityOptions, .TLSv13)
      guard let localIdentity = sec_identity_create(loadedIdentity.identity) else {
        throw AutoNetTransportError.identityUnavailable(
          "Security.framework could not bridge the Keychain identity")
      }
      sec_protocol_options_set_local_identity(securityOptions, localIdentity)
      return framedQUICParameters(options: quic)
    #else
      throw AutoNetTransportError.identityUnavailable(
        "Cerebro's QUIC listener is supported only on macOS")
    #endif
  }

  static func makeV2ClientParameters() throws -> NWParameters {
    let credential = try clientAuthenticationMaterial()
    return makeV2ClientParameters(pinnedCertificateSHA256: credential.certificateSHA256)
  }

  /// Internal injection point used by localhost transport fixtures.
  static func makeV2ClientParameters(pinnedCertificateSHA256 expectedFingerprint: Data)
    -> NWParameters
  {
    precondition(expectedFingerprint.count == 32)
    let quic = NWProtocolQUIC.Options(alpn: [applicationProtocol])
    quic.direction = .bidirectional
    quic.idleTimeout = 10_000
    let securityOptions = quic.securityProtocolOptions
    sec_protocol_options_set_min_tls_protocol_version(securityOptions, .TLSv13)
    sec_protocol_options_set_verify_block(
      securityOptions,
      { _, trust, complete in
        let trustReference = sec_trust_copy_ref(trust).takeRetainedValue()
        guard let chain = SecTrustCopyCertificateChain(trustReference) as? [SecCertificate],
          let leaf = chain.first
        else {
          complete(false)
          return
        }
        let leafData = SecCertificateCopyData(leaf) as Data
        complete(Data(SHA256.hash(data: leafData)) == expectedFingerprint)
      }, verifyQueue)
    return framedQUICParameters(options: quic)
  }

  static func serverBonjourTXTRecord() throws -> Data {
    let credential = try serverCredential()
    return NetService.data(fromTXTRecord: [
      "ver": Data("2".utf8),
      "alpn": Data(applicationProtocol.utf8),
      "robot_id": Data(credential.robotID.uuidString.lowercased().utf8),
    ])
  }

  static func pairedRobotID() -> UUID? {
    try? loadCredential(account: clientProfileAccount)?.robotID
  }

  static func robotID(fromBonjourMetadata metadata: NWBrowser.Result.Metadata) -> UUID? {
    guard case .bonjour(let txtRecord) = metadata,
      let string = txtRecord["robot_id"]
    else { return nil }
    return UUID(uuidString: string)
  }

  static func makeLegacyUDPParameters() throws -> NWParameters {
    guard legacyTransportIsEnabled() else {
      throw AutoNetTransportError.legacyDisabled
    }
    let parameters = NWParameters(dtls: nil, udp: NWProtocolUDP.Options())
    parameters.allowLocalEndpointReuse = true
    parameters.includePeerToPeer = true
    parameters.defaultProtocolStack.applicationProtocols.insert(
      NWProtocolFramer.Options(definition: LegacyAutoNetFramer.definition),
      at: 0
    )
    return parameters
  }

  private static func framedQUICParameters(options: NWProtocolQUIC.Options) -> NWParameters {
    let parameters = NWParameters(quic: options)
    parameters.allowLocalEndpointReuse = true
    parameters.includePeerToPeer = true
    parameters.serviceClass = .signaling
    parameters.defaultProtocolStack.applicationProtocols.insert(
      NWProtocolFramer.Options(definition: ROBV2ControlFramer.definition),
      at: 0
    )
    return parameters
  }

  private static func genericQuery(account: String) -> [String: Any] {
    return [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: account,
    ]
  }

  private static func loadData(account: String) throws -> Data? {
    var query = genericQuery(account: account)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecSuccess {
      return result as? Data
    }
    guard status == errSecItemNotFound else {
      throw AutoNetTransportError.keychain(status)
    }

    return nil
  }

  private static func storeData(_ data: Data, account: String) throws {
    let updateStatus = SecItemUpdate(
      genericQuery(account: account) as CFDictionary,
      [kSecValueData as String: data] as CFDictionary
    )
    if updateStatus == errSecSuccess {
      return
    }
    guard updateStatus == errSecItemNotFound else {
      throw AutoNetTransportError.keychain(updateStatus)
    }

    var addQuery = genericQuery(account: account)
    addQuery[kSecValueData as String] = data
    addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
    guard addStatus == errSecSuccess else {
      throw AutoNetTransportError.keychain(addStatus)
    }
  }

  private static func loadCredential(account: String) throws -> ROBControlCredential? {
    guard let data = try loadData(account: account) else { return nil }
    guard let credential = try? JSONDecoder().decode(ROBControlCredential.self, from: data),
      credential.isValid
    else {
      throw AutoNetTransportError.invalidPairingCode
    }
    return credential
  }

  private static func storeCredential(_ credential: ROBControlCredential, account: String) throws {
    guard credential.isValid else { throw AutoNetTransportError.invalidPairingCode }
    try storeData(try JSONEncoder().encode(credential), account: account)
  }

  private static func serverCredential() throws -> ROBControlCredential {
    #if os(macOS)
      let loadedIdentity = try ROBControlIdentityStore.loadOrCreate()
      let fingerprint = Data(
        SHA256.hash(data: SecCertificateCopyData(loadedIdentity.certificate) as Data))
      let existing = try loadCredential(account: serverProfileAccount)
      if let existing,
        existing.certificateSHA256 == fingerprint
      {
        return existing
      }

      let migratedSecret: Data?
      if let oldSecret = try loadData(account: legacySecretAccount),
        oldSecret.count == requiredSecretLength
      {
        migratedSecret = oldSecret
      } else if let environmentSecret = ProcessInfo.processInfo.environment[environmentKey],
        let decoded = Data(base64Encoded: environmentSecret), decoded.count == requiredSecretLength
      {
        migratedSecret = decoded
      } else {
        migratedSecret = nil
      }

      let credential = ROBControlCredential(
        version: 2,
        robotID: existing?.robotID ?? UUID(),
        controllerID: existing?.controllerID ?? UUID(),
        serviceType: serviceType,
        applicationProtocol: applicationProtocol,
        certificateSHA256: fingerprint,
        sharedSecret: try existing?.sharedSecret ?? migratedSecret
          ?? secureRandomData(count: requiredSecretLength)
      )
      try storeCredential(credential, account: serverProfileAccount)
      return credential
    #else
      throw AutoNetTransportError.identityUnavailable(
        "Cerebro's server identity is supported only on macOS")
    #endif
  }

  private static func secureRandomData(count: Int) throws -> Data {
    var data = Data(count: count)
    let status = data.withUnsafeMutableBytes { buffer in
      guard let baseAddress = buffer.baseAddress else { return errSecParam }
      return SecRandomCopyBytes(kSecRandomDefault, count, baseAddress)
    }
    guard status == errSecSuccess else { throw AutoNetTransportError.randomGeneration(status) }
    return data
  }
}

private enum ROBControlDER {
  static func tagged(_ tag: UInt8, _ content: Data) -> Data {
    var result = Data([tag])
    result.append(length(content.count))
    result.append(content)
    return result
  }
  static func sequence(_ elements: [Data]) -> Data {
    tagged(0x30, elements.reduce(into: Data()) { $0.append($1) })
  }
  static func set(_ elements: [Data]) -> Data {
    tagged(0x31, elements.reduce(into: Data()) { $0.append($1) })
  }
  static func explicit(_ number: UInt8, _ content: Data) -> Data { tagged(0xA0 | number, content) }
  static func boolean(_ value: Bool) -> Data { tagged(0x01, Data([value ? 0xFF : 0x00])) }
  static func integer(_ value: Int) -> Data {
    positiveInteger(withUnsafeBytes(of: UInt64(value).bigEndian) { Data($0) })
  }
  static func positiveInteger(_ bytes: Data) -> Data {
    var value = Data(bytes.drop(while: { $0 == 0 }))
    if value.isEmpty { value = Data([0]) }
    if value[0] & 0x80 != 0 { value.insert(0, at: 0) }
    return tagged(0x02, value)
  }
  static func objectIdentifier(_ dotted: String) throws -> Data {
    let arcs = try dotted.split(separator: ".").map { component -> UInt64 in
      guard let value = UInt64(component) else {
        throw AutoNetTransportError.identityUnavailable("invalid OID")
      }
      return value
    }
    guard arcs.count >= 2, arcs[0] <= 2, arcs[0] == 2 || arcs[1] <= 39 else {
      throw AutoNetTransportError.identityUnavailable("invalid OID")
    }
    var body = Data(base128(arcs[0] * 40 + arcs[1]))
    for arc in arcs.dropFirst(2) { body.append(contentsOf: base128(arc)) }
    return tagged(0x06, body)
  }
  static func utf8String(_ string: String) -> Data { tagged(0x0C, Data(string.utf8)) }
  static func generalizedTime(_ date: Date) -> Data {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyyMMddHHmmss'Z'"
    return tagged(0x18, Data(formatter.string(from: date).utf8))
  }
  static func bitString(_ bytes: Data, unusedBits: UInt8 = 0) -> Data {
    var body = Data([unusedBits])
    body.append(bytes)
    return tagged(0x03, body)
  }
  static func octetString(_ bytes: Data) -> Data { tagged(0x04, bytes) }
  private static func length(_ count: Int) -> Data {
    if count < 128 { return Data([UInt8(count)]) }
    var remaining = count
    var bytes: [UInt8] = []
    while remaining > 0 {
      bytes.insert(UInt8(remaining & 0xFF), at: 0)
      remaining >>= 8
    }
    return Data([0x80 | UInt8(bytes.count)] + bytes)
  }
  private static func base128(_ value: UInt64) -> [UInt8] {
    var remaining = value
    var bytes = [UInt8(remaining & 0x7F)]
    remaining >>= 7
    while remaining > 0 {
      bytes.insert(UInt8(remaining & 0x7F), at: 0)
      remaining >>= 7
    }
    if bytes.count > 1 { for index in 0..<(bytes.count - 1) { bytes[index] |= 0x80 } }
    return bytes
  }
}

#if os(macOS)
  private final class ROBControlIdentityStore {
    private static let certificateLabel = "ROB Control QUIC Server Identity v1"
    private static let keyLabel = "ROB Control QUIC P-256 Key v1"
    private static let keyTag = Data("com.orbitusrobotics.robctl.v2.p256.v1".utf8)
    struct LoadedIdentity {
      let identity: SecIdentity
      let certificate: SecCertificate
    }

    static func loadOrCreate() throws -> LoadedIdentity {
      if let certificate = try loadCertificate() {
        var identity: SecIdentity?
        let status = SecIdentityCreateWithCertificate(nil, certificate, &identity)
        guard status == errSecSuccess, let identity else {
          throw AutoNetTransportError.identityUnavailable(
            "private key missing (OSStatus \(status))")
        }
        return LoadedIdentity(identity: identity, certificate: certificate)
      }
      let privateKey = try loadPrivateKey() ?? createPrivateKey()
      let certificateData = try makeSelfSignedCertificate(privateKey: privateKey)
      guard let certificate = SecCertificateCreateWithData(nil, certificateData as CFData) else {
        throw AutoNetTransportError.identityUnavailable("generated X.509 certificate was rejected")
      }
      let status = SecItemAdd(
        [
          kSecClass as String: kSecClassCertificate, kSecAttrLabel as String: certificateLabel,
          kSecValueRef as String: certificate,
        ] as CFDictionary, nil)
      guard status == errSecSuccess || status == errSecDuplicateItem else {
        throw AutoNetTransportError.keychain(status)
      }
      let stored = try loadCertificate() ?? certificate
      var identity: SecIdentity?
      let identityStatus = SecIdentityCreateWithCertificate(nil, stored, &identity)
      guard identityStatus == errSecSuccess, let identity else {
        throw AutoNetTransportError.identityUnavailable(
          "could not form SecIdentity (OSStatus \(identityStatus))")
      }
      return LoadedIdentity(identity: identity, certificate: stored)
    }

    private static func loadCertificate() throws -> SecCertificate? {
      let query: [String: Any] = [
        kSecClass as String: kSecClassCertificate, kSecAttrLabel as String: certificateLabel,
        kSecReturnRef as String: true, kSecMatchLimit as String: kSecMatchLimitOne,
      ]
      var item: CFTypeRef?
      let status = SecItemCopyMatching(query as CFDictionary, &item)
      if status == errSecItemNotFound { return nil }
      guard status == errSecSuccess, let certificate = item as! SecCertificate? else {
        throw AutoNetTransportError.keychain(status)
      }
      return certificate
    }

    private static func loadPrivateKey() throws -> SecKey? {
      let query: [String: Any] = [
        kSecClass as String: kSecClassKey,
        kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
        kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
        kSecAttrApplicationTag as String: keyTag, kSecReturnRef as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne,
      ]
      var item: CFTypeRef?
      let status = SecItemCopyMatching(query as CFDictionary, &item)
      if status == errSecItemNotFound { return nil }
      guard status == errSecSuccess, let key = item as! SecKey? else {
        throw AutoNetTransportError.keychain(status)
      }
      return key
    }

    private static func createPrivateKey() throws -> SecKey {
      let attributes: [String: Any] = [
        kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
        kSecAttrKeySizeInBits as String: 256,
        kSecPrivateKeyAttrs as String: [
          kSecAttrIsPermanent as String: true, kSecAttrApplicationTag as String: keyTag,
          kSecAttrLabel as String: keyLabel,
        ],
      ]
      var error: Unmanaged<CFError>?
      guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
        throw AutoNetTransportError.identityUnavailable(
          error?.takeRetainedValue().localizedDescription ?? "P-256 key generation failed")
      }
      return key
    }

    private static func makeSelfSignedCertificate(privateKey: SecKey) throws -> Data {
      guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
        throw AutoNetTransportError.identityUnavailable("public key unavailable")
      }
      var exportError: Unmanaged<CFError>?
      guard let publicBytes = SecKeyCopyExternalRepresentation(publicKey, &exportError) as Data?,
        publicBytes.count == 65, publicBytes.first == 0x04
      else {
        throw AutoNetTransportError.identityUnavailable(
          exportError?.takeRetainedValue().localizedDescription ?? "P-256 public key export failed")
      }
      let signatureAlgorithm = ROBControlDER.sequence([
        try ROBControlDER.objectIdentifier("1.2.840.10045.4.3.2")
      ])
      let name = ROBControlDER.sequence([
        ROBControlDER.set([
          ROBControlDER.sequence([
            try ROBControlDER.objectIdentifier("2.5.4.3"),
            ROBControlDER.utf8String("Cerebro ROB Control"),
          ])
        ])
      ])
      let publicKeyInfo = ROBControlDER.sequence([
        ROBControlDER.sequence([
          try ROBControlDER.objectIdentifier("1.2.840.10045.2.1"),
          try ROBControlDER.objectIdentifier("1.2.840.10045.3.1.7"),
        ]), ROBControlDER.bitString(publicBytes),
      ])
      var serial = Data(count: 16)
      let randomStatus = serial.withUnsafeMutableBytes {
        SecRandomCopyBytes(kSecRandomDefault, $0.count, $0.baseAddress!)
      }
      guard randomStatus == errSecSuccess else {
        throw AutoNetTransportError.randomGeneration(randomStatus)
      }
      let now = Date()
      let validity = ROBControlDER.sequence([
        ROBControlDER.generalizedTime(now.addingTimeInterval(-300)),
        ROBControlDER.generalizedTime(now.addingTimeInterval(10 * 365 * 24 * 60 * 60)),
      ])
      let extensions = ROBControlDER.sequence([
        ROBControlDER.sequence([
          try ROBControlDER.objectIdentifier("2.5.29.19"), ROBControlDER.boolean(true),
          ROBControlDER.octetString(ROBControlDER.sequence([])),
        ]),
        ROBControlDER.sequence([
          try ROBControlDER.objectIdentifier("2.5.29.15"), ROBControlDER.boolean(true),
          ROBControlDER.octetString(ROBControlDER.bitString(Data([0x80]), unusedBits: 7)),
        ]),
        ROBControlDER.sequence([
          try ROBControlDER.objectIdentifier("2.5.29.37"),
          ROBControlDER.octetString(
            ROBControlDER.sequence([try ROBControlDER.objectIdentifier("1.3.6.1.5.5.7.3.1")])),
        ]),
      ])
      let tbs = ROBControlDER.sequence([
        ROBControlDER.explicit(0, ROBControlDER.integer(2)), ROBControlDER.positiveInteger(serial),
        signatureAlgorithm, name, validity, name, publicKeyInfo,
        ROBControlDER.explicit(3, extensions),
      ])
      var signError: Unmanaged<CFError>?
      guard
        let signature = SecKeyCreateSignature(
          privateKey, .ecdsaSignatureMessageX962SHA256, tbs as CFData, &signError) as Data?
      else {
        throw AutoNetTransportError.identityUnavailable(
          signError?.takeRetainedValue().localizedDescription ?? "certificate signing failed")
      }
      return ROBControlDER.sequence([tbs, signatureAlgorithm, ROBControlDER.bitString(signature)])
    }
  }
#endif

struct ROBControlAuthChallenge {
  static let encodedSize = 65
  let sessionID: Data
  let serverNonce: Data
  let robotID: UUID
  var encoded: Data {
    var data = Data([1])
    data.append(sessionID)
    data.append(serverNonce)
    data.append(robotID.robControlBytes)
    return data
  }
  init(sessionID: Data, serverNonce: Data, robotID: UUID) {
    self.sessionID = sessionID
    self.serverNonce = serverNonce
    self.robotID = robotID
  }
  init?(_ data: Data) {
    guard data.count == Self.encodedSize, data[0] == 1,
      let robotID = UUID(robControlBytes: data.subdata(in: 49..<65))
    else { return nil }
    self.sessionID = data.subdata(in: 1..<17)
    self.serverNonce = data.subdata(in: 17..<49)
    self.robotID = robotID
  }
}

struct ROBControlAuthProof {
  static let encodedSize = 97
  let sessionID: Data
  let controllerID: UUID
  let clientNonce: Data
  let mac: Data
  var encoded: Data {
    var data = Data([1])
    data.append(sessionID)
    data.append(controllerID.robControlBytes)
    data.append(clientNonce)
    data.append(mac)
    return data
  }
  init(sessionID: Data, controllerID: UUID, clientNonce: Data, mac: Data) {
    self.sessionID = sessionID
    self.controllerID = controllerID
    self.clientNonce = clientNonce
    self.mac = mac
  }
  init?(_ data: Data) {
    guard data.count == Self.encodedSize, data[0] == 1,
      let controllerID = UUID(robControlBytes: data.subdata(in: 17..<33))
    else { return nil }
    self.sessionID = data.subdata(in: 1..<17)
    self.controllerID = controllerID
    self.clientNonce = data.subdata(in: 33..<65)
    self.mac = data.subdata(in: 65..<97)
  }
}

struct ROBControlAuthAccepted {
  static let encodedSize = 65
  let sessionID: Data
  let controllerID: UUID
  let mac: Data
  var encoded: Data {
    var data = Data([1])
    data.append(sessionID)
    data.append(controllerID.robControlBytes)
    data.append(mac)
    return data
  }
  init(sessionID: Data, controllerID: UUID, mac: Data) {
    self.sessionID = sessionID
    self.controllerID = controllerID
    self.mac = mac
  }
  init?(_ data: Data) {
    guard data.count == Self.encodedSize, data[0] == 1,
      let controllerID = UUID(robControlBytes: data.subdata(in: 17..<33))
    else { return nil }
    self.sessionID = data.subdata(in: 1..<17)
    self.controllerID = controllerID
    self.mac = data.subdata(in: 33..<65)
  }
}

enum ROBControlAuthenticator {
  private static let transcriptDomain = Data("robctl/2\0".utf8)
  private static let clientDomain = Data("ROBCTL-AUTH-V1/CLIENT-PROOF\0".utf8)
  private static let serverDomain = Data("ROBCTL-AUTH-V1/SERVER-ACCEPTED\0".utf8)

  static func makeChallenge(robotID: UUID) throws -> ROBControlAuthChallenge {
    ROBControlAuthChallenge(
      sessionID: try random(count: 16), serverNonce: try random(count: 32), robotID: robotID)
  }
  static func makeProof(challenge: ROBControlAuthChallenge, credential: ROBControlCredential) throws
    -> ROBControlAuthProof
  {
    let nonce = try random(count: 32)
    let transcript = makeTranscript(
      challenge: challenge, controllerID: credential.controllerID, clientNonce: nonce)
    return ROBControlAuthProof(
      sessionID: challenge.sessionID, controllerID: credential.controllerID, clientNonce: nonce,
      mac: hmac(domain: clientDomain, transcript: transcript, secret: credential.sharedSecret))
  }
  static func validate(
    _ proof: ROBControlAuthProof, challenge: ROBControlAuthChallenge,
    credential: ROBControlCredential
  ) -> Bool {
    guard proof.sessionID == challenge.sessionID, proof.controllerID == credential.controllerID,
      challenge.robotID == credential.robotID
    else { return false }
    var input = clientDomain
    input.append(
      makeTranscript(
        challenge: challenge, controllerID: proof.controllerID, clientNonce: proof.clientNonce))
    return HMAC<SHA256>.isValidAuthenticationCode(
      proof.mac, authenticating: input, using: SymmetricKey(data: credential.sharedSecret))
  }
  static func accepted(
    for proof: ROBControlAuthProof, challenge: ROBControlAuthChallenge,
    credential: ROBControlCredential
  ) -> ROBControlAuthAccepted {
    let transcript = makeTranscript(
      challenge: challenge, controllerID: proof.controllerID, clientNonce: proof.clientNonce)
    var input = serverDomain
    input.append(transcript)
    input.append(proof.mac)
    let mac = Data(
      HMAC<SHA256>.authenticationCode(
        for: input, using: SymmetricKey(data: credential.sharedSecret)))
    return ROBControlAuthAccepted(
      sessionID: proof.sessionID, controllerID: proof.controllerID, mac: mac)
  }
  static func validate(
    _ accepted: ROBControlAuthAccepted, proof: ROBControlAuthProof,
    challenge: ROBControlAuthChallenge, credential: ROBControlCredential
  ) -> Bool {
    guard accepted.sessionID == challenge.sessionID,
      accepted.controllerID == credential.controllerID
    else { return false }
    var input = serverDomain
    input.append(
      makeTranscript(
        challenge: challenge, controllerID: proof.controllerID, clientNonce: proof.clientNonce))
    input.append(proof.mac)
    return HMAC<SHA256>.isValidAuthenticationCode(
      accepted.mac, authenticating: input, using: SymmetricKey(data: credential.sharedSecret))
  }
  private static func makeTranscript(
    challenge: ROBControlAuthChallenge, controllerID: UUID, clientNonce: Data
  ) -> Data {
    var data = transcriptDomain
    data.append(challenge.encoded)
    data.append(controllerID.robControlBytes)
    data.append(clientNonce)
    return data
  }
  private static func hmac(domain: Data, transcript: Data, secret: Data) -> Data {
    var input = domain
    input.append(transcript)
    return Data(HMAC<SHA256>.authenticationCode(for: input, using: SymmetricKey(data: secret)))
  }
  private static func random(count: Int) throws -> Data {
    var data = Data(count: count)
    let status = data.withUnsafeMutableBytes {
      SecRandomCopyBytes(kSecRandomDefault, $0.count, $0.baseAddress!)
    }
    guard status == errSecSuccess else { throw AutoNetTransportError.randomGeneration(status) }
    return data
  }
}

extension UUID {
  fileprivate var robControlBytes: Data {
    var value = uuid
    return withUnsafeBytes(of: &value) { Data($0) }
  }
  fileprivate init?(robControlBytes data: Data) {
    guard data.count == 16 else { return nil }
    var value: uuid_t = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    _ = withUnsafeMutableBytes(of: &value) { data.copyBytes(to: $0) }
    self.init(uuid: value)
  }
}

@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
enum AutoNetTransportMode {
  case v2
  case legacy

  init(service: String) throws {
    switch service {
    case ROBControlPairing.serviceType:
      self = .v2
    case ROBControlPairing.legacyServiceType:
      guard ROBControlPairing.legacyTransportIsEnabled() else {
        throw AutoNetTransportError.legacyDisabled
      }
      self = .legacy
    default:
      throw AutoNetTransportError.unsupportedService(service)
    }
  }

  var serviceType: String {
    switch self {
    case .v2: return ROBControlPairing.serviceType
    case .legacy: return ROBControlPairing.legacyServiceType
    }
  }

  var framerDefinition: NWProtocolFramer.Definition {
    switch self {
    case .v2: return ROBV2ControlFramer.definition
    case .legacy: return LegacyAutoNetFramer.definition
    }
  }

  func makeServerParameters() throws -> NWParameters {
    switch self {
    case .v2: return try ROBControlPairing.makeV2ServerParameters()
    case .legacy: return try ROBControlPairing.makeLegacyUDPParameters()
    }
  }

  func makeClientParameters() throws -> NWParameters {
    switch self {
    case .v2: return try ROBControlPairing.makeV2ClientParameters()
    case .legacy: return try ROBControlPairing.makeLegacyUDPParameters()
    }
  }

  func makeMessage(type: DataMessageType) -> NWProtocolFramer.Message {
    let message = NWProtocolFramer.Message(definition: framerDefinition)
    message.autoNetMessageType = type
    return message
  }

  func messageType(from context: NWConnection.ContentContext?) -> DataMessageType? {
    guard
      let message = context?.protocolMetadata(definition: framerDefinition)
        as? NWProtocolFramer.Message
    else {
      return nil
    }
    return message.autoNetMessageType
  }
}

@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
final class ROBV2ControlFramer: NWProtocolFramerImplementation {
  static let definition = NWProtocolFramer.Definition(implementation: ROBV2ControlFramer.self)
  static var label: String { "ROBControlV2" }

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
    guard messageLength <= ROBV2FrameHeader.maximumPayloadLength,
      messageLength >= 0,
      message.autoNetMessageType != .invalid,
      nextOutputSequence != UInt64.max
    else {
      framer.markFailed(error: NWError.posix(.EMSGSIZE))
      return
    }

    let header = ROBV2FrameHeader(
      type: message.autoNetMessageType,
      payloadLength: UInt32(messageLength),
      sequence: nextOutputSequence,
      messageID: UUID()
    )
    nextOutputSequence += 1
    framer.writeOutput(data: header.encodedData)
    do {
      try framer.writeOutputNoCopy(length: messageLength)
    } catch {
      framer.markFailed(error: NWError.posix(.EIO))
    }
  }

  func handleInput(framer: NWProtocolFramer.Instance) -> Int {
    while true {
      var parsedHeader: ROBV2FrameHeader?
      var malformed = false
      let headerSize = ROBV2FrameHeader.encodedSize
      let parsed = framer.parseInput(
        minimumIncompleteLength: headerSize,
        maximumLength: headerSize
      ) { buffer, _ in
        guard let buffer = buffer, buffer.count >= headerSize else { return 0 }
        parsedHeader = ROBV2FrameHeader(buffer)
        malformed = parsedHeader == nil
        return headerSize
      }

      guard parsed else { return headerSize }
      guard !malformed,
        let header = parsedHeader,
        header.sequence > lastInputSequence
      else {
        framer.markFailed(error: NWError.posix(.EPROTO))
        return 0
      }
      lastInputSequence = header.sequence

      let message = NWProtocolFramer.Message(definition: Self.definition)
      message.autoNetMessageType = header.type
      if !framer.deliverInputNoCopy(
        length: Int(header.payloadLength),
        message: message,
        isComplete: true
      ) {
        return 0
      }
    }
  }
}

private struct ROBV2FrameHeader {
  static let magic: UInt32 = 0x5243_544C  // "RCTL"
  static let version: UInt8 = 2
  static let encodedSize = 40
  static let maximumPayloadLength = 4 * 1024 * 1024

  let type: DataMessageType
  let payloadLength: UInt32
  let sequence: UInt64
  let messageID: [UInt8]

  init(type: DataMessageType, payloadLength: UInt32, sequence: UInt64, messageID: UUID) {
    self.type = type
    self.payloadLength = payloadLength
    self.sequence = sequence
    var uuid = messageID.uuid
    self.messageID = withUnsafeBytes(of: &uuid) { Array($0) }
  }

  init?(_ buffer: UnsafeMutableRawBufferPointer) {
    guard buffer.count >= Self.encodedSize,
      Self.readUInt32(buffer, offset: 0) == Self.magic,
      buffer[4] == Self.version,
      Int(buffer[5]) == Self.encodedSize,
      Self.readUInt16(buffer, offset: 8) == 0,
      Self.readUInt16(buffer, offset: 10) == 0,
      let type = DataMessageType(rawValue: UInt32(Self.readUInt16(buffer, offset: 6))),
      type != .invalid
    else {
      return nil
    }
    let length = Self.readUInt32(buffer, offset: 12)
    guard length <= UInt32(Self.maximumPayloadLength) else { return nil }

    self.type = type
    self.payloadLength = length
    self.sequence = Self.readUInt64(buffer, offset: 16)
    self.messageID = Array(UnsafeRawBufferPointer(rebasing: buffer[24..<40]))
  }

  var encodedData: Data {
    var data = Data(capacity: Self.encodedSize)
    data.appendBigEndian(Self.magic)
    data.append(Self.version)
    data.append(UInt8(Self.encodedSize))
    data.appendBigEndian(UInt16(type.rawValue))
    data.appendBigEndian(UInt16(0))  // flags
    data.appendBigEndian(UInt16(0))  // channel
    data.appendBigEndian(payloadLength)
    data.appendBigEndian(sequence)
    data.append(contentsOf: messageID)
    return data
  }

  private static func readUInt16(_ buffer: UnsafeMutableRawBufferPointer, offset: Int) -> UInt16 {
    return (UInt16(buffer[offset]) << 8) | UInt16(buffer[offset + 1])
  }

  private static func readUInt32(_ buffer: UnsafeMutableRawBufferPointer, offset: Int) -> UInt32 {
    return (UInt32(buffer[offset]) << 24) | (UInt32(buffer[offset + 1]) << 16)
      | (UInt32(buffer[offset + 2]) << 8) | UInt32(buffer[offset + 3])
  }

  private static func readUInt64(_ buffer: UnsafeMutableRawBufferPointer, offset: Int) -> UInt64 {
    var value: UInt64 = 0
    for index in offset..<(offset + 8) {
      value = (value << 8) | UInt64(buffer[index])
    }
    return value
  }
}

extension Data {
  fileprivate mutating func appendBigEndian(_ value: UInt16) {
    append(UInt8((value >> 8) & 0xff))
    append(UInt8(value & 0xff))
  }

  fileprivate mutating func appendBigEndian(_ value: UInt32) {
    append(UInt8((value >> 24) & 0xff))
    append(UInt8((value >> 16) & 0xff))
    append(UInt8((value >> 8) & 0xff))
    append(UInt8(value & 0xff))
  }

  fileprivate mutating func appendBigEndian(_ value: UInt64) {
    for shift in stride(from: 56, through: 0, by: -8) {
      append(UInt8((value >> UInt64(shift)) & 0xff))
    }
  }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
final class LegacyAutoNetFramer: NWProtocolFramerImplementation {
  static let definition = NWProtocolFramer.Definition(implementation: LegacyAutoNetFramer.self)
  static var label: String { "LegacyAutoNetPlaintextUDP" }

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
    guard messageLength >= 0,
      messageLength <= LegacyAutoNetHeader.maximumPayloadLength,
      message.autoNetMessageType != .invalid
    else {
      framer.markFailed(error: NWError.posix(.EMSGSIZE))
      return
    }
    let header = LegacyAutoNetHeader(
      type: message.autoNetMessageType.rawValue,
      length: UInt32(messageLength)
    )
    framer.writeOutput(data: header.encodedData)
    do {
      try framer.writeOutputNoCopy(length: messageLength)
    } catch {
      framer.markFailed(error: NWError.posix(.EIO))
    }
  }

  func handleInput(framer: NWProtocolFramer.Instance) -> Int {
    while true {
      var parsedHeader: LegacyAutoNetHeader?
      let headerSize = LegacyAutoNetHeader.encodedSize
      let parsed = framer.parseInput(
        minimumIncompleteLength: headerSize,
        maximumLength: headerSize
      ) { buffer, _ in
        guard let buffer = buffer, buffer.count >= headerSize else { return 0 }
        parsedHeader = LegacyAutoNetHeader(buffer)
        return headerSize
      }
      guard parsed else { return headerSize }
      guard let header = parsedHeader,
        header.length <= UInt32(LegacyAutoNetHeader.maximumPayloadLength),
        let type = DataMessageType(rawValue: header.type),
        type != .invalid
      else {
        framer.markFailed(error: NWError.posix(.EPROTO))
        return 0
      }

      let message = NWProtocolFramer.Message(definition: Self.definition)
      message.autoNetMessageType = type
      if !framer.deliverInputNoCopy(length: Int(header.length), message: message, isComplete: true)
      {
        return 0
      }
    }
  }
}

/// This is the only host-endian wire structure. It deliberately preserves the
/// original bug-compatible layout inside the legacy adapter.
private struct LegacyAutoNetHeader {
  static let encodedSize = MemoryLayout<UInt32>.size * 2
  static let maximumPayloadLength = 4 * 1024 * 1024

  let type: UInt32
  let length: UInt32

  init(type: UInt32, length: UInt32) {
    self.type = type
    self.length = length
  }

  init(_ buffer: UnsafeMutableRawBufferPointer) {
    var type: UInt32 = 0
    var length: UInt32 = 0
    withUnsafeMutableBytes(of: &type) { destination in
      destination.copyBytes(from: UnsafeRawBufferPointer(rebasing: buffer[0..<4]))
    }
    withUnsafeMutableBytes(of: &length) { destination in
      destination.copyBytes(from: UnsafeRawBufferPointer(rebasing: buffer[4..<8]))
    }
    self.type = type
    self.length = length
  }

  var encodedData: Data {
    var type = self.type
    var length = self.length
    var data = Data(bytes: &type, count: MemoryLayout<UInt32>.size)
    data.append(Data(bytes: &length, count: MemoryLayout<UInt32>.size))
    return data
  }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension NWProtocolFramer.Message {
  fileprivate var autoNetMessageType: DataMessageType {
    get { self["ROBControlMessageType"] as? DataMessageType ?? .invalid }
    set { self["ROBControlMessageType"] = newValue }
  }
}
