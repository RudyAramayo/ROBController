//
//  ROBAdministratorTerminalViewController.swift
//  ROBController
//
//  Multi-tab terminal client for administrator-authorized Cerebro PTYs.
//

import SwiftTerm
import UIKit

@objcMembers public final class ROBAdministratorTerminalViewController: UIViewController {
    private enum SessionState {
        case offline
        case opening
        case ready(String)
        case exited(String)
        case denied(String)

        var shortLabel: String {
            switch self {
            case .offline: return "OFFLINE"
            case .opening: return "CONNECTING"
            case .ready: return "READY"
            case .exited: return "EXITED"
            case .denied: return "DENIED"
            }
        }

        var detail: String {
            switch self {
            case .offline: return "Connect to Cerebro to attach this shell."
            case .opening: return "Requesting an administrator PTY from Cerebro…"
            case .ready(let directory): return "Shell on Cerebro • \(directory)"
            case .exited(let reason), .denied(let reason): return reason
            }
        }

        var color: UIColor {
            switch self {
            case .ready: return .systemGreen
            case .opening: return .systemOrange
            case .offline, .exited: return .systemGray
            case .denied: return .systemRed
            }
        }

        var acceptsInput: Bool {
            if case .ready = self { return true }
            return false
        }
    }

    private final class TerminalTab {
        let id = UUID()
        let terminalView = TerminalView(frame: .zero)
        var displayName: String
        var requestSequence: UInt64 = 0
        var lastInboundSequence: UInt64 = 0
        var columns: UInt16 = 100
        var rows: UInt16 = 30
        var state: SessionState = .offline

        init(number: Int) {
            displayName = "Shell \(number)"
        }

        func nextRequestSequence() -> UInt64 {
            requestSequence &+= 1
            return requestSequence
        }
    }

    private weak var autoNetClient: AutoNetClient?
    private var connectionAvailable = false
    private var pendingCloseRequests: [(terminalID: UUID, sequence: UInt64)] = []
    private var tabs: [TerminalTab] = []
    private var selectedTabID: UUID?
    private var nextTabNumber = 1

    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let statusPill = UILabel()
    private let detailLabel = UILabel()
    private let addButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let codexButton = UIButton(type: .system)
    private let tabsScrollView = UIScrollView()
    private let tabsStackView = UIStackView()
    private let terminalContainer = UIView()
    private let keyBar = UIStackView()

    public override func viewDidLoad() {
        super.viewDidLoad()
        buildInterface()
        createTab(select: true)
        refreshInterface()
    }

    public func bindAutoNetClient(_ client: AutoNetClient) {
        autoNetClient = client
        setConnectionAvailable(client.isConnected)
    }

    public func setConnectionAvailable(_ available: Bool) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard connectionAvailable != available else { return }
        connectionAvailable = available
        loadViewIfNeeded()
        if available {
            flushPendingCloseRequests()
            for tab in tabs {
                tab.state = .opening
                sendOpen(for: tab)
            }
        } else {
            for tab in tabs where tab.state.acceptsInput || isOpening(tab.state) {
                tab.state = .offline
            }
        }
        refreshInterface()
    }

    /// Returns true for every terminal-discriminated frame, including malformed
    /// frames, so Objective-C never forwards shell data to another protocol.
    public func handleIncomingData(_ data: Data) -> Bool {
        guard ROBAdministratorTerminalProtocol.claimsProtocol(data) else { return false }
        guard let message = try? ROBAdministratorTerminalProtocol.decode(data) else { return true }
        DispatchQueue.main.async { [weak self] in self?.consume(message) }
        return true
    }

    private var selectedTab: TerminalTab? {
        guard let selectedTabID else { return nil }
        return tabs.first { $0.id == selectedTabID }
    }

    private func buildInterface() {
        view.backgroundColor = UIColor(red: 0.025, green: 0.035, blue: 0.05, alpha: 1)

        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = UIColor(red: 0.045, green: 0.06, blue: 0.08, alpha: 1)
        view.addSubview(headerView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        let usesCompactHeader = UIDevice.current.userInterfaceIdiom == .phone
        titleLabel.text = usesCompactHeader ? "ADMIN TERMINAL" : "ADMINISTRATOR TERMINAL"
        titleLabel.font = .monospacedSystemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.accessibilityIdentifier = "administratorTerminalTitle"
        headerView.addSubview(titleLabel)

        statusPill.translatesAutoresizingMaskIntoConstraints = false
        statusPill.font = .monospacedSystemFont(ofSize: 10, weight: .bold)
        statusPill.textAlignment = .center
        statusPill.textColor = .black
        statusPill.layer.cornerRadius = 9
        statusPill.layer.masksToBounds = true
        statusPill.accessibilityIdentifier = "administratorTerminalStatus"
        headerView.addSubview(statusPill)

        var addConfiguration = UIButton.Configuration.tinted()
        addConfiguration.title = usesCompactHeader ? nil : "New"
        addConfiguration.image = UIImage(systemName: "plus")
        addConfiguration.imagePadding = 5
        addButton.configuration = addConfiguration
        addButton.accessibilityIdentifier = "administratorTerminalNewTab"
        addButton.addTarget(self, action: #selector(addTabPressed), for: .touchUpInside)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(addButton)

        var closeConfiguration = UIButton.Configuration.tinted()
        closeConfiguration.title = usesCompactHeader ? nil : "Close"
        closeConfiguration.image = UIImage(systemName: "xmark")
        closeConfiguration.imagePadding = 5
        closeButton.configuration = closeConfiguration
        closeButton.tintColor = .systemRed
        closeButton.accessibilityIdentifier = "administratorTerminalCloseTab"
        closeButton.addTarget(self, action: #selector(closeTabPressed), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(closeButton)

        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        detailLabel.textColor = UIColor.white.withAlphaComponent(0.62)
        detailLabel.numberOfLines = 1
        detailLabel.lineBreakMode = .byTruncatingMiddle
        detailLabel.accessibilityIdentifier = "administratorTerminalDetail"
        headerView.addSubview(detailLabel)

        var codexConfiguration = UIButton.Configuration.filled()
        codexConfiguration.title = "Open Codex"
        codexConfiguration.image = UIImage(systemName: "chevron.left.forwardslash.chevron.right")
        codexConfiguration.imagePadding = 7
        codexConfiguration.cornerStyle = .medium
        codexButton.configuration = codexConfiguration
        codexButton.accessibilityIdentifier = "administratorTerminalOpenCodex"
        codexButton.addTarget(self, action: #selector(openCodexPressed), for: .touchUpInside)
        codexButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(codexButton)

        tabsScrollView.translatesAutoresizingMaskIntoConstraints = false
        tabsScrollView.backgroundColor = UIColor.black.withAlphaComponent(0.24)
        tabsScrollView.showsHorizontalScrollIndicator = false
        tabsScrollView.alwaysBounceHorizontal = true
        view.addSubview(tabsScrollView)

        tabsStackView.translatesAutoresizingMaskIntoConstraints = false
        tabsStackView.axis = .horizontal
        tabsStackView.alignment = .fill
        tabsStackView.spacing = 6
        tabsScrollView.addSubview(tabsStackView)

        terminalContainer.translatesAutoresizingMaskIntoConstraints = false
        terminalContainer.backgroundColor = .black
        terminalContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        terminalContainer.layer.borderWidth = 1
        view.addSubview(terminalContainer)

        keyBar.translatesAutoresizingMaskIntoConstraints = false
        keyBar.axis = .horizontal
        keyBar.spacing = 6
        keyBar.distribution = .fillEqually
        keyBar.isLayoutMarginsRelativeArrangement = true
        keyBar.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
        keyBar.backgroundColor = UIColor(red: 0.045, green: 0.06, blue: 0.08, alpha: 1)
        view.addSubview(keyBar)
        for (title, bytes) in [
            ("esc", [UInt8(0x1b)]),
            ("tab", [UInt8(0x09)]),
            ("ctrl-c", [UInt8(0x03)]),
            ("←", Array("\u{1b}[D".utf8)),
            ("↑", Array("\u{1b}[A".utf8)),
            ("↓", Array("\u{1b}[B".utf8)),
            ("→", Array("\u{1b}[C".utf8))
        ] {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
            button.backgroundColor = UIColor.white.withAlphaComponent(0.08)
            button.tintColor = .white
            button.layer.cornerRadius = 6
            button.accessibilityLabel = title
            button.addAction(UIAction { [weak self] _ in self?.sendInput(Data(bytes)) }, for: .touchUpInside)
            keyBar.addArrangedSubview(button)
        }

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.topAnchor.constraint(equalTo: safe.topAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 82),

            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 14),
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 10),
            statusPill.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 9),
            statusPill.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            statusPill.heightAnchor.constraint(equalToConstant: 18),
            statusPill.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),

            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -10),
            closeButton.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 7),
            closeButton.heightAnchor.constraint(equalToConstant: 34),
            addButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -6),
            addButton.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 7),
            addButton.heightAnchor.constraint(equalToConstant: 34),

            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(lessThanOrEqualTo: codexButton.leadingAnchor, constant: -12),
            detailLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -10),
            codexButton.trailingAnchor.constraint(equalTo: closeButton.trailingAnchor),
            codexButton.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -7),
            codexButton.heightAnchor.constraint(equalToConstant: 34),

            tabsScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabsScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabsScrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tabsScrollView.heightAnchor.constraint(equalToConstant: 44),
            tabsStackView.leadingAnchor.constraint(equalTo: tabsScrollView.contentLayoutGuide.leadingAnchor, constant: 8),
            tabsStackView.trailingAnchor.constraint(equalTo: tabsScrollView.contentLayoutGuide.trailingAnchor, constant: -8),
            tabsStackView.topAnchor.constraint(equalTo: tabsScrollView.contentLayoutGuide.topAnchor, constant: 5),
            tabsStackView.bottomAnchor.constraint(equalTo: tabsScrollView.contentLayoutGuide.bottomAnchor, constant: -5),
            tabsStackView.heightAnchor.constraint(equalTo: tabsScrollView.frameLayoutGuide.heightAnchor, constant: -10),

            terminalContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            terminalContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            terminalContainer.topAnchor.constraint(equalTo: tabsScrollView.bottomAnchor),
            terminalContainer.bottomAnchor.constraint(equalTo: keyBar.topAnchor),

            keyBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyBar.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
            keyBar.heightAnchor.constraint(equalToConstant: 48)
        ])
        if usesCompactHeader {
            addButton.widthAnchor.constraint(equalToConstant: 48).isActive = true
            closeButton.widthAnchor.constraint(equalToConstant: 48).isActive = true
        }
    }

    private func createTab(select: Bool) {
        guard tabs.count < ROBAdministratorTerminalProtocol.maximumTabs else { return }
        loadViewIfNeeded()
        let tab = TerminalTab(number: nextTabNumber)
        nextTabNumber += 1
        configure(tab.terminalView)
        tabs.append(tab)
        if select {
            selectedTabID = tab.id
            showTerminal(for: tab)
        }
        if connectionAvailable {
            tab.state = .opening
            sendOpen(for: tab)
        }
        refreshInterface()
    }

    private func configure(_ terminalView: TerminalView) {
        terminalView.translatesAutoresizingMaskIntoConstraints = false
        terminalView.terminalDelegate = self
        terminalView.font = .monospacedSystemFont(ofSize: UIDevice.current.userInterfaceIdiom == .pad ? 14 : 12, weight: .regular)
        terminalView.nativeForegroundColor = UIColor(red: 0.84, green: 0.93, blue: 1, alpha: 1)
        terminalView.nativeBackgroundColor = .black
        terminalView.caretColor = .systemGreen
        terminalView.selectedTextBackgroundColor = UIColor.systemBlue.withAlphaComponent(0.36)
        terminalView.optionAsMetaKey = true
        terminalView.allowMouseReporting = true
        terminalView.changeScrollback(10_000)
        terminalView.accessibilityLabel = "Cerebro administrator shell"
    }

    private func showTerminal(for tab: TerminalTab) {
        for subview in terminalContainer.subviews { subview.removeFromSuperview() }
        terminalContainer.addSubview(tab.terminalView)
        NSLayoutConstraint.activate([
            tab.terminalView.leadingAnchor.constraint(equalTo: terminalContainer.leadingAnchor, constant: 6),
            tab.terminalView.trailingAnchor.constraint(equalTo: terminalContainer.trailingAnchor, constant: -6),
            tab.terminalView.topAnchor.constraint(equalTo: terminalContainer.topAnchor, constant: 4),
            tab.terminalView.bottomAnchor.constraint(equalTo: terminalContainer.bottomAnchor, constant: -4)
        ])
    }

    private func refreshInterface() {
        guard isViewLoaded else { return }
        for view in tabsStackView.arrangedSubviews {
            tabsStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        for (index, tab) in tabs.enumerated() {
            var configuration = UIButton.Configuration.tinted()
            configuration.title = "●  \(tab.displayName)"
            configuration.baseForegroundColor = tab.id == selectedTabID ? .white : tab.state.color
            configuration.baseBackgroundColor = tab.id == selectedTabID
                ? UIColor.systemBlue.withAlphaComponent(0.72)
                : UIColor.white.withAlphaComponent(0.05)
            configuration.cornerStyle = .small
            let button = UIButton(configuration: configuration)
            button.tag = index
            button.titleLabel?.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
            button.accessibilityIdentifier = "administratorTerminalTab\(index + 1)"
            button.addTarget(self, action: #selector(tabPressed(_:)), for: .touchUpInside)
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 118).isActive = true
            tabsStackView.addArrangedSubview(button)
        }

        let state = selectedTab?.state ?? .offline
        statusPill.text = "  \(state.shortLabel)  "
        statusPill.backgroundColor = state.color
        detailLabel.text = state.detail
        codexButton.isEnabled = connectionAvailable && state.acceptsInput
        closeButton.isEnabled = selectedTab != nil
        addButton.isEnabled = tabs.count < ROBAdministratorTerminalProtocol.maximumTabs
    }

    @objc private func addTabPressed() {
        createTab(select: true)
    }

    @objc private func tabPressed(_ sender: UIButton) {
        guard tabs.indices.contains(sender.tag) else { return }
        let tab = tabs[sender.tag]
        selectedTabID = tab.id
        showTerminal(for: tab)
        refreshInterface()
        _ = tab.terminalView.becomeFirstResponder()
    }

    @objc private func closeTabPressed() {
        guard let tab = selectedTab else { return }
        let alert = UIAlertController(
            title: "Close \(tab.displayName)?",
            message: "The shell and any command running in it will be stopped on Cerebro.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Close Terminal", style: .destructive) { [weak self] _ in
            self?.close(tab)
        })
        present(alert, animated: true)
    }

    private func close(_ tab: TerminalTab) {
        if connectionAvailable {
            send(kind: .close, payload: Data(), columns: 0, rows: 0, for: tab)
        } else {
            pendingCloseRequests.append((tab.id, tab.nextRequestSequence()))
        }
        let removedIndex = tabs.firstIndex { $0.id == tab.id } ?? 0
        tabs.removeAll { $0.id == tab.id }
        if tabs.isEmpty {
            selectedTabID = nil
            createTab(select: true)
            return
        }
        let replacement = tabs[min(removedIndex, tabs.count - 1)]
        selectedTabID = replacement.id
        showTerminal(for: replacement)
        refreshInterface()
    }

    @objc private func openCodexPressed() {
        sendInput(Data("codex\r".utf8))
        _ = selectedTab?.terminalView.becomeFirstResponder()
    }

    private func sendInput(_ data: Data) {
        guard let tab = selectedTab, connectionAvailable, tab.state.acceptsInput else { return }
        var offset = 0
        while offset < data.count {
            let upperBound = min(offset + ROBAdministratorTerminalProtocol.maximumPayloadBytes, data.count)
            send(
                kind: .input,
                payload: data.subdata(in: offset ..< upperBound),
                columns: 0,
                rows: 0,
                for: tab
            )
            offset = upperBound
        }
    }

    private func sendOpen(for tab: TerminalTab) {
        send(
            kind: .open,
            payload: ROBAdministratorTerminalProtocol.acknowledgementPayload(tab.lastInboundSequence),
            columns: tab.columns,
            rows: tab.rows,
            for: tab
        )
    }

    private func flushPendingCloseRequests() {
        guard let autoNetClient else { return }
        for request in pendingCloseRequests {
            let message = ROBAdministratorTerminalMessage(
                kind: .close,
                terminalID: request.terminalID,
                sequence: request.sequence,
                columns: 0,
                rows: 0,
                payload: Data()
            )
            if let encoded = try? ROBAdministratorTerminalProtocol.encode(message) {
                autoNetClient.send(data: encoded)
            }
        }
        pendingCloseRequests.removeAll()
    }

    private func send(
        kind: ROBAdministratorTerminalMessageKind,
        payload: Data,
        columns: UInt16,
        rows: UInt16,
        for tab: TerminalTab
    ) {
        guard connectionAvailable, let autoNetClient else { return }
        let message = ROBAdministratorTerminalMessage(
            kind: kind,
            terminalID: tab.id,
            sequence: tab.nextRequestSequence(),
            columns: columns,
            rows: rows,
            payload: payload
        )
        guard let encoded = try? ROBAdministratorTerminalProtocol.encode(message) else { return }
        autoNetClient.send(data: encoded)
    }

    private func consume(_ message: ROBAdministratorTerminalMessage) {
        guard let tab = tabs.first(where: { $0.id == message.terminalID }) else { return }
        if message.kind != .error {
            guard message.sequence > tab.lastInboundSequence else { return }
            tab.lastInboundSequence = message.sequence
        }

        switch message.kind {
        case .output:
            tab.terminalView.feed(byteArray: ArraySlice(message.payload))
        case .ready:
            let directory = String(data: message.payload, encoding: .utf8) ?? "Cerebro"
            tab.state = .ready(directory)
        case .title:
            updateTitle(String(data: message.payload, encoding: .utf8), for: tab)
        case .exited:
            tab.state = .exited(String(data: message.payload, encoding: .utf8) ?? "The shell exited.")
        case .error:
            tab.state = .denied(String(data: message.payload, encoding: .utf8) ?? "Terminal access was denied.")
        case .open, .input, .resize, .close:
            return
        }
        refreshInterface()
    }

    private func updateTitle(_ title: String?, for tab: TerminalTab) {
        guard let title else { return }
        let sanitized = title
            .components(separatedBy: .controlCharacters)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else { return }
        tab.displayName = String(sanitized.suffix(48))
    }

    private func isOpening(_ state: SessionState) -> Bool {
        if case .opening = state { return true }
        return false
    }
}

extension ROBAdministratorTerminalViewController: TerminalViewDelegate {
    public func send(source: TerminalView, data: ArraySlice<UInt8>) {
        guard let tab = tabs.first(where: { $0.terminalView === source }),
              tab.id == selectedTabID else { return }
        sendInput(Data(data))
    }

    public func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        guard let tab = tabs.first(where: { $0.terminalView === source }) else { return }
        tab.columns = UInt16(clamping: newCols).clamped(
            to: ROBAdministratorTerminalProtocol.minimumColumns ... ROBAdministratorTerminalProtocol.maximumColumns
        )
        tab.rows = UInt16(clamping: newRows).clamped(
            to: ROBAdministratorTerminalProtocol.minimumRows ... ROBAdministratorTerminalProtocol.maximumRows
        )
        guard connectionAvailable, tab.state.acceptsInput else { return }
        send(kind: .resize, payload: Data(), columns: tab.columns, rows: tab.rows, for: tab)
    }

    public func setTerminalTitle(source: TerminalView, title: String) {
        guard let tab = tabs.first(where: { $0.terminalView === source }) else { return }
        updateTitle(title, for: tab)
        refreshInterface()
    }

    public func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        guard let tab = tabs.first(where: { $0.terminalView === source }),
              let directory, tab.state.acceptsInput else { return }
        tab.state = .ready(directory)
        refreshInterface()
    }

    public func scrolled(source: TerminalView, position: Double) {}

    public func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
        guard let url = URL(string: link), ["https", "http"].contains(url.scheme?.lowercased() ?? "") else {
            return
        }
        UIApplication.shared.open(url)
    }

    public func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
