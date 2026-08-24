from pathlib import Path

root = Path(__file__).resolve().parents[1] / "Consciousness"
workspace = (root / "ROBAdministratorWorkspaceViewController.swift").read_text()
follow = (root / "ROBFollowTargetViewController.swift").read_text()
client = (root / "AutoNetClient" / "AutoNetClient.swift").read_text()

assert '["Terminal", "Desktop", "Follow"]' in workspace
assert "follow.handleIncomingData" in workspace
assert "authenticatedControllerID" in client
assert "Tap one outlined person" in follow
assert "Authorize Selected Person" in follow
assert "STOP FOLLOW MODE" in follow
assert "message.controllerID == client.authenticatedControllerID" in follow
assert "message.sessionID == client.authenticatedSessionID" in follow
assert "Insta360 delay is used only to re-aim" in follow

print("ROB follow-target UI static tests passed")
