# ROBController
This is the controller software for my droid R.O.B.

**Action Approvals** is a remembered preference for receiving requests, enabled
by default. It resumes after an authenticated reconnect or return to the
foreground; an explicit Off choice stays off. Disconnecting or backgrounding
still cancels pending requests. Restoring the preference never approves a
movement or replays an old request: each operation needs its own Approve tap.

With **Action Approvals** enabled in the foreground, a new AI request plays a
short two-note ping, gives a warning haptic on supported iPhones, and shows an
orange **AI APPROVAL REQUESTED** banner above every tab with the time remaining.
Tap the banner to review the full operation and choose Approve or Reject. One
sound/haptic reminder follows after ten seconds if the request is still pending;
duplicate packets do not restart alerts. Alerts end on approval, rejection,
cancellation, expiry, disconnect or leaving the foreground. The banner never
grants permission itself. Device sound/haptic settings apply; use **Settings →
Test AI Approval Sound + Vibration** to check them without requesting motion.

`python3 Tests/ROBApprovalNoticeRuntimeTests.py` exercises the production notice
lifecycle with inert UI/audio/transport substitutes: duplicate refreshes, one
reminder, expiry, terminal-state cleanup, disconnect and background suppression.
It does not send robot commands or establish physical sound/haptic output.
`python3 Tests/ROBApprovalPreferenceRuntimeTests.py` checks preference recovery,
explicit Off, foreground/connection gating and cancellation without an approval
being created or replayed.

For wireless iPhone development, use the **ROBController Wireless** scheme to
run the Debug build without LLDB attached. See [wireless debugging](docs/wireless-debugging.md)
for the startup-stutter comparison and normal breakpoint debugging.

On iPhone, open **Auto → Open Follow Mode** (also **Admin → Follow**), tap **Refresh
Main-Camera Preview**, select an outlined person, then **Authorize Selected
Person**. Authorization can start physical motion; test only under operator
supervision with working stop controls. **STOP FOLLOW MODE** revokes the target.
This flow uses a fresh image from Cerebro, not an arbitrary photo-library image.
It requires a current Cerebro build, an authenticated controller session, and
fresh depth, belly-camera safety and lidar data. Read the displayed blocker
instead of bypassing a missing sensor or calibration gate.

On the RPLidar map, long-press ROB's actual position to calibrate the perceived
lidar location. The map settings menu also provides **Set ROB to Map Center**
and **Use Device GPS**; the persisted east/north correction follows subsequent
device-location updates until reset.

Destination taps preserve the current zoom. The map's **Missions** menu creates
and saves named multi-stop paths: enable **Add Stops**, tap each waypoint in
order, and use the menu to reopen, reverse, edit, or delete mission paths.
Choosing **Use as Destination** on a saved stop sends it through the existing
navigation authorization and Cerebro safety checks.

<img width="2622" height="1206" alt="IMG_5920" src="https://github.com/user-attachments/assets/15715bee-f526-4fcc-9982-b98e69a292a2" />
