# ROBController v2 pairing and autonomy

## Pair and connect

1. Start Cerebro and click **Pair ROBController…** beneath its camera view.
2. On ROBController, tap **Pair Cerebro…** and paste the complete `ROBCTL2:`
   code. It is stored in the iOS Keychain and must be handled as a credential.
3. ROBController browses only `_robctl._udp`. It filters Bonjour TXT metadata
   for the robot ID in that credential, pins Cerebro's exact P-256 certificate,
   and completes a fresh reciprocal HMAC challenge before showing Connected.

The old `_roboNet._tcp` advertisement/plaintext-UDP combination is not a v2
fallback. It exists only in the explicitly enabled legacy adapter. The app
never downgrades automatically.

The Watch app is a deliberately limited companion. It uses WatchConnectivity
to send versioned, freshness-checked Dictate and Drive commands to the paired
iPhone; it never receives the Cerebro TLS credential. ROBController validates
those commands and forwards them over its existing `_robctl._udp` connection.
The iPhone app must be open, paired with Cerebro, and reachable before the
Watch enables Drive.

Watch Drive uses one centered touch joystick. A fresh touch requests manual
controller ownership and starts 5 Hz typed differential-tread snapshots. Releasing
the touch, leaving the view, lowering the wrist, losing reachability, or a
450 ms relay timeout sends a braked neutral snapshot and releases ownership.
Motion commands use immediate WatchConnectivity messages and are never queued
or replayed after reconnection.

Watch voice input uses the watchOS system text-entry sheet, including Dictation.
The transcript is forwarded as a separate bounded voice message, so speaking
does not claim tread authority and the response still follows Cerebro's normal
Gemini/SpeechBox path.

## Start and stop social roam

The iPad and iPhone storyboards expose the same controls:

- **Start Social Roam** sends one bounded, eight-hour authorization with a
  five-meter activation-centered zone and a 0.20 maximum speed scale.
- **Stop Autonomy** sends a higher-sequence stop immediately. If the link is
  down, the controller keeps the immutable stop queued and retransmits it after
  authentication returns.
- Cerebro status restores the active session after this app restarts, so the
  Stop control can still address the correct session.

Putting the controller app in the background does not itself end an already
authorized server-side session. Cerebro restarts inactive, a manual Request
Control ends autonomy, and the physical arm E-stops, front shutdown, and
Arduino tread deadman remain authoritative.

Social roam currently drives only low-speed treads from fresh local RPLidar
data and uses the existing Gemini camera/audio/SpeechBox conversation path.
Arm grasping, rotating-base motion, and general neck gestures remain unavailable
until calibrated transforms, complete joint mappings, feedback, IK, collision
checking, and a cancellable executor are implemented and hardware-tested.
