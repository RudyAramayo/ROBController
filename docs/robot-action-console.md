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

Robot actions default to **Off** on every launch. The operator must explicitly opt in before the controller advertises that it accepts proposals. When the app resigns active or AutoNet reconnects, opt-in resets to Off; returning to the app requires a new opt-in. A pending, unapproved proposal is cancelled. An approved/manual action remains nonterminal with stop/hold marked unconfirmed until the operator returns and reports Complete, Failed, or Cancel; losing the UI is not proof that hardware stopped.

The normal flow is:

`Off -> operator opt-in -> pending -> accepted -> manual terminal result`

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
