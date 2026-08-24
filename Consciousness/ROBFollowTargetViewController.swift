import UIKit

private final class ROBFollowPreviewView: UIView {
    var image: UIImage? { didSet { setNeedsDisplay() } }
    var candidates: [ROBFollowTargetCandidate] = [] { didSet { setNeedsDisplay() } }
    var selectedID: UUID? { didSet { setNeedsDisplay() } }
    var selectionHandler: ((UUID) -> Void)?

    override func draw(_ rect: CGRect) {
        UIColor(red: 0.012, green: 0.018, blue: 0.028, alpha: 1).setFill()
        UIRectFill(bounds)
        guard let image else { return }
        let imageRect = aspectFitRect(imageSize: image.size)
        image.draw(in: imageRect)
        for (index, candidate) in candidates.enumerated() {
            let candidateRect = displayRect(for: candidate, imageRect: imageRect)
            let selected = candidate.id == selectedID
            let color = selected ? UIColor.systemGreen : UIColor.systemYellow
            color.setStroke()
            let path = UIBezierPath(rect: candidateRect)
            path.lineWidth = selected ? 4 : 2
            path.stroke()

            let title = " \(index + 1) "
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 13, weight: .bold),
                .foregroundColor: UIColor.black,
                .backgroundColor: color
            ]
            title.draw(at: CGPoint(x: candidateRect.minX, y: max(imageRect.minY, candidateRect.minY - 18)), withAttributes: attributes)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self), let image else { return }
        let imageRect = aspectFitRect(imageSize: image.size)
        let matches = candidates.filter { displayRect(for: $0, imageRect: imageRect).insetBy(dx: -14, dy: -14).contains(point) }
        guard let nearest = matches.min(by: {
            distance(point, to: displayRect(for: $0, imageRect: imageRect).center)
                < distance(point, to: displayRect(for: $1, imageRect: imageRect).center)
        }) else { return }
        selectedID = nearest.id
        selectionHandler?(nearest.id)
    }

    private func aspectFitRect(imageSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
    }

    private func displayRect(for candidate: ROBFollowTargetCandidate, imageRect: CGRect) -> CGRect {
        let x = CGFloat(candidate.x) / 10_000
        let y = CGFloat(candidate.y) / 10_000
        let width = CGFloat(candidate.width) / 10_000
        let height = CGFloat(candidate.height) / 10_000
        return CGRect(
            x: imageRect.minX + x * imageRect.width,
            y: imageRect.minY + (1 - y - height) * imageRect.height,
            width: width * imageRect.width,
            height: height * imageRect.height
        )
    }

    private func distance(_ lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}

@objcMembers public final class ROBFollowTargetViewController: UIViewController {
    private weak var autoNetClient: AutoNetClient?
    private var connectionAvailable = false
    private var requestID = UUID()
    private var sequence: UInt64 = 0
    private var previewMessage: ROBFollowTargetMessage?
    private var selectedCandidateID: UUID?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let statusPill = UILabel()
    private let detailLabel = UILabel()
    private let previewView = ROBFollowPreviewView()
    private let selectedLabel = UILabel()
    private let refreshButton = UIButton(type: .system)
    private let authorizeButton = UIButton(type: .system)
    private let stopButton = UIButton(type: .system)
    private let preferredSlider = UISlider()
    private let maximumSlider = UISlider()
    private let speedSlider = UISlider()
    private let preferredValueLabel = UILabel()
    private let maximumValueLabel = UILabel()
    private let speedValueLabel = UILabel()

    public override func viewDidLoad() {
        super.viewDidLoad()
        buildInterface()
        refreshState(state: .idle, detail: "Request a fresh main-camera preview, then tap the person ROB should follow.")
    }

    public func bindAutoNetClient(_ client: AutoNetClient) {
        autoNetClient = client
        setConnectionAvailable(client.isConnected)
    }

    public func setConnectionAvailable(_ available: Bool) {
        dispatchPrecondition(condition: .onQueue(.main))
        connectionAvailable = available
        loadViewIfNeeded()
        refreshButton.isEnabled = available
        if !available {
            authorizeButton.isEnabled = false
            refreshState(state: .idle, detail: "Connect to Cerebro before selecting a follow target.")
        }
    }

    /// Claims valid and malformed follow frames so they cannot fall through to
    /// the historical controller parser.
    public func handleIncomingData(_ data: Data) -> Bool {
        guard ROBFollowTargetProtocol.claimsProtocol(data) else { return false }
        guard let message = try? ROBFollowTargetProtocol.decode(data),
              let client = autoNetClient,
              message.controllerID == client.authenticatedControllerID,
              message.sessionID == client.authenticatedSessionID else { return true }
        DispatchQueue.main.async { [weak self] in self?.consume(message) }
        return true
    }

    private func buildInterface() {
        view.backgroundColor = UIColor(red: 0.022, green: 0.03, blue: 0.045, alpha: 1)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 14
        contentStack.layoutMargins = UIEdgeInsets(top: 14, left: 16, bottom: 28, right: 16)
        contentStack.isLayoutMarginsRelativeArrangement = true
        scrollView.addSubview(contentStack)

        let title = UILabel()
        title.text = "VISUAL FOLLOW MODE"
        title.font = .monospacedSystemFont(ofSize: 19, weight: .bold)
        title.textColor = .white
        title.accessibilityIdentifier = "followModeTitle"

        statusPill.font = .monospacedSystemFont(ofSize: 11, weight: .bold)
        statusPill.textAlignment = .center
        statusPill.layer.cornerRadius = 10
        statusPill.layer.masksToBounds = true
        statusPill.widthAnchor.constraint(equalToConstant: 118).isActive = true
        statusPill.heightAnchor.constraint(equalToConstant: 24).isActive = true
        let header = UIStackView(arrangedSubviews: [title, UIView(), statusPill])
        header.axis = .horizontal
        header.alignment = .center
        contentStack.addArrangedSubview(header)

        detailLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        detailLabel.textColor = UIColor.white.withAlphaComponent(0.72)
        detailLabel.numberOfLines = 0
        contentStack.addArrangedSubview(detailLabel)

        previewView.translatesAutoresizingMaskIntoConstraints = false
        previewView.layer.cornerRadius = 10
        previewView.layer.masksToBounds = true
        previewView.layer.borderWidth = 1
        previewView.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        previewView.heightAnchor.constraint(equalTo: previewView.widthAnchor, multiplier: 2.0 / 3.0).isActive = true
        previewView.accessibilityIdentifier = "followTargetPreview"
        previewView.selectionHandler = { [weak self] id in self?.selectCandidate(id) }
        contentStack.addArrangedSubview(previewView)

        selectedLabel.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
        selectedLabel.textColor = .systemYellow
        selectedLabel.text = "No person selected"
        selectedLabel.numberOfLines = 2
        contentStack.addArrangedSubview(selectedLabel)

        configureSlider(preferredSlider, minimum: 1.4, maximum: 2.4, value: 1.8, action: #selector(sliderChanged))
        configureSlider(maximumSlider, minimum: 2.4, maximum: 3.8, value: 2.8, action: #selector(sliderChanged))
        configureSlider(speedSlider, minimum: 0.06, maximum: 0.16, value: 0.12, action: #selector(sliderChanged))
        contentStack.addArrangedSubview(controlRow(title: "Preferred distance", slider: preferredSlider, value: preferredValueLabel))
        contentStack.addArrangedSubview(controlRow(title: "Maximum distance", slider: maximumSlider, value: maximumValueLabel))
        contentStack.addArrangedSubview(controlRow(title: "Maximum tread speed", slider: speedSlider, value: speedValueLabel))
        sliderChanged()

        var refreshConfiguration = UIButton.Configuration.tinted()
        refreshConfiguration.title = "Refresh Main-Camera Preview"
        refreshConfiguration.image = UIImage(systemName: "camera.viewfinder")
        refreshConfiguration.imagePadding = 8
        refreshButton.configuration = refreshConfiguration
        refreshButton.accessibilityIdentifier = "followRefreshPreview"
        refreshButton.addTarget(self, action: #selector(refreshPressed), for: .touchUpInside)

        var authorizeConfiguration = UIButton.Configuration.filled()
        authorizeConfiguration.title = "Authorize Selected Person"
        authorizeConfiguration.image = UIImage(systemName: "person.badge.shield.checkmark")
        authorizeConfiguration.imagePadding = 8
        authorizeConfiguration.baseBackgroundColor = .systemGreen
        authorizeButton.configuration = authorizeConfiguration
        authorizeButton.accessibilityIdentifier = "followAuthorizeTarget"
        authorizeButton.isEnabled = false
        authorizeButton.addTarget(self, action: #selector(authorizePressed), for: .touchUpInside)

        var stopConfiguration = UIButton.Configuration.filled()
        stopConfiguration.title = "STOP FOLLOW MODE"
        stopConfiguration.image = UIImage(systemName: "stop.fill")
        stopConfiguration.imagePadding = 8
        stopConfiguration.baseBackgroundColor = .systemRed
        stopButton.configuration = stopConfiguration
        stopButton.accessibilityIdentifier = "followStop"
        stopButton.addTarget(self, action: #selector(stopPressed), for: .touchUpInside)

        contentStack.addArrangedSubview(refreshButton)
        contentStack.addArrangedSubview(authorizeButton)
        contentStack.addArrangedSubview(stopButton)

        let safety = UILabel()
        safety.text = "Treads stop on target loss, missing depth, stale belly RGB-D, stale RPLidar, or blocked terrain. Insta360 delay is used only to re-aim the camera/waist; it never moves the treads."
        safety.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        safety.textColor = UIColor.systemOrange.withAlphaComponent(0.9)
        safety.numberOfLines = 0
        contentStack.addArrangedSubview(safety)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: safe.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    private func configureSlider(_ slider: UISlider, minimum: Float, maximum: Float, value: Float, action: Selector) {
        slider.minimumValue = minimum
        slider.maximumValue = maximum
        slider.value = value
        slider.addTarget(self, action: action, for: .valueChanged)
    }

    private func controlRow(title: String, slider: UISlider, value: UILabel) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
        label.textColor = .white
        value.font = .monospacedSystemFont(ofSize: 11, weight: .bold)
        value.textColor = .systemTeal
        value.textAlignment = .right
        value.widthAnchor.constraint(equalToConstant: 66).isActive = true
        let heading = UIStackView(arrangedSubviews: [label, UIView(), value])
        heading.axis = .horizontal
        let stack = UIStackView(arrangedSubviews: [heading, slider])
        stack.axis = .vertical
        stack.spacing = 4
        return stack
    }

    @objc private func sliderChanged() {
        if maximumSlider.value < preferredSlider.value + 0.2 {
            maximumSlider.value = min(maximumSlider.maximumValue, preferredSlider.value + 0.2)
        }
        preferredValueLabel.text = String(format: "%.1f m", preferredSlider.value)
        maximumValueLabel.text = String(format: "%.1f m", maximumSlider.value)
        speedValueLabel.text = String(format: "%.0f%%", speedSlider.value * 100)
    }

    @objc private func refreshPressed() {
        guard let identity = authenticatedIdentity() else { return }
        requestID = UUID()
        selectedCandidateID = nil
        previewMessage = nil
        previewView.image = nil
        previewView.candidates = []
        previewView.selectedID = nil
        selectedLabel.text = "Waiting for Cerebro…"
        authorizeButton.isEnabled = false
        send(ROBFollowTargetMessage(
            kind: .previewRequest,
            requestID: requestID,
            controllerID: identity.controller,
            sessionID: identity.session,
            sequence: nextSequence(),
            sentAtMilliseconds: Self.nowMilliseconds
        ))
        refreshState(state: .idle, detail: "Waiting for a fresh main-camera frame and person detection…")
    }

    private func selectCandidate(_ id: UUID) {
        guard let previewMessage,
              let index = previewMessage.candidates.firstIndex(where: { $0.id == id }) else { return }
        selectedCandidateID = id
        authorizeButton.isEnabled = connectionAvailable
        let candidate = previewMessage.candidates[index]
        let distance = candidate.distanceMillimeters.map { String(format: " • %.1f m", Double($0) / 1_000) } ?? " • depth pending"
        selectedLabel.text = "Person \(index + 1) selected\(distance)"
    }

    @objc private func authorizePressed() {
        guard let id = selectedCandidateID,
              previewMessage?.requestID == requestID else { return }
        let alert = UIAlertController(
            title: "Authorize Follow Mode?",
            message: "ROB will follow the green-boxed person only. The treads can move autonomously after all depth, belly-camera, and RPLidar safety checks pass.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Authorize", style: .default) { [weak self] _ in
            self?.sendAuthorization(candidateID: id)
        })
        present(alert, animated: true)
    }

    private func sendAuthorization(candidateID: UUID) {
        guard let identity = authenticatedIdentity() else { return }
        let preferred = UInt16((preferredSlider.value * 100).rounded())
        let maximum = UInt16((maximumSlider.value * 100).rounded())
        let speed = UInt16((speedSlider.value * 1_000).rounded())
        send(ROBFollowTargetMessage(
            kind: .authorize,
            requestID: requestID,
            controllerID: identity.controller,
            sessionID: identity.session,
            sequence: nextSequence(),
            sentAtMilliseconds: Self.nowMilliseconds,
            selectedCandidateID: candidateID,
            minimumDistanceCentimeters: 120,
            preferredDistanceCentimeters: preferred,
            maximumDistanceCentimeters: maximum,
            maximumSpeedPermille: speed
        ))
        authorizeButton.isEnabled = false
        refreshState(state: .idle, detail: "Authorization sent. Cerebro is preparing the full-pan-safe tracking pose.")
    }

    @objc private func stopPressed() {
        guard let identity = authenticatedIdentity() else { return }
        send(ROBFollowTargetMessage(
            kind: .stop,
            requestID: requestID,
            controllerID: identity.controller,
            sessionID: identity.session,
            sequence: nextSequence(),
            sentAtMilliseconds: Self.nowMilliseconds,
            detail: "Stopped by ROBController"
        ))
        refreshState(state: .stopped, detail: "Stop requested. Cerebro will release follow motion authority and the waist motor.")
    }

    private func consume(_ message: ROBFollowTargetMessage) {
        guard message.requestID == requestID else { return }
        if message.kind == .preview,
           let jpeg = message.previewJPEG,
           let image = UIImage(data: jpeg) {
            previewMessage = message
            selectedCandidateID = nil
            previewView.image = image
            previewView.candidates = message.candidates
            previewView.selectedID = nil
            selectedLabel.text = "Tap one outlined person to select the authorized target."
        }
        if let state = message.state {
            refreshState(state: state, detail: message.detail ?? state.rawValue)
        }
    }

    private func refreshState(state: ROBFollowTargetState, detail: String) {
        statusPill.text = state.rawValue.uppercased()
        detailLabel.text = detail
        switch state {
        case .following: statusPill.backgroundColor = .systemGreen
        case .targetLost: statusPill.backgroundColor = .systemOrange
        case .blocked: statusPill.backgroundColor = .systemYellow
        case .previewReady: statusPill.backgroundColor = .systemTeal
        case .idle, .stopped: statusPill.backgroundColor = .systemGray
        }
        statusPill.textColor = .black
    }

    private func authenticatedIdentity() -> (controller: UUID, session: UUID)? {
        guard connectionAvailable,
              let controller = autoNetClient?.authenticatedControllerID,
              let session = autoNetClient?.authenticatedSessionID else {
            refreshState(state: .idle, detail: "The authenticated Cerebro session is not ready.")
            return nil
        }
        return (controller, session)
    }

    private func send(_ message: ROBFollowTargetMessage) {
        guard let data = try? ROBFollowTargetProtocol.encode(message) else {
            refreshState(state: .blocked, detail: "The follow request failed local safety validation.")
            return
        }
        autoNetClient?.send(data: data)
    }

    private func nextSequence() -> UInt64 {
        sequence &+= 1
        return sequence
    }

    private static var nowMilliseconds: UInt64 {
        UInt64(Date().timeIntervalSince1970 * 1_000)
    }
}
