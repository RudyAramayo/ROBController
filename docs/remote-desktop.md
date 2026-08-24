# Cerebro remote desktop

ROBController's **Admin → Desktop** workspace is a VNC-style remote desktop for the Mac running
Cerebro. It uses ROB's existing authenticated transports rather than exposing a
general-purpose VNC port or storing another password.

## One-time setup on the Mac

1. Pair ROBController as an operator and complete the Administrator face enrollment
   bound to that controller.
2. Open **Admin → Desktop** in ROBController while you still have access to the Mac. Cerebro
   requests the two macOS privacy permissions it needs.
3. In **System Settings → Privacy & Security**, enable Cerebro under **Screen & System
   Audio Recording** and **Accessibility**. Restart Cerebro after changing Screen
   Recording permission.
4. Reopen **Admin → Desktop** and confirm its status is `LIVE` before relying on it at a show.

Screen Recording provides the image. Accessibility permits synthesized mouse and
keyboard events. Without Accessibility, the desktop can remain view-only. Neither
permission can be silently granted over the network.

## Controls

- In **Control** mode, tap for a primary click, drag with one finger to mouse-drag,
  long-press for a secondary click, and drag with two fingers to scroll.
- Select **Pan / Zoom** to move around a magnified desktop without clicking it. Pinch
  zoom is available for small text.
- Tap a field on the Mac, enter text in the controller's text bar, then press **Type**.
  The key strip supplies Escape, Tab, Return, Delete, Command-A, and arrow keys.
- Leaving **Admin → Desktop** closes its media stream and releases any held mouse button.

Desktop images use a demand-driven JPEG stream on `_robvideo._udp`. Mouse and keyboard
events use small `ROBDESK1` messages on the separately authenticated `_robctl._udp`
session. Media congestion therefore cannot queue ahead of steering or stop controls.

This is intentionally not an open RFB/VNC server: third-party VNC clients cannot attach,
and no TCP VNC listener or reusable VNC password is created.

## Verification

```sh
swiftc Consciousness/AutoNetClient/AutoNetDataTransferProtocol.swift \
  Tests/ROBRemoteDesktopControlProtocolFixtureTests.swift \
  -o /tmp/ROBRemoteDesktopControlProtocolFixtureTests
/tmp/ROBRemoteDesktopControlProtocolFixtureTests
python3 Tests/ROBRemoteDesktopUIStaticTests.py
```
