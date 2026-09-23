# Robot action approval console

ROBController is an operator approval and status console for bounded robot-action proposals from Cerebro. It does not translate an AI proposal into motor, arm, or servo commands and does not actuate hardware.

## Active interfaces

Both device-specific storyboards expose the same console:

- iPad: `Consciousness/Base.lproj/Main.storyboard`
- iPhone: `Consciousness/Base.lproj/Main_iPhone.storyboard`

The `ConsciousViewController` outlets are:

- `robotActionPanel`
- `robotActionSafetyLabel`
- `robotActionTitleLabel`
- `robotActionDetailLabel`
- `robotActionsEnabledButton`
- `robotActionApproveButton`
- `robotActionRejectButton`
- `robotActionCompleteButton`
- `robotActionFailedButton`
- `robotActionCancelButton`

The connected actions are:

- `toggleRobotActionsEnabled:`
- `approveRobotAction:`
- `rejectRobotAction:`
- `completeRobotAction:`
- `failRobotAction:`
- `cancelRobotAction:`

## Operator state model

**Action Approvals** is a persisted preference for receiving proposals, enabled
by default. Explicit Off persists across launches. The console advertises that
it accepts requests only while foregrounded and authenticated to Cerebro.
Disconnect/background suspends that availability and cancels pending proposals
without erasing the preference. Reconnect/foreground restores availability, not
approval: it cannot accept or replay a cancelled request. An approved/manual
action remains nonterminal with stop/hold marked unconfirmed until a terminal
outcome is reported; losing the UI is not proof that hardware stopped.

The normal flow is:

`Receiving requests -> pending -> operator approves -> accepted -> terminal result`

For Cerebro-owned `arm_operation`, `play_gesture` and `run_startup_test`, Cerebro
performs the approved execution and reports the terminal result. Manual Complete
and Failed are disabled for these operations; Cancel remains available.

On 2026-09-23 the preference and notice runtime fixtures passed, as did the
signed iOS build and signature verification. The update was installed and
launched on Onix16. Debug-library SHA-256:
`d519b559806e38d376cfefd67cde1ab0731f5d511557178892036507b33116dd`.
This verifies installation, not physical arm execution or audible/haptic output.

- **Pending:** The proposal is displayed for an operator decision. Approve, Reject, and Cancel are available.
- **Accepted:** Approval reports permission only. The UI tells the operator to perform the action manually; ROBController still sends no hardware command. Complete, Failed, and Cancel are available.
- **Completed:** Complete is a manual declaration that the operator confirmed the physical outcome. It never means ROBController executed hardware automatically.
- **Rejected / Failed / Cancelled / Expired:** These are terminal outcomes and disable decision controls.
- **Cancellation after approval:** Cerebro's cancel requests and app lifecycle changes request a safe stop but preserve the last known `accepted` or `executing` state until the operator confirms the outcome. The console does not promote approval to execution, and message delivery is never mistaken for observed physical stop.

Duplicate requests from the same sender with the same call ID replay their last status. The bounded replay ledger and terminal tombstones are keyed by both sender and call ID, so one Cerebro session cannot suppress another session's request through an identifier collision. Generated status details are truncated to the protocol limit before they are stored, ensuring every stored retry remains encodable. This coordinator behavior lives in Objective-C and is documented here rather than exercised by the protocol-only Swift fixture.

## Wire protocol

`Consciousness/ROBRobotActionProtocol.swift` is the shared, bounded protocol definition also used by Cerebro. Robot-action messages use its keyed envelope and travel as `.sendData` payloads over the authenticated `_robctl._udp` QUIC connection. Keep the Cerebro and ROBController protocol copies synchronized when changing message kinds, validation limits, sender/recipient binding, or encoding.

The separate Social Roam control authorizes a bounded autonomy session rather
than approving each planner tick. See
[`rob-control-v2-and-autonomy.md`](rob-control-v2-and-autonomy.md).

The standalone fixture covers protocol round trips, sender/recipient preservation and envelope binding, malformed input, expiry, and invalid motion bounds:

```sh
swiftc Consciousness/ROBRobotActionProtocol.swift Tests/ROBRobotActionProtocolFixtureTests.swift -o /tmp/ROBRobotActionProtocolFixtureTests
/tmp/ROBRobotActionProtocolFixtureTests
```
