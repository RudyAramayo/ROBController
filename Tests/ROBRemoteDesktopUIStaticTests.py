#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
controller = (ROOT / "Consciousness/ConsciousViewController.mm").read_text()
view = (ROOT / "Consciousness/ROBRemoteDesktopViewController.swift").read_text()
client = (ROOT / "Consciousness/ROBRemoteDesktopVideoClient.swift").read_text()
workspace = (ROOT / "Consciousness/ROBAdministratorWorkspaceViewController.swift").read_text()
control_client = (ROOT / "Consciousness/AutoNetClient/AutoNetClient.swift").read_text()
plist = (ROOT / "Consciousness/Info.plist").read_text()

assert controller.count("administratorWorkspace,") == 2, "Admin workspace must be on iPhone and iPad"
assert controller.index("administratorWorkspaceViewController handleIncomingData:data") < controller.index(
    "decodeEnvelopeData:data"
)
assert 'UISegmentedControl(items: ["Terminal", "Desktop"])' in workspace
assert "authenticatedSessionID" in control_client and "authenticationHello" in client
assert "SecTrustCopyCertificateChain" in client and "certificateSHA256" in client
assert 'cameraID: "desktop"' in client and 'preferredCodecs: ["jpeg"]' in client
assert "UIPanGestureRecognizer" in view and "UILongPressGestureRecognizer" in view
assert "primaryDown" in view and "primaryUp" in view and "secondaryClick" in view
assert "remoteDesktopTextInput" in view and "sendTextPressed" in view
assert "inputControlAvailable = pieces.first == \"READY\"" in view
assert 'string>_robvideo._udp</string>' in plist

print("ROB remote desktop UI static tests passed")
