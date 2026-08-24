# Administrator terminal

ROBController now includes a **Terminal** tab on iPhone and iPad. Each tab is a real
`xterm-256color` terminal connected to an independent `zsh` pseudo-terminal on the Mac
running Cerebro. The phone or iPad never attempts to execute commands locally.

## Before a show

1. Pair ROBController with Cerebro as an operator controller.
2. In Cerebro's **People & Face Enrollment** window, complete the Administrator
   enrollment using that paired controller. The enrollment must have all required face
   samples and its trusted reference must be the controller's device ID.
3. On the Mac, run `codex` once in a normal Terminal and complete its first-time sign-in.
   The remote shell deliberately inherits the normal Cerebro login-shell environment;
   ROBController does not store or transmit an OpenAI API key.
4. Keep Cerebro running and confirm ROBController's main connection indicator is online.

## Using it

- Open **Terminal** in the main tab bar. `READY` means Cerebro created or reattached the
  shell. `DENIED` explains a missing or mismatched administrator binding.
- Tap **New** to open another independent shell, up to eight tabs. Switching tabs keeps
  each terminal's screen and running process intact.
- Tap **Open Codex** to enter `codex` in the selected login shell. It behaves like the
  Codex CLI launched from the Mac's `~/dev` directory.
- The key strip provides Esc, Tab, Ctrl-C, and arrow keys for touch keyboards. Hardware
  keyboards continue to work through the terminal emulator.
- Closing a tab sends a remote close request and warns that any running command will stop.
  A close made during a brief disconnect is sent as soon as the authenticated connection
  returns.

## Security and reconnect behavior

Terminal traffic uses the existing certificate-pinned, reciprocally authenticated
ROBControl QUIC connection. Cerebro authorizes the server-owned paired controller ID,
then requires an encrypted, completed Administrator face profile bound to that exact ID.
Face recognition alone is not a terminal credential, and known-person or telemetry-only
devices cannot open a shell.

Terminal frames are versioned, bounded, sequenced, and routed before legacy robot command
parsing. Output is returned only to the exact authenticated network session. Cerebro keeps
a bounded output backlog so tabs can reattach after a network interruption without
turning a disconnect into a second shell.

## Verification

```sh
swiftc Consciousness/AutoNetClient/AutoNetDataTransferProtocol.swift \
  Tests/ROBAdministratorTerminalProtocolFixtureTests.swift \
  -o /tmp/ROBAdministratorTerminalProtocolFixtureTests
/tmp/ROBAdministratorTerminalProtocolFixtureTests
python3 Tests/ROBAdministratorTerminalUIStaticTests.py
```
