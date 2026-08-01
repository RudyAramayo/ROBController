import Foundation

@main
struct ROBControlTransportSecurityFixtureTests {
    static func main() throws {
        let credential = ROBControlCredential(
            version: 2,
            robotID: UUID(),
            controllerID: UUID(),
            serviceType: ROBControlPairing.serviceType,
            applicationProtocol: ROBControlPairing.applicationProtocol,
            certificateSHA256: Data(repeating: 0xA5, count: 32),
            sharedSecret: Data((0..<32).map(UInt8.init))
        )
        let challenge = try ROBControlAuthenticator.makeChallenge(robotID: credential.robotID)
        let proof = try ROBControlAuthenticator.makeProof(challenge: challenge, credential: credential)
        precondition(ROBControlAuthenticator.validate(proof, challenge: challenge, credential: credential))

        let accepted = ROBControlAuthenticator.accepted(for: proof, challenge: challenge, credential: credential)
        precondition(ROBControlAuthenticator.validate(accepted, proof: proof, challenge: challenge, credential: credential))

        let wrong = ROBControlCredential(
            version: 2,
            robotID: credential.robotID,
            controllerID: credential.controllerID,
            serviceType: credential.serviceType,
            applicationProtocol: credential.applicationProtocol,
            certificateSHA256: credential.certificateSHA256,
            sharedSecret: Data(repeating: 0x5A, count: 32)
        )
        precondition(!ROBControlAuthenticator.validate(proof, challenge: challenge, credential: wrong))
        let freshChallenge = try ROBControlAuthenticator.makeChallenge(robotID: credential.robotID)
        precondition(!ROBControlAuthenticator.validate(proof, challenge: freshChallenge, credential: credential))
        print("ROBController v2 pairing security fixtures passed")
    }
}
