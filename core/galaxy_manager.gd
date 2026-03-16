extends Node
## Holds galaxy data (systems, hyperlanes), generates galaxy, provides queries.
## Access via autoload: GalaxyManager

var galaxy: Galaxy = null  ## Current galaxy; null until generated

signal galaxy_generated

## Radius used for hyperlane connection points in system local space (same units as ship position_in_system).
const SYSTEM_EDGE_RADIUS: float = 1500.0  # Beyond expanded Sol orbits (Oort ~1390)


func generate_galaxy(system_count: int = 50, seed_value: int = -1, num_ai_empires: int = 2) -> void:
	var opts: Dictionary = {
		"system_count": system_count,
		"seed_value": seed_value,
		"num_ai_empires": num_ai_empires,
		"galaxy_shape": "elliptical",
		"hyperlane_density": "medium",
		"wormhole_pairs": 0
	}
	generate_galaxy_from_options(opts)


func generate_galaxy_from_options(options: Dictionary) -> void:
	var gen := GalaxyGenerator.new()
	galaxy = gen.generate_with_options(options)
	galaxy_generated.emit()


func get_system(system_id: int) -> StarSystem:
	if galaxy == null:
		return null
	for s in galaxy.systems:
		if s.id == system_id:
			return s
	return null


func get_system_neighbors(system_id: int) -> Array[StarSystem]:
	var result: Array[StarSystem] = []
	if galaxy == null:
		return result
	for edge in galaxy.hyperlanes:
		if edge.from_id == system_id:
			var s := get_system(edge.to_id)
			if s != null:
				result.append(s)
		elif edge.to_id == system_id:
			var s := get_system(edge.from_id)
			if s != null:
				result.append(s)
	return result


## Returns position in system local space (same as ship position_in_system) for the hyperlane exit toward the given neighbor.
func get_hyperlane_exit_position_in_system(system_id: int, toward_system_id: int) -> Vector2:
	var sys: StarSystem = get_system(system_id)
	var other: StarSystem = get_system(toward_system_id)
	if sys == null or other == null:
		return Vector2.ZERO
	var dir: Vector2 = (other.position - sys.position).normalized()
	return dir * SYSTEM_EDGE_RADIUS


func get_all_systems() -> Array[StarSystem]:
	if galaxy == null:
		return []
	return galaxy.systems.duplicate()


## True if the system has at least one planet the player can colonize (habitability > 0 and no player colony).
func system_has_colonizable_planet(system_id: int) -> bool:
	var sys: StarSystem = get_system(system_id)
	if sys == null or EmpireManager == null:
		return false
	var player_emp: Empire = EmpireManager.get_player_empire()
	if player_emp == null:
		return false
	for p_idx in sys.planets.size():
		var planet: Planet = sys.planets[p_idx]
		if planet.habitability <= 0.0:
			continue
		if player_emp.get_colony(system_id, p_idx) == null:
			return true
	return false


## BFS path via hyperlanes. Returns [from_id, ..., to_id] or [] if no path.
func get_path_between_systems(from_system_id: int, to_system_id: int) -> Array[int]:
	if galaxy == null or get_system(from_system_id) == null or get_system(to_system_id) == null:
		return []
	if from_system_id == to_system_id:
		return [from_system_id]
	var queue: Array[Array] = []  # each element: [current_id, path so far]
	var visited: Dictionary = {}
	queue.append([from_system_id, [from_system_id]])
	visited[from_system_id] = true
	while queue.size() > 0:
		var front: Array = queue.pop_front()
		var cur_id: int = front[0]
		var path: Array = front[1]
		var neighbors: Array[StarSystem] = get_system_neighbors(cur_id)
		for nb in neighbors:
			var next_id: int = nb.id
			if visited.get(next_id, false):
				continue
			visited[next_id] = true
			var new_path: Array = path.duplicate()
			new_path.append(next_id)
			if next_id == to_system_id:
				var out: Array[int] = []
				for p in new_path:
					out.append(p as int)
				return out
			queue.append([next_id, new_path])
	return []


func clear_galaxy() -> void:
	galaxy = null
