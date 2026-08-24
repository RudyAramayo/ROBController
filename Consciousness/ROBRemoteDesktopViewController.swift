import UIKit

@objcMembers public final class ROBRemoteDesktopViewController: UIViewController {
    private weak var autoNetClient: AutoNetClient?
    private let videoClient = ROBRemoteDesktopVideoClient()
    private var connectionAvailable = false
    private var isDesktopVisible = false
    private var sequence: UInt64 = 0
    private var videoStatus = "OFFLINE"
    private var inputStatus = "Open Admin → Desktop to request access."
    private var inputControlAvailable = false
    private var latestNormalizedPoint = CGPoint(x: 0.5, y: 0.5)
    private var videoQuality = ROBRemoteDesktopVideoQuality(
        rawValue: UserDefaults.standard.integer(forKey: "ROBRemoteDesktop.videoQuality")
    ) ?? .maximumDetail

    private let statusPill = UILabel()
    private let detailLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private let modeControl = UISegmentedControl(items: ["Control", "Pan / Zoom"])
    private let qualityControl = UISegmentedControl(
        items: ROBRemoteDesktopVideoQuality.allCases.map(\.controlTitle)
    )
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let placeholderLabel = UILabel()
    private let textField = UITextField()
    private let sendTextButton = UIButton(type: .system)
    private let keyBar = UIStackView()

    public override func viewDidLoad() {
        super.viewDidLoad()
        videoClient.delegate = self
        buildInterface()
        refreshStatus()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isDesktopVisible = true
        beginDesktopIfPossible()
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isDesktopVisible = false
        send(kind: .stop)
        videoClient.stop()
    }

    public func bindAutoNetClient(_ client: AutoNetClient) {
        autoNetClient = client
        setConnectionAvailable(client.isConnected)
    }

    public func setConnectionAvailable(_ available: Bool) {
        dispatchPrecondition(condition: .onQueue(.main))
        connectionAvailable = available
        loadViewIfNeeded()
        if available, isDesktopVisible {
            beginDesktopIfPossible()
        } else if !available {
            videoClient.stop()
            videoStatus = "OFFLINE"
            inputStatus = "Connect to Cerebro to view and control its desktop."
            inputControlAvailable = false
            refreshStatus()
        }
    }

    /// Claims malformed desktop-control messages as well as valid status
    /// frames so they can never reach a historical robot command decoder.
    public func handleIncomingData(_ data: Data) -> Bool {
        guard ROBRemoteDesktopControlProtocol.claimsProtocol(data) else { return false }
        guard let message = try? ROBRemoteDesktopControlProtocol.decode(data),
              message.kind == .status,
              let status = String(data: message.payload, encoding: .utf8) else { return true }
        DispatchQueue.main.async { [weak self] in
            self?.consumeStatus(status)
        }
        return true
    }

    private func buildInterface() {
        view.backgroundColor = UIColor(red: 0.022, green: 0.03, blue: 0.045, alpha: 1)

        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.backgroundColor = UIColor(red: 0.045, green: 0.06, blue: 0.08, alpha: 1)
        view.addSubview(header)

        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = "CEREBRO DESKTOP"
        title.font = .monospacedSystemFont(ofSize: 17, weight: .bold)
        title.textColor = .white
        title.accessibilityIdentifier = "remoteDesktopTitle"
        header.addSubview(title)

        statusPill.translatesAutoresizingMaskIntoConstraints = false
        statusPill.font = .monospacedSystemFont(ofSize: 10, weight: .bold)
        statusPill.textAlignment = .center
        statusPill.textColor = .black
        statusPill.layer.cornerRadius = 9
        statusPill.layer.masksToBounds = true
        statusPill.accessibilityIdentifier = "remoteDesktopStatus"
        header.addSubview(statusPill)

        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        detailLabel.textColor = UIColor.white.withAlphaComponent(0.68)
        detailLabel.numberOfLines = 2
        detailLabel.lineBreakMode = .byTruncatingTail
        header.addSubview(detailLabel)

        var retryConfiguration = UIButton.Configuration.tinted()
        retryConfiguration.title = UIDevice.current.userInterfaceIdiom == .phone ? nil : "Reconnect"
        retryConfiguration.image = UIImage(systemName: "arrow.clockwise")
        retryConfiguration.imagePadding = 5
        retryButton.configuration = retryConfiguration
        retryButton.accessibilityLabel = "Reconnect Cerebro desktop"
        retryButton.accessibilityIdentifier = "remoteDesktopReconnect"
        retryButton.addTarget(self, action: #selector(retryPressed), for: .touchUpInside)
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(retryButton)

        modeControl.translatesAutoresizingMaskIntoConstraints = false
        modeControl.selectedSegmentIndex = 0
        modeControl.setTitleTextAttributes([.font: UIFont.monospacedSystemFont(ofSize: 11, weight: .semibold)], for: .normal)
        modeControl.accessibilityIdentifier = "remoteDesktopInteractionMode"
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)

        qualityControl.translatesAutoresizingMaskIntoConstraints = false
        qualityControl.selectedSegmentIndex = videoQuality.rawValue
        qualityControl.setTitleTextAttributes(
            [.font: UIFont.monospacedSystemFont(ofSize: 11, weight: .semibold)],
            for: .normal
        )
        qualityControl.accessibilityLabel = "Desktop video quality"
        qualityControl.accessibilityIdentifier = "remoteDesktopVideoQuality"
        qualityControl.addTarget(self, action: #selector(qualityChanged), for: .valueChanged)

        let desktopControls = UIStackView(arrangedSubviews: [qualityControl, modeControl])
        desktopControls.translatesAutoresizingMaskIntoConstraints = false
        desktopControls.axis = .horizontal
        desktopControls.distribution = .fillEqually
        desktopControls.spacing = 8
        header.addSubview(desktopControls)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 12
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = .black
        scrollView.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        scrollView.layer.borderWidth = 1
        view.addSubview(scrollView)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.backgroundColor = .black
        imageView.accessibilityLabel = "Live Cerebro desktop"
        scrollView.addSubview(imageView)

        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.text = "Waiting for Cerebro desktop…\nScreen Recording permission must be granted on the Mac."
        placeholderLabel.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        placeholderLabel.textColor = UIColor.white.withAlphaComponent(0.55)
        placeholderLabel.textAlignment = .center
        placeholderLabel.numberOfLines = 0
        scrollView.addSubview(placeholderLabel)

        let tap = UITapGestureRecognizer(target: self, action: #selector(primaryTapped(_:)))
        let drag = UIPanGestureRecognizer(target: self, action: #selector(primaryDragged(_:)))
        drag.minimumNumberOfTouches = 1
        drag.maximumNumberOfTouches = 1
        let rightClick = UILongPressGestureRecognizer(target: self, action: #selector(secondaryPressed(_:)))
        rightClick.minimumPressDuration = 0.55
        let remoteScroll = UIPanGestureRecognizer(target: self, action: #selector(remoteScrolled(_:)))
        remoteScroll.minimumNumberOfTouches = 2
        remoteScroll.maximumNumberOfTouches = 2
        remoteScroll.delegate = self
        tap.require(toFail: rightClick)
        imageView.addGestureRecognizer(tap)
        imageView.addGestureRecognizer(drag)
        imageView.addGestureRecognizer(rightClick)
        imageView.addGestureRecognizer(remoteScroll)

        let inputPanel = UIView()
        inputPanel.translatesAutoresizingMaskIntoConstraints = false
        inputPanel.backgroundColor = UIColor(red: 0.045, green: 0.06, blue: 0.08, alpha: 1)
        view.addSubview(inputPanel)

        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = "Type text into the selected Mac field"
        textField.borderStyle = .roundedRect
        textField.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        textField.textColor = .white
        textField.tintColor = .systemGreen
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.spellCheckingType = .no
        textField.returnKeyType = .send
        textField.delegate = self
        textField.accessibilityIdentifier = "remoteDesktopTextInput"
        inputPanel.addSubview(textField)

        var sendConfiguration = UIButton.Configuration.filled()
        sendConfiguration.title = "Type"
        if UIDevice.current.userInterfaceIdiom == .pad {
            sendConfiguration.image = UIImage(systemName: "keyboard")
            sendConfiguration.imagePadding = 5
        }
        sendTextButton.configuration = sendConfiguration
        sendTextButton.accessibilityIdentifier = "remoteDesktopSendText"
        sendTextButton.addTarget(self, action: #selector(sendTextPressed), for: .touchUpInside)
        sendTextButton.translatesAutoresizingMaskIntoConstraints = false
        inputPanel.addSubview(sendTextButton)

        keyBar.translatesAutoresizingMaskIntoConstraints = false
        keyBar.axis = .horizontal
        keyBar.distribution = .fillEqually
        keyBar.spacing = 5
        inputPanel.addSubview(keyBar)
        for item in [
            ("esc", ROBRemoteDesktopKey.escape, UInt8(0)),
            ("tab", .tab, 0),
            ("return", .returnKey, 0),
            ("delete", .delete, 0),
            ("⌘A", .letterA, ROBRemoteDesktopControlProtocol.modifierCommand),
            ("←", .leftArrow, 0),
            ("→", .rightArrow, 0)
        ] {
            let button = UIButton(type: .system)
            button.setTitle(item.0, for: .normal)
            button.titleLabel?.font = .monospacedSystemFont(ofSize: 10, weight: .semibold)
            button.backgroundColor = UIColor.white.withAlphaComponent(0.08)
            button.tintColor = .white
            button.layer.cornerRadius = 6
            button.addAction(UIAction { [weak self] _ in
                self?.sendKey(item.1, modifiers: item.2)
            }, for: .touchUpInside)
            keyBar.addArrangedSubview(button)
        }

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.topAnchor.constraint(equalTo: safe.topAnchor),
            header.heightAnchor.constraint(equalToConstant: 126),

            title.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 14),
            title.topAnchor.constraint(equalTo: header.topAnchor, constant: 9),
            statusPill.leadingAnchor.constraint(equalTo: title.trailingAnchor, constant: 8),
            statusPill.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            statusPill.heightAnchor.constraint(equalToConstant: 18),
            statusPill.widthAnchor.constraint(greaterThanOrEqualToConstant: 54),
            retryButton.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -10),
            retryButton.topAnchor.constraint(equalTo: header.topAnchor, constant: 6),
            retryButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            retryButton.heightAnchor.constraint(equalToConstant: 34),
            detailLabel.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: retryButton.trailingAnchor),
            detailLabel.topAnchor.constraint(equalTo: retryButton.bottomAnchor, constant: 2),
            detailLabel.bottomAnchor.constraint(lessThanOrEqualTo: desktopControls.topAnchor, constant: -5),
            desktopControls.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            desktopControls.trailingAnchor.constraint(equalTo: retryButton.trailingAnchor),
            desktopControls.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -7),
            desktopControls.heightAnchor.constraint(equalToConstant: 32),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: inputPanel.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
            placeholderLabel.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            placeholderLabel.widthAnchor.constraint(lessThanOrEqualTo: imageView.widthAnchor, constant: -32),

            inputPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputPanel.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
            inputPanel.heightAnchor.constraint(equalToConstant: 94),
            textField.leadingAnchor.constraint(equalTo: inputPanel.leadingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: sendTextButton.leadingAnchor, constant: -7),
            textField.topAnchor.constraint(equalTo: inputPanel.topAnchor, constant: 7),
            textField.heightAnchor.constraint(equalToConstant: 36),
            sendTextButton.trailingAnchor.constraint(equalTo: inputPanel.trailingAnchor, constant: -8),
            sendTextButton.topAnchor.constraint(equalTo: textField.topAnchor),
            sendTextButton.widthAnchor.constraint(equalToConstant: 82),
            sendTextButton.heightAnchor.constraint(equalTo: textField.heightAnchor),
            keyBar.leadingAnchor.constraint(equalTo: textField.leadingAnchor),
            keyBar.trailingAnchor.constraint(equalTo: sendTextButton.trailingAnchor),
            keyBar.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 6),
            keyBar.bottomAnchor.constraint(equalTo: inputPanel.bottomAnchor, constant: -7)
        ])
        updateInteractionMode()
    }

    private func beginDesktopIfPossible() {
        guard connectionAvailable, isDesktopVisible,
              let sessionID = autoNetClient?.authenticatedSessionID else {
            videoStatus = connectionAvailable ? "AUTHORIZING" : "OFFLINE"
            inputControlAvailable = false
            refreshStatus()
            return
        }
        inputControlAvailable = false
        send(kind: .start)
        videoClient.start(controlSessionID: sessionID, quality: videoQuality)
    }

    private func consumeStatus(_ status: String) {
        let pieces = status.split(separator: "|", maxSplits: 1).map(String.init)
        inputStatus = pieces.count == 2 ? pieces[1] : status
        inputControlAvailable = pieces.first == "READY"
        if pieces.first == "DENIED" { videoStatus = "DENIED" }
        refreshStatus()
    }

    private func refreshStatus() {
        guard isViewLoaded else { return }
        let upper = videoStatus.uppercased()
        statusPill.text = "  \(upper.contains("LIVE") ? "LIVE" : upper.prefix(10))  "
        statusPill.backgroundColor = upper.contains("LIVE")
            ? .systemGreen
            : (upper.contains("DENIED") || upper.contains("FAILED") ? .systemRed : .systemOrange)
        detailLabel.text = "\(videoStatus) • \(inputStatus)"
        let enabled = connectionAvailable && inputControlAvailable
        sendTextButton.isEnabled = enabled
        textField.isEnabled = enabled
        keyBar.arrangedSubviews.forEach { ($0 as? UIControl)?.isEnabled = enabled }
        retryButton.isEnabled = connectionAvailable
    }

    @objc private func retryPressed() {
        videoClient.stop()
        beginDesktopIfPossible()
    }

    @objc private func modeChanged() {
        updateInteractionMode()
    }

    @objc private func qualityChanged() {
        guard let selected = ROBRemoteDesktopVideoQuality(
            rawValue: qualityControl.selectedSegmentIndex
        ) else { return }
        videoQuality = selected
        UserDefaults.standard.set(selected.rawValue, forKey: "ROBRemoteDesktop.videoQuality")
        guard connectionAvailable, isDesktopVisible,
              let sessionID = autoNetClient?.authenticatedSessionID else { return }
        videoStatus = "SWITCHING TO \(selected.displayName)…"
        refreshStatus()
        videoClient.start(controlSessionID: sessionID, quality: selected)
    }

    private func updateInteractionMode() {
        let controlsDesktop = modeControl.selectedSegmentIndex == 0
        scrollView.panGestureRecognizer.isEnabled = !controlsDesktop
        for recognizer in imageView.gestureRecognizers ?? [] {
            if recognizer is UIPinchGestureRecognizer { continue }
            recognizer.isEnabled = controlsDesktop
        }
    }

    @objc private func primaryTapped(_ gesture: UITapGestureRecognizer) {
        guard let point = normalizedPoint(for: gesture) else { return }
        sendPointer(kind: .primaryDown, point: point)
        sendPointer(kind: .primaryUp, point: point)
    }

    @objc private func primaryDragged(_ gesture: UIPanGestureRecognizer) {
        guard let point = normalizedPoint(for: gesture) else {
            if gesture.state == .ended || gesture.state == .cancelled {
                sendPointer(kind: .primaryUp, point: latestNormalizedPoint)
            }
            return
        }
        switch gesture.state {
        case .began: sendPointer(kind: .primaryDown, point: point)
        case .changed: sendPointer(kind: .pointerMoved, point: point)
        case .ended, .cancelled, .failed: sendPointer(kind: .primaryUp, point: point)
        default: break
        }
    }

    @objc private func secondaryPressed(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let point = normalizedPoint(for: gesture) else { return }
        sendPointer(kind: .secondaryClick, point: point)
    }

    @objc private func remoteScrolled(_ gesture: UIPanGestureRecognizer) {
        guard gesture.state == .changed, let point = normalizedPoint(for: gesture) else { return }
        let translation = gesture.translation(in: imageView)
        gesture.setTranslation(.zero, in: imageView)
        let x = Int16(clamping: Int(-translation.x * 2))
        let y = Int16(clamping: Int(translation.y * 2))
        guard x != 0 || y != 0 else { return }
        send(kind: .scroll, point: point, scrollX: x, scrollY: y)
    }

    private func normalizedPoint(for gesture: UIGestureRecognizer) -> CGPoint? {
        guard let image = imageView.image else { return nil }
        let point = gesture.location(in: imageView)
        let bounds = imageView.bounds
        let scale = min(bounds.width / image.size.width, bounds.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let rect = CGRect(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
        guard rect.contains(point), rect.width > 0, rect.height > 0 else { return nil }
        let normalized = CGPoint(
            x: min(1, max(0, (point.x - rect.minX) / rect.width)),
            y: min(1, max(0, (point.y - rect.minY) / rect.height))
        )
        latestNormalizedPoint = normalized
        return normalized
    }

    @objc private func sendTextPressed() {
        guard let text = textField.text, !text.isEmpty else { return }
        var clipped = text
        while clipped.utf8.count > ROBRemoteDesktopControlProtocol.maximumTextBytes {
            clipped.removeLast()
        }
        guard !clipped.isEmpty else { return }
        send(kind: .text, payload: Data(clipped.utf8))
        textField.text = ""
    }

    private func sendKey(_ key: ROBRemoteDesktopKey, modifiers: UInt8) {
        send(kind: .key, modifiers: modifiers, key: key)
    }

    private func sendPointer(kind: ROBRemoteDesktopControlKind, point: CGPoint) {
        send(kind: kind, point: point)
    }

    private func send(
        kind: ROBRemoteDesktopControlKind,
        point: CGPoint = .zero,
        scrollX: Int16 = 0,
        scrollY: Int16 = 0,
        modifiers: UInt8 = 0,
        key: ROBRemoteDesktopKey? = nil,
        payload: Data = Data()
    ) {
        guard connectionAvailable, let autoNetClient else { return }
        if kind != .start && kind != .stop && !inputControlAvailable { return }
        sequence &+= 1
        guard sequence > 0 else { return }
        let message = ROBRemoteDesktopControlMessage(
            kind: kind,
            sequence: sequence,
            normalizedX: UInt16(clamping: Int(point.x * CGFloat(UInt16.max))),
            normalizedY: UInt16(clamping: Int(point.y * CGFloat(UInt16.max))),
            scrollX: scrollX,
            scrollY: scrollY,
            modifiers: modifiers,
            key: key,
            payload: payload
        )
        guard let data = try? ROBRemoteDesktopControlProtocol.encode(message) else { return }
        autoNetClient.send(data: data)
    }
}

extension ROBRemoteDesktopViewController: ROBRemoteDesktopVideoClientDelegate {
    func remoteDesktopVideoClient(
        _ client: ROBRemoteDesktopVideoClient,
        didReceiveJPEG data: Data
    ) {
        guard let image = UIImage(data: data) else { return }
        imageView.image = image
        placeholderLabel.isHidden = true
    }

    func remoteDesktopVideoClient(
        _ client: ROBRemoteDesktopVideoClient,
        didChangeStatus status: String
    ) {
        videoStatus = status
        placeholderLabel.text = status
        refreshStatus()
    }
}

extension ROBRemoteDesktopViewController: UIScrollViewDelegate {
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
}

extension ROBRemoteDesktopViewController: UITextFieldDelegate {
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendTextPressed()
        return false
    }
}

extension ROBRemoteDesktopViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        gestureRecognizer is UIPinchGestureRecognizer || otherGestureRecognizer is UIPinchGestureRecognizer
    }
}
