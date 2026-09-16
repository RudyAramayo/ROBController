# Robot control authority status

The persistent ROBController status separates an authenticated network link from robot motion
authority. A connected controller starts at **LINK VERIFIED • CONTROL UNCONFIRMED**. Pressing
**Request Control** changes the status to amber while the app waits for Cerebro's
`ROBControlAuthorityStateV1` response.

Only an update naming this controller's device ID changes the indicator to green and displays
**CONTROL GRANTED BY ROBOT**. A response naming Cerebro, autonomy, or another controller remains
amber and reports that control was not granted. A missing response returns to the unconfirmed
state after four seconds. Disconnecting always clears the last authority confirmation.

On iPhone, Reconnect and Request Control share a dedicated row with equal-width
buttons at least 44 points tall. The status wraps above them and the overlay sizes
to its contents, including long pairing failures and portrait layouts. Its content
respects the horizontal safe area when rotated.

While disconnected, the latest connection failure remains visible during automatic
retries. Request Control stays disabled until authentication succeeds; a visible
button does not bypass pairing or the robot's authority confirmation.
