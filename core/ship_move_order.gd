extends Node
## Single entry for hyperlane move orders (galaxy + system view). Tunables pushed from GameplayConfig at runtime.

var jump_point_radius_galaxy: float = 400.0
var jump_point_lane_fraction: float = 0.2


func apply_gameplay_config(cfg: GameplayConfig) -> void:
	if cfg == null:
		return
	jump_point_radius_galaxy = cfg.jump_point_radius_galaxy
	jump_point_lane_fraction = clampf(cfg.jump_point_lane_fraction, 0.05, 0.45)


## Galaxy map world space: point near destination along the origin→dest axis (same space as StarSystem.position / ship icons on ShipsLayer).
func compute_jump_point_galaxy(origin_pos: Vector2, dest_pos: Vector2) -> Vector2:
	var delta: Vector2 = dest_pos - origin_pos
	var lane_len: float = delta.length()
	if lane_len < 0.001:
		return dest_pos
	var dir: Vector2 = delta / lane_len
	var k: float = jump_point_lane_fraction
	var min_r: float = lane_len * 0.1
	var max_r: float = lane_len * k
	var effective_r: float = minf(jump_point_radius_galaxy, maxf(min_r, max_r))
	return dest_pos - dir * effective_r


func cancel_transit_and_prepare_reorder(ship: Ship) -> void:
	if ship == null:
		return
	ship.in_hyperlane = false
	ship.hyperlane_to_system_id = -1
	ship.hyperlane_progress = 0.0
	ship.transit_origin_galaxy = Vector2.ZERO
	ship.transit_origin_galaxy_valid = false


func issue_move_orders_for_ships(ships: Array, source_system_id: int, destination_system_id: int) -> void:
	if GalaxyManager == null or source_system_id < 0 or destination_system_id < 0:
		return
	if source_system_id == destination_system_id:
		return
	var neighbors: Array[StarSystem] = GalaxyManager.get_system_neighbors(source_system_id)
	var target_is_neighbor: bool = false
	for nb in neighbors:
		if nb.id == destination_system_id:
			target_is_neighbor = true
			break
	var first_hop: int = -1
	var path_rest: Array[int] = []
	if target_is_neighbor:
		first_hop = destination_system_id
	else:
		var path: Array[int] = GalaxyManager.get_path_between_systems(source_system_id, destination_system_id)
		if path.size() < 2:
			return
		first_hop = path[1]
		for i in range(2, path.size()):
			path_rest.append(path[i])
	for item in ships:
		var ship: Ship = item as Ship
		if ship == null:
			continue
		cancel_transit_and_prepare_reorder(ship)
		ship.target_system_id = first_hop
		ship.path_queue = path_rest.duplicate()
		ship.target_position = Vector2(-99999.0, -99999.0)
		# Do not snap to hyperlane exit — ship walks in system view to jump point (see Ship.tick_movement).
