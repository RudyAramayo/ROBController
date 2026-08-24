# Robot control authority status

The persistent ROBController status separates an authenticated network link from robot motion
authority. A connected controller starts at **LINK VERIFIED • CONTROL UNCONFIRMED**. Pressing
**Request Control** changes the status to amber while the app waits for Cerebro's
`ROBControlAuthorityStateV1` response.

Only an update naming this controller's device ID changes the indicator to green and displays
**CONTROL GRANTED BY ROBOT**. A response naming Cerebro, autonomy, or another controller remains
amber and reports that control was not granted. A missing response returns to the unconfirmed
state after four seconds. Disconnecting always clears the last authority confirmation.
