"""Exercise the production delivery methods without opening a network connection."""
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
source = (repo / "Consciousness/AutoNetClient/AutoNetClient.swift").read_text()


def method(signature):
    start = source.index(signature)
    opening = source.index("{", start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end]


fixture = '''
import Foundation
protocol Delegate: AnyObject { func didReceiveData(_ data: NSData) }
final class Client {
    weak var dataDelegate: Delegate?
''' + method("func didReceiveData(_ data: Data)") + "\n" + method("private func performOnMain(") + '''
}
final class Receiver: Delegate {
    var received: [UInt8] = []
    func didReceiveData(_ data: NSData) {
        precondition(Thread.isMainThread, "UI status must be delivered on the main thread")
        received.append((data as Data)[0])
    }
}
let client = Client(), receiver = Receiver()
client.dataDelegate = receiver
client.didReceiveData(Data([0]))
precondition(receiver.received == [0], "A main-thread callback should remain synchronous")
DispatchQueue(label: "fixture.transport").async {
    for value: UInt8 in 1...3 { client.didReceiveData(Data([value])) }
}
let deadline = Date().addingTimeInterval(2)
while receiver.received.count < 4 && Date() < deadline {
    RunLoop.main.run(until: Date().addingTimeInterval(0.01))
}
precondition(receiver.received == [0, 1, 2, 3], "Background status callbacks must preserve delivery order")
print("Bubble connection fixtures passed: main-thread UI delivery and packet order")
'''

with tempfile.TemporaryDirectory(prefix="rob-bubble-connection-") as directory:
    path = Path(directory)
    (path / "main.swift").write_text(fixture)
    subprocess.run(["xcrun", "swiftc", "-module-cache-path", "/private/tmp/rob-bubble-client-swift-cache",
                    str(path / "main.swift"), "-o", str(path / "fixture")], check=True)
    subprocess.run([str(path / "fixture")], check=True)
