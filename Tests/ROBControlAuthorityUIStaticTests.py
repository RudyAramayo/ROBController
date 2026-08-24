#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
controller = (ROOT / "Consciousness" / "ConsciousViewController.mm").read_text()

assert 'ROBControlAuthorityStateV1' in controller
assert 'control.authority.controller_id' in controller
assert 'ROBControlAuthorityStateRequesting' in controller
assert 'ROBControlAuthorityStateGranted' in controller
assert 'LINK VERIFIED • CONTROL UNCONFIRMED' in controller
assert 'LINK VERIFIED • CONTROL REQUESTING…' in controller
assert 'CONTROL GRANTED BY ROBOT' in controller
assert 'CONTROL NOT GRANTED' in controller
assert 'Green is reserved for a robot-confirmed authority update.' in controller
assert 'controlAuthorityRequestTimer' in controller
assert 'scheduledTimerWithTimeInterval:4.0' in controller
assert 'requestRobotControlButton' in controller
assert 'robotControlAuthorityIndicator' in controller

print("ROBController control-authority UI static tests passed")
