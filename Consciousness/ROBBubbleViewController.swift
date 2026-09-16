import SwiftUI
import UIKit

@MainActor @objcMembers final class ROBBubbleViewController: UIViewController {
    private let model = ROBBubbleConsoleModel()
    private weak var client: AutoNetClient?
    private var sequence: UInt64 = 0
    private var lastInbound: UInt64 = 0
    private var inboundSession: UUID?
    private var lifecycleObservers: [NSObjectProtocol] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: ROBBubbleConsole(model: model))
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        model.send = { [weak self] in self?.send($0) }
        lifecycleObservers.append(NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification,
            object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.model.suspend() } })
        lifecycleObservers.append(NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
            object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.model.sceneActive = true } })
    }
    deinit { lifecycleObservers.forEach(NotificationCenter.default.removeObserver) }
    func bindAutoNetClient(_ client: AutoNetClient) { self.client = client }
    func setConnectionAvailable(_ available: Bool) {
        if !available { model.status = nil; model.imageData = nil; model.frameID = nil }
    }
    func handleIncomingData(_ data: Data) -> Bool {
        guard ROBBubbleProtocol.claims(data) else { return false }
        guard let message = try? ROBBubbleProtocol.decode(data),
              message.command.operation == .status,
              message.controllerID == client?.authenticatedControllerID,
              message.sessionID == client?.authenticatedSessionID,
              ROBBubbleProtocol.isFresh(message, now: Date().timeIntervalSince1970),
              let status = message.status else { return true }
        if inboundSession != message.sessionID { inboundSession = message.sessionID; lastInbound = 0 }
        guard message.sequence > lastInbound else { return true }
        lastInbound = message.sequence
        model.consume(status)
        return true
    }
    private func send(_ command: ROBBubbleCommand) {
        guard let client, let controller = client.authenticatedControllerID,
              let session = client.authenticatedSessionID else {
            model.error = "Connect to an authenticated Cerebro session"; return
        }
        sequence &+= 1
        let message = ROBBubbleMessage(controllerID: controller, sessionID: session, sequence: sequence, command: command)
        if let data = try? ROBBubbleProtocol.encode(message) { client.send(data: data) }
    }
}
