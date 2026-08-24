# ROBController
This is the controller software for my droid R.O.B.

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
