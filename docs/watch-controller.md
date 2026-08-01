# ROBController Watch companion

The Watch target intentionally exposes only two functions:

- **Dictate** opens the watchOS system text-input sheet. Choose Dictation, speak
  a short message, and submit it. The paired iPhone forwards the transcript to
  Cerebro without requesting motion authority.
- **Drive** presents one centered joystick. Hold one finger on the pad to take
  manual tread control; move vertically for forward/reverse and horizontally
  for differential turning. Lifting the finger stops and releases control.

## Connection boundary

The Watch does not store the robot pairing credential and does not browse the
local network. It sends a versioned `ROBWatchCommand` to its companion iPhone
with `WCSession.sendMessage`. ROBController rejects malformed, stale, or
out-of-order motion snapshots and forwards a typed, range-checked Watch-drive
envelope over its existing authenticated `_robctl._udp` QUIC connection.

Drive requires all of the following:

1. The Watch is paired with the iPhone and the companion app is installed.
2. ROBController is open and reachable from the Watch.
3. ROBController has an authenticated Cerebro connection.
4. A finger is currently held on the joystick.

Drive snapshots run at 5 Hz. The iPhone relay expires them after 450 ms, while
Cerebro retains its independent 600 ms controller freshness rule and Arduino
USB heartbeat deadman. Commands are never stored with `transferUserInfo` or
replayed after a reconnect.

## Deployment

The existing iPhone target embeds and depends on
`ROBController-Watch Watch App`. Bundle identifiers are:

- iPhone: `com.orbitusrobotics.robcontroller`
- Watch: `com.orbitusrobotics.robcontroller.watchkitapp`

Select the shared **Consciousness-Watch Watch App** scheme to run directly on a
paired Developer Mode Watch. Archive the iPhone companion scheme to package
both apps.

Deployment prerequisites are the matching watchOS platform component in
Xcode, automatic signing/provisioning for both bundle identifiers under the
same development team, and a paired iPhone/Watch with Developer Mode enabled.

Before a hardware drive test, lift the treads and verify forward/reverse and
turn signs. Then verify touch release, wrist lowering, iPhone reachability loss,
Wi-Fi loss, the Arduino deadman, and the physical shutdown switches.
