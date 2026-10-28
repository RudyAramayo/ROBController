# Recycle Cans

The map's **Missions** menu includes **Recycle Cans**, alongside saved waypoint
paths. Its destination is **Orange bucket**. The radius and maximum can count
are saved on this controller. Start covers camera search, gentle tread travel
and checked right-arm recycling phases for 30 minutes, without another approval
at each waypoint. Live status shows searched stops, verified transfers and the
reason for any pause. **Stop and hold** remains queued until acknowledged.

The controller supplies intent; paired Cerebro owns room-map routes, measured
progress, perception and arm execution. It searches the immediate right and
left, selects reachable free-space observation stops and reacquires targets
after movement. GPS and satellite display alignment do not define this room
mission's distances. This requires updated Cerebro and RPLidar builds.

Current manipulation limits remain visible: transfers use the native stationary
can-to-bucket executor. Carrying a held can to another base position is not yet
connected. An unverified landing or possible payload pauses the mission and
does not increase the recycling count. This release has not demonstrated a
complete room-wide pickup/carry/drop cycle on hardware.

An authenticated Start is the task authorization; status/query traffic never
starts motion. Disconnect/restart ends the old route. When an interrupted phase
may have a payload, the operator can inspect/remove the object and select
**I inspected the gripper: it is empty**. That records an observation only;
continuing requires a fresh mission plan and never replays old arm waypoints.
