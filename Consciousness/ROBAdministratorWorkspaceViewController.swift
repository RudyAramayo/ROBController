import UIKit

/// One main-tab destination for both privileged administrator surfaces. This
/// keeps Terminal and Desktop directly reachable on iPhone without allowing a
/// sixth tab to be hidden behind UIKit's More controller.
@objcMembers public final class ROBAdministratorWorkspaceViewController: UIViewController {
    private let terminal = ROBAdministratorTerminalViewController()
    private let desktop = ROBRemoteDesktopViewController()
    private let selector = UISegmentedControl(items: ["Terminal", "Desktop"])
    private let contentView = UIView()
    private var selectedController: UIViewController?

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.022, green: 0.03, blue: 0.045, alpha: 1)

        let switcher = UIView()
        switcher.translatesAutoresizingMaskIntoConstraints = false
        switcher.backgroundColor = UIColor(red: 0.035, green: 0.047, blue: 0.065, alpha: 1)
        view.addSubview(switcher)

        selector.translatesAutoresizingMaskIntoConstraints = false
        selector.selectedSegmentIndex = 0
        selector.setTitleTextAttributes(
            [.font: UIFont.monospacedSystemFont(ofSize: 12, weight: .bold)],
            for: .normal
        )
        selector.accessibilityIdentifier = "administratorWorkspaceMode"
        selector.addTarget(self, action: #selector(selectionChanged), for: .valueChanged)
        switcher.addSubview(selector)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentView)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            switcher.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            switcher.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            switcher.topAnchor.constraint(equalTo: safe.topAnchor),
            switcher.heightAnchor.constraint(equalToConstant: 42),
            selector.centerXAnchor.constraint(equalTo: switcher.centerXAnchor),
            selector.centerYAnchor.constraint(equalTo: switcher.centerYAnchor),
            selector.widthAnchor.constraint(equalTo: switcher.widthAnchor, multiplier: 0.58),
            selector.heightAnchor.constraint(equalToConstant: 30),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: switcher.bottomAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        show(terminal, animated: false)
    }

    public func bindAutoNetClient(_ client: AutoNetClient) {
        terminal.bindAutoNetClient(client)
        desktop.bindAutoNetClient(client)
    }

    public func setConnectionAvailable(_ available: Bool) {
        terminal.setConnectionAvailable(available)
        desktop.setConnectionAvailable(available)
    }

    public func handleIncomingData(_ data: Data) -> Bool {
        terminal.handleIncomingData(data) || desktop.handleIncomingData(data)
    }

    @objc private func selectionChanged() {
        show(selector.selectedSegmentIndex == 0 ? terminal : desktop, animated: true)
    }

    private func show(_ controller: UIViewController, animated: Bool) {
        guard selectedController !== controller else { return }
        let previous = selectedController
        previous?.beginAppearanceTransition(false, animated: animated)
        controller.beginAppearanceTransition(true, animated: animated)
        previous?.willMove(toParent: nil)

        addChild(controller)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: contentView.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        controller.didMove(toParent: self)

        let finish = {
            previous?.view.removeFromSuperview()
            previous?.removeFromParent()
            previous?.endAppearanceTransition()
            controller.endAppearanceTransition()
        }
        selectedController = controller
        if animated {
            controller.view.alpha = 0
            UIView.animate(withDuration: 0.16, animations: {
                controller.view.alpha = 1
                previous?.view.alpha = 0
            }) { _ in
                previous?.view.alpha = 1
                finish()
            }
        } else {
            finish()
        }
    }
}
