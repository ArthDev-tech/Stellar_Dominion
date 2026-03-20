class_name Ship
extends RefCounted
## A ship built at a station. Moves toward waypoints over time; can travel between systems via hyperlanes.

var empire_id: int
var system_id: int  ## Which star system the ship is in (or departing from when in_hyperlane)
var design_id: String  ## From ship_designs.json
var name_key: String  ## Display name (e.g. "Corvette")
## Current position in system (world space). Updated each day toward target.
var position_in_system: Vector2 = Vector2.ZERO
## Waypoint; invalid sentinel (-99999,-99999) = no order.
var target_position: Vector2 = Vector2(-99999.0, -99999.0)
## Order to go to another system; -1 = none.
var target_system_id: int = -1
## Remaining system IDs to visit after current target (multi-hop). Cleared when empty.
## AUDIT: NEEDS REVIEW — total trip time for multi-hop must sum each hop's transit days.
var path_queue: Array[int] = []
## True when ship is in hyperlane transit (system_id still = from_system until arrival at dest jump point).
var in_hyperlane: bool = false
var hyperlane_to_system_id: int = -1
var hyperlane_progress: float = 0.0  ## 0..1, advances each day
## Days to traverse current jump (set when entering hyperlane; from base_transit_days * transit_time_modifier).
var hyperlane_transit_days: int = 180
## Drive modifier for transit time (1.0 = baseline; set from design when ship is built).
var transit_time_modifier: float = 1.0
## Galaxy map world: lerp start for hyperlane phase (system center or icon pos after mid-flight reorder).
## # AUDIT: NEEDS REVIEW if parent transforms move — must stay same space as StarSystem.position / icon global_position.
var transit_origin_galaxy: Vector2 = Vector2.ZERO
var transit_origin_galaxy_valid: bool = false
## Set from galaxy map before reorder while in_hyperlane; consumed when entering hyperlane.
var pending_galaxy_transit_origin_use: bool = false
var pending_galaxy_transit_origin: Vector2 = Vector2.ZERO
## Facing angle in radians (0 = right). Updated toward movement direction.
var facing_angle: float = 0.0
## When set, ship is building a resource station. Keys: type, system_id, body_type, body_index, progress_months, build_time_months
var build_order: Dictionary = {}

const SPEED_UNITS_PER_DAY: float = 2.5
const ARRIVAL_DISTANCE_SQ: float = 4.0  ## Arrived when within 2 units
const MIN_TRANSIT_DAYS: int = 30  ## Minimum days per jump (clamp floor)


func _init(p_empire_id: int, p_system_id: int, p_design_id: String, p_name_key: String) -> void:
	empire_id = p_empire_id
	system_id = p_system_id
	design_id = p_design_id
	name_key = p_name_key


func has_move_order() -> bool:
	return target_position.x > -99998.0 or target_system_id >= 0 or in_hyperlane


func has_build_order() -> bool:
	return build_order.get("type", "") == "resource_station"


## Returns world position of the build target body in the given system (star = system-local origin, planet/belt = orbit position).
func get_build_target_position_in_system(sys: StarSystem, body_type: String, body_index: int) -> Vector2:
	if sys == null:
		return Vector2.ZERO
	if body_type == "star":
		return Vector2.ZERO
	if body_type == "planet" and body_index >= 0 and body_index < sys.planets.size():
		var p: Planet = sys.planets[body_index]
		var pos: Vector2 = Vector2(cos(p.orbit_angle), sin(p.orbit_angle)) * p.orbit_radius
		return pos
	if body_type == "belt" and body_index >= 0 and body_index < sys.asteroid_belts.size():
		var b: AsteroidBelt = sys.asteroid_belts[body_index]
		var mid_r: float = (b.inner_radius + b.outer_radius) * 0.5
		return Vector2(mid_r, 0.0)
	return Vector2.ZERO


func _compute_transit_days_for_ship() -> int:
	var base: int = 180
	if EconomyManager != null:
		base = EconomyManager.base_transit_days
	var actual: int = clampi(int(base * transit_time_modifier), MIN_TRANSIT_DAYS, 99999)
	return actual


## Move toward waypoint or through hyperlane. delta_days can be fractional for smooth movement at low game speed.
func tick_movement(delta_days: float = 1.0) -> void:
	if delta_days <= 0.0:
		return
	# In hyperlane: advance progress; on completion arrive at destination jump point (system view), not star center.
	if in_hyperlane:
		hyperlane_progress += delta_days / float(hyperlane_transit_days)
		if hyperlane_progress >= 1.0:
			var from_id: int = system_id
			var to_id: int = hyperlane_to_system_id
			system_id = to_id
			var jump_pos: Vector2 = Vector2.ZERO
			if GalaxyManager != null:
				jump_pos = GalaxyManager.get_hyperlane_exit_position_in_system(to_id, from_id)
			position_in_system = jump_pos
			in_hyperlane = false
			hyperlane_to_system_id = -1
			hyperlane_progress = 0.0
			transit_origin_galaxy = Vector2.ZERO
			transit_origin_galaxy_valid = false
			if path_queue.size() > 0:
				target_system_id = path_queue[0]
				path_queue.remove_at(0)
			else:
				target_system_id = -1
			if has_build_order() and GalaxyManager != null and build_order.get("system_id", -1) == system_id:
				var sys: StarSystem = GalaxyManager.get_system(system_id)
				target_position = get_build_target_position_in_system(sys, build_order.get("body_type", ""), int(build_order.get("body_index", 0)))
			var to_center: Vector2 = -jump_pos
			if to_center.length_squared() > 0.0001:
				facing_angle = atan2(to_center.y, to_center.x)
		return

	# Order to another system: move in-system toward hyperlane exit, then enter hyperlane.
	if target_system_id >= 0:
		var exit_pos: Vector2 = Vector2.ZERO
		if GalaxyManager != null:
			exit_pos = GalaxyManager.get_hyperlane_exit_position_in_system(system_id, target_system_id)
		target_position = exit_pos
		var to_exit: Vector2 = target_position - position_in_system
		var dist_sq_exit: float = to_exit.length_squared()
		if dist_sq_exit <= ARRIVAL_DISTANCE_SQ:
			in_hyperlane = true
			hyperlane_to_system_id = target_system_id
			hyperlane_progress = 0.0
			hyperlane_transit_days = _compute_transit_days_for_ship()
			target_position = Vector2(-99999.0, -99999.0)
			if pending_galaxy_transit_origin_use:
				transit_origin_galaxy = pending_galaxy_transit_origin
				pending_galaxy_transit_origin_use = false
			elif GalaxyManager != null:
				var cur: StarSystem = GalaxyManager.get_system(system_id)
				transit_origin_galaxy = cur.position if cur != null else Vector2.ZERO
			else:
				transit_origin_galaxy = Vector2.ZERO
			transit_origin_galaxy_valid = true
			var dest_name: String = "?"
			if GalaxyManager != null:
				var dest: StarSystem = GalaxyManager.get_system(hyperlane_to_system_id)
				if dest != null:
					dest_name = dest.name_key
			print("Ship %s moving to %s: %d days (%.0f%% speed)" % [name_key, dest_name, hyperlane_transit_days, transit_time_modifier * 100.0])
			return
		var step_exit: float = minf(SPEED_UNITS_PER_DAY * delta_days, sqrt(dist_sq_exit))
		position_in_system += to_exit.normalized() * step_exit
		facing_angle = atan2(to_exit.y, to_exit.x)
		return

	# In-system waypoint only
	if not (target_position.x > -99998.0):
		return
	var to_target: Vector2 = target_position - position_in_system
	var dist_sq: float = to_target.length_squared()
	if dist_sq <= ARRIVAL_DISTANCE_SQ:
		position_in_system = target_position
		if not has_build_order():
			target_position = Vector2(-99999.0, -99999.0)
		return
	var step: float = minf(SPEED_UNITS_PER_DAY * delta_days, sqrt(dist_sq))
	position_in_system += to_target.normalized() * step
	facing_angle = atan2(to_target.y, to_target.x)
