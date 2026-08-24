#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
controller = (ROOT / "Consciousness/ConsciousViewController.mm").read_text()
ui = (ROOT / "Consciousness/ROBAdministratorTerminalViewController.swift").read_text()
workspace = (ROOT / "Consciousness/ROBAdministratorWorkspaceViewController.swift").read_text()
project = (ROOT / "ROBController.xcodeproj/project.pbxproj").read_text()

assert controller.count("administratorWorkspace,") == 2, "Admin workspace must be in iPhone and iPad tab sets"
assert "ROBAdministratorTerminalViewController()" in workspace
assert controller.index("handleIncomingData:data") < controller.index("decodeEnvelopeData:data")
assert "import SwiftTerm" in ui and "TerminalView(frame: .zero)" in ui
assert "maximumTabs" in ui and "createTab(select: true)" in ui
assert 'Data("codex\\r".utf8)' in ui
assert "pendingCloseRequests" in ui and "flushPendingCloseRequests" in ui
assert "keyboardWillChangeFrameNotification" in ui and "keyboardWillHideNotification" in ui
assert "keyboardFrameEndUserInfoKey" in ui and "keyBarBottomConstraint" in ui
assert "keyboardAnimationDurationUserInfoKey" in ui and "keyboardAnimationCurveUserInfoKey" in ui
assert "terminalView.keyboardDismissMode = .interactive" in ui
assert "UserDefaults" not in ui and "sharedSecret" not in ui and "API_KEY" not in ui
assert "SwiftTerm.git" in project and "version = 1.18.0" in project

print("ROB administrator terminal UI static tests passed")
