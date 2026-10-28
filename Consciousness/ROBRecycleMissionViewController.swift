import UIKit

@objcMembers final class ROBRecycleMissionClient: NSObject {
    static let shared = ROBRecycleMissionClient()
    var sendData: ((Data) -> Void)?
    var connected: (() -> Bool)?
    @nonobjc private(set) var status: ROBRecycleMissionMessage?
    @nonobjc private var pending: ROBRecycleMissionMessage?
    private var sequence: UInt64 = 0
    private var timer: Timer?
    static let statusChanged = Notification.Name("ROBRecycleMissionStatusChanged")
    private let configurationKey = "ROBController.RecycleCans.Configuration.v1"
    @nonobjc var configuration: ROBRecycleMissionMessage.Configuration {
        get {
            if let data=UserDefaults.standard.data(forKey:configurationKey),
               let value=try? JSONDecoder().decode(ROBRecycleMissionMessage.Configuration.self,from:data),value.valid { return value }
            return .init()
        }
        set { if newValue.valid,let data=try? JSONEncoder().encode(newValue) { UserDefaults.standard.set(data,forKey:configurationKey) } }
    }
    var isActive: Bool { status?.active == true || pending?.kind == .start || pending?.kind == .stop }
    var detail: String {
        if connected?() != true { return "Cerebro disconnected. Reconnect to read the mission state; Stop will remain queued." }
        if pending?.kind == .stop { return "Stop sent — waiting for Cerebro to confirm the hold" }
        if pending?.kind == .start { return "Starting Recycle Cans — waiting for Cerebro" }
        return status?.detail ?? "Ready to search for cans and recycle them into the orange bucket."
    }
    @nonobjc func start() {
        guard connected?()==true,!isActive,status?.possiblePayloadHeld != true else { return }
        sequence=1
        pending=ROBRecycleMissionMessage(kind:.start,missionID:UUID(),sequence:sequence,
            sentAtMilliseconds:ROBRecycleMissionMessage.now,configuration:configuration)
        status=nil;sendPending();beginPolling();notify()
    }
    func stop() {
        guard let current=pending ?? status else { return }
        sequence=max(sequence,current.sequence)+1
        pending=ROBRecycleMissionMessage(kind:.stop,missionID:current.missionID,sequence:sequence,
            sentAtMilliseconds:ROBRecycleMissionMessage.now,configuration:current.configuration)
        sendPending();beginPolling();notify()
    }
    func confirmEmpty() {
        guard !isActive,let current=status,current.possiblePayloadHeld,connected?()==true else { return }
        sequence=max(sequence,current.sequence)+1
        pending=ROBRecycleMissionMessage(kind:.confirmEmpty,missionID:current.missionID,sequence:sequence,
            sentAtMilliseconds:ROBRecycleMissionMessage.now,configuration:current.configuration)
        sendPending();notify()
    }
    func connectionChanged() { sendPending();query();beginPolling();notify() }
    func consume(_ data: Data) -> Bool {
        if !Thread.isMainThread { return DispatchQueue.main.sync { consume(data) } }
        guard ROBRecycleMissionMessage.claims(data) else { return false }
        guard let next=ROBRecycleMissionMessage.decode(data),next.kind == .status,
              abs(ROBRecycleMissionMessage.now-next.sentAtMilliseconds)<10_000 else { return true }
        if let current=pending ?? status,current.missionID != next.missionID {
            // An authenticated robot may already own a mission (e.g. the
            // controller relaunched). Restore its Stop control, never restart it.
            if pending?.kind == .stop { return true }
            if pending?.kind == .start { pending=nil }
            else if current.active { return true }
        }
        if let old=status,old.missionID==next.missionID,old.sentAtMilliseconds>next.sentAtMilliseconds { return true }
        status=next;sequence=max(sequence,next.sequence)
        if let request=pending,request.missionID==next.missionID,next.sequence>=request.sequence {
            pending=nil
        }
        notify();return true
    }
    private func beginPolling() {
        guard timer==nil else { return }
        timer=Timer.scheduledTimer(withTimeInterval:1,repeats:true) { [weak self] _ in
            self?.sendPending();self?.query();self?.notify()
        }
    }
    private func sendPending() {
        guard connected?()==true,var request=pending else { return }
        // Start is immutable and short-lived. Stop remains retryable after a
        // reconnect, with the SAME sequence and mission identity.
        if request.kind == .stop { request.sentAtMilliseconds=ROBRecycleMissionMessage.now;pending=request }
        if request.kind != .stop,ROBRecycleMissionMessage.now-request.sentAtMilliseconds>10_000 {
            // Preserve the unresolved request so another Start cannot race it.
            query();return
        }
        if let data=request.encoded() { sendData?(data) }
    }
    private func query() {
        guard connected?()==true else { return }
        let request=ROBRecycleMissionMessage(kind:.query,missionID:pending?.missionID ?? status?.missionID ?? UUID(),
            sequence:max(1,sequence),sentAtMilliseconds:ROBRecycleMissionMessage.now,configuration:configuration)
        if let data=request.encoded() { sendData?(data) }
    }
    private func notify() { NotificationCenter.default.post(name:Self.statusChanged,object:self) }
    func present(from parent: UIViewController) {
        parent.present(UINavigationController(rootViewController:ROBRecycleMissionViewController()),animated:true)
        query();beginPolling()
    }
}

/// Built-in mission, alongside existing user-created waypoint paths.
private final class ROBRecycleMissionViewController: UIViewController {
    private let client=ROBRecycleMissionClient.shared
    private let destination=UIButton(type:.system)
    private let count=UIStepper(),radius=UIStepper()
    private let countLabel=UILabel(),radiusLabel=UILabel(),statusLabel=UILabel(),progressLabel=UILabel()
    private let start=UIButton(type:.system),stop=UIButton(type:.system),empty=UIButton(type:.system)
    override func viewDidLoad() {
        super.viewDidLoad();title="Recycle Cans";view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem=UIBarButtonItem(barButtonSystemItem:.done,target:self,action:#selector(close))
        let intro=UILabel();intro.numberOfLines=0
        intro.text="Search the mapped room for nearby cans, approach a reachable can, and use the right gripper to place it in the selected destination. Recheck targets after movement."
        destination.setTitle("Destination: Orange bucket",for:.normal)
        destination.showsMenuAsPrimaryAction=true
        destination.menu=UIMenu(title:"Recycling destination",children:[UIAction(title:"Orange bucket",state:.on) { [weak self] _ in
            guard let self else { return };var config=self.client.configuration;config.destination="orange_bucket";self.client.configuration=config
        }])
        count.minimumValue=1;count.maximumValue=8;count.value=Double(client.configuration.maximumCans)
        radius.minimumValue=1;radius.maximumValue=10;radius.value=client.configuration.radiusMeters
        count.addTarget(self,action:#selector(changeConfiguration),for:.valueChanged)
        radius.addTarget(self,action:#selector(changeConfiguration),for:.valueChanged)
        start.setTitle("Start Recycle Cans",for:.normal);start.addTarget(self,action:#selector(startMission),for:.touchUpInside)
        stop.setTitle("Stop and hold",for:.normal);stop.tintColor = .systemRed;stop.addTarget(self,action:#selector(stopMission),for:.touchUpInside)
        empty.setTitle("I inspected the gripper: it is empty",for:.normal)
        empty.addTarget(self,action:#selector(confirmEmpty),for:.touchUpInside)
        let scope=UILabel();scope.numberOfLines=0;scope.font = .preferredFont(forTextStyle:.footnote)
        scope.text="Start authorizes this mission for 30 minutes: camera search, gentle tread travel up to 40% demand and checked right-arm transfers. Stop holds the arm. A can counts only when placement and empty jaws are verified."
        statusLabel.numberOfLines=0;statusLabel.accessibilityIdentifier="RecycleCans.status"
        progressLabel.numberOfLines=0;progressLabel.font = .preferredFont(forTextStyle:.headline)
        let stack=UIStackView(arrangedSubviews:[intro,destination,row(countLabel,count),row(radiusLabel,radius),scope,progressLabel,statusLabel,start,stop,empty])
        stack.axis = .vertical;stack.spacing=18;stack.translatesAutoresizingMaskIntoConstraints=false
        let scroll=UIScrollView();scroll.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(scroll);scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.leadingAnchor),scroll.trailingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.trailingAnchor),
            scroll.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor),scroll.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo:scroll.contentLayoutGuide.leadingAnchor,constant:20),stack.trailingAnchor.constraint(equalTo:scroll.contentLayoutGuide.trailingAnchor,constant:-20),
            stack.topAnchor.constraint(equalTo:scroll.contentLayoutGuide.topAnchor,constant:20),stack.bottomAnchor.constraint(equalTo:scroll.contentLayoutGuide.bottomAnchor,constant:-20),
            stack.widthAnchor.constraint(equalTo:scroll.frameLayoutGuide.widthAnchor,constant:-40)])
        NotificationCenter.default.addObserver(self,selector:#selector(refresh),name:ROBRecycleMissionClient.statusChanged,object:client)
        refresh()
    }
    private func row(_ label:UILabel,_ stepper:UIStepper)->UIView {
        let stack=UIStackView(arrangedSubviews:[label,stepper]);stack.axis = .horizontal;stack.distribution = .equalSpacing;return stack
    }
    @objc private func changeConfiguration() {
        var config=client.configuration;config.maximumCans=Int(count.value);config.radiusMeters=radius.value
        client.configuration=config;refresh()
    }
    @objc private func refresh() {
        let config=client.status?.active == true ? client.status!.configuration:client.configuration
        countLabel.text="Up to \(config.maximumCans) cans";radiusLabel.text=String(format:"Search radius: %.0f m",config.radiusMeters)
        statusLabel.text=client.detail
        progressLabel.text="\(client.status?.verifiedTransfers ?? 0) recycled · \(client.status?.searchedStops ?? 0) stops searched"
        start.isEnabled=client.connected?()==true && !client.isActive && client.status?.possiblePayloadHeld != true
        empty.isHidden=client.status?.possiblePayloadHeld != true
        empty.isEnabled = !client.isActive && client.connected?()==true
        stop.isEnabled=client.isActive;count.isEnabled = !client.isActive;radius.isEnabled = !client.isActive;destination.isEnabled = !client.isActive
        start.setTitle(client.status?.phase == .paused ? "Resume with a fresh plan":"Start Recycle Cans",for:.normal)
    }
    @objc private func confirmEmpty() { client.confirmEmpty() }
    @objc private func startMission() { client.start() }
    @objc private func stopMission() { client.stop() }
    @objc private func close() { dismiss(animated:true) }
    deinit { NotificationCenter.default.removeObserver(self) }
}
