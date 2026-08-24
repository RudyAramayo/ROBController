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
assert 'case maximumDetail' in client and 'case fast' in client
assert 'return (4_096, 2_160, 2, 40_000_000)' in client
assert 'return (960, 540, 8, 1_500_000)' in client
assert 'desktopMaximumJPEGBytes = 8 * 1_024 * 1_024' in client
assert 'remoteDesktopVideoQuality' in view and 'qualityChanged' in view
assert 'videoClient.start(controlSessionID: sessionID, quality:' in view
assert 'scrollView.maximumZoomScale = 12' in view
assert 'remoteDesktopFullScreen' in view and 'remoteDesktopHideOverlay' in view
assert 'remoteDesktopShowOverlay' in view and 'setOverlayControlsVisible' in view
assert 'fullScreenScrollConstraints' in view and 'normalScrollConstraints' in view
assert 'scrollView.contentInsetAdjustmentBehavior = .never' in view
assert 'fullScreenLayoutHandler' in workspace and 'tabBar.isHidden = enabled' in workspace
assert 'prefersStatusBarHidden' in workspace and 'prefersHomeIndicatorAutoHidden' in workspace
assert "UIPanGestureRecognizer" in view and "UILongPressGestureRecognizer" in view
assert "primaryDown" in view and "primaryUp" in view and "secondaryClick" in view
assert "remoteDesktopTextInput" in view and "sendTextPressed" in view
assert "inputControlAvailable = pieces.first == \"READY\"" in view
assert 'string>_robvideo._udp</string>' in plist

print("ROB remote desktop UI static tests passed")
