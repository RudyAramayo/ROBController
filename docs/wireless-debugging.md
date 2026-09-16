# Wireless development on iPhone

Select the shared **ROBController Wireless** scheme, select the iPhone, then Run.
It builds the same Debug configuration as the regular scheme, but launches with
**Debug executable** unchecked. Breakpoints and LLDB inspection require switching
back to **Consciousness** or **ROBController**, or attaching the debugger after
startup. Those normal schemes keep LLDB enabled and disable queue debugging and
queue backtrace recording.

For the reported two minutes of startup stuttering followed by smooth operation,
compare both schemes on the same phone. If Wireless becomes responsive promptly,
the debugger is contributing to the delay. If both remain slow, profile the app's
startup using Instruments; this scheme alone does not establish the root cause.

Apple engineers recommend this comparison in
[App Startup with Debugger in Xcode 26 is slow](https://developer.apple.com/forums/thread/800067).
They identify library debug-information loading and debugger/device communication
as possible sources of launch delays. For an attached run that remains slow, let
startup finish, pause while robot control is idle, and collect `image list` in
LLDB as described in that thread. Compare a USB run with a wireless run too.

The separate pairing handshake still has its five-second deadline. Its status
now distinguishes waiting for a challenge, waiting for confirmation, an explicit
Cerebro rejection, and a response that fails verification. A timeout does not
mean the pairing key was rejected. Automatic retries retain the last failure
onscreen until a successful connection or an explicit Reconnect. Request Control
becomes available only after the link is authenticated.

Current Cerebro builds expire a probe-capable session after ten seconds without
a valid heartbeat reply, including during a reconnect. If another responsive
session is using the same pairing, ROBController reports that separately. Close
the other app, or issue a separate pairing code for each device or simulator.
Reconnect retains the outgoing connection until its queued shutdown cancels the
transport and clears the authenticated session, even after the client facade has
released it.

## Validation

The loopback fixture exercises the production client handshake and v2 framer
with synthetic credentials over local TCP. It checks both timeouts, explicit
rejection at either stage, a pairing already in use, invalid server proof, and
successful mutual proof. The success case also releases the connection while
shutdown is queued and verifies that the old transport is still cancelled.
It does not replace the QUIC/TLS certificate-pinning checks in a device run.

```sh
swiftc Consciousness/AutoNetClient/AutoNetDataTransferProtocol.swift \
  Consciousness/AutoNetClient/AutoNetClientConnection.swift \
  Tests/ROBControlHandshakeIntegrationTests.swift \
  -o /tmp/ROBControlHandshakeIntegrationTests
/tmp/ROBControlHandshakeIntegrationTests
```
