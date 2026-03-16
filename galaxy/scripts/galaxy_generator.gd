class_name GalaxyGenerator
extends RefCounted
## Procedural galaxy generator: systems, positions, hyperlanes, star types, planets.

const MIN_DISTANCE_SQ := 8000.0  ## Min squared distance between systems (avoid overlap)
const HYPERLANE_MAX_DISTANCE_SQ := 350000.0  ## Max squared distance to connect two systems
const GALAXY_RADIUS := 1200.0

var _rng: RandomNumberGenerator
var _galaxy_shape: String = "elliptical"
var _hyperlane_max_dist_sq: float = HYPERLANE_MAX_DISTANCE_SQ
var _hyperlane_max_neighbors: int = 5


func generate(system_count: int, seed_value: int = -1, num_ai_empires: int = 2) -> Galaxy:
	var opts: Dictionary = {
		"system_count": system_count,
		"seed_value": seed_value,
		"num_ai_empires": num_ai_empires,
		"galaxy_shape": "elliptical",
		"hyperlane_density": "medium",
		"wormhole_pairs": 0
	}
	return generate_with_options(opts)


func generate_with_options(options: Dictionary) -> Galaxy:
	_rng = RandomNumberGenerator.new()
	var seed_val: Variant = options.get("seed_value", -1)
	if seed_val is int and seed_val >= 0:
		_rng.seed = seed_val
	else:
		_rng.randomize()

	var system_count: int = int(options.get("system_count", 50))
	var num_ai_empires: int = int(options.get("num_ai_empires", 2))
	var wormhole_pairs_count: int = int(options.get("wormhole_pairs", 0))

	_galaxy_shape = str(options.get("galaxy_shape", "elliptical"))
	var density: String = str(options.get("hyperlane_density", "medium"))
	match density:
		"low":
			_hyperlane_max_dist_sq = HYPERLANE_MAX_DISTANCE_SQ * 0.5
			_hyperlane_max_neighbors = 3
		"high":
			_hyperlane_max_dist_sq = HYPERLANE_MAX_DISTANCE_SQ * 1.5
			_hyperlane_max_neighbors = 7
		_:
			_hyperlane_max_dist_sq = HYPERLANE_MAX_DISTANCE_SQ
			_hyperlane_max_neighbors = 5

	var galaxy := Galaxy.new()
	_fill_systems(galaxy, system_count)
	_connect_hyperlanes(galaxy)
	if wormhole_pairs_count > 0:
		_place_wormholes(galaxy, wormhole_pairs_count)
	_assign_star_types_and_planets(galaxy)
	_assign_resource_deposits(galaxy)
	var num_empires: int = 1 + num_ai_empires
	_assign_empire_starts(galaxy, num_empires)
	_apply_sol_template_to_home_systems(galaxy)
	_normalize_empire_start_planets(galaxy)
	if galaxy.empire_home_system_ids.size() > 0:
		galaxy.player_home_system_id = galaxy.empire_home_system_ids[0]
	_place_precursor_anomalies(galaxy)
	_place_fallen_empires(galaxy)
	return galaxy


func _fill_systems(galaxy: Galaxy, count: int) -> void:
	var attempts := 0
	var max_attempts := count * 120
	while galaxy.systems.size() < count and attempts < max_attempts:
		attempts += 1
		var pos := _random_position_in_galaxy()
		if _too_near_any(pos, galaxy.systems):
			continue
		var id := galaxy.systems.size()
		var name_key := "system_%d" % id
		var system := StarSystem.new(id, name_key, pos, StarSystem.StarType.G)
		galaxy.systems.append(system)
	if galaxy.systems.size() < count:
		push_warning("GalaxyGenerator: only placed %d of %d systems." % [galaxy.systems.size(), count])


func _random_position_in_galaxy() -> Vector2:
	match _galaxy_shape:
		"spiral_2":
			return _random_position_spiral(2)
		"spiral_4":
			return _random_position_spiral(4)
		"ring":
			return _random_position_ring()
		_:
			# elliptical (default)
			var angle := _rng.randf() * TAU
			var r := sqrt(_rng.randf()) * GALAXY_RADIUS
			return Vector2(cos(angle) * r, sin(angle) * r)


func _random_position_spiral(arm_count: int) -> Vector2:
	var arm: int = _rng.randi() % arm_count
	var t: float = _rng.randf()
	var angle_offset: float = arm * TAU / arm_count
	var spread: float = 0.4
	var angle: float = angle_offset + t * TAU * 0.5 + _rng.randf_range(-spread, spread)
	var r: float = (80.0 + t * (GALAXY_RADIUS - 80.0)) + _rng.randf_range(-60.0, 60.0)
	r = clampf(r, 50.0, GALAXY_RADIUS)
	return Vector2(cos(angle) * r, sin(angle) * r)


func _random_position_ring() -> Vector2:
	var ring_radius: float = GALAXY_RADIUS * 0.6
	var spread: float = GALAXY_RADIUS * 0.25
	var r: float = ring_radius + _rng.randf_range(-spread, spread)
	r = clampf(r, 50.0, GALAXY_RADIUS)
	var angle: float = _rng.randf() * TAU
	return Vector2(cos(angle) * r, sin(angle) * r)


func _too_near_any(pos: Vector2, systems: Array[StarSystem]) -> bool:
	for s in systems:
		if pos.distance_squared_to(s.position) < MIN_DISTANCE_SQ:
			return true
	return false


func _connect_hyperlanes(galaxy: Galaxy) -> void:
	var sys := galaxy.systems
	for i in sys.size():
		var from_pos := sys[i].position
		var nearest: Array[Dictionary] = []  ## { id, dist_sq }
		for j in sys.size():
			if i == j:
				continue
			var d_sq := from_pos.distance_squared_to(sys[j].position)
			if d_sq <= _hyperlane_max_dist_sq:
				nearest.append({ "id": sys[j].id, "dist_sq": d_sq })
		nearest.sort_custom(func(a, b): return a.dist_sq < b.dist_sq)
		var max_neighbors := mini(2 + int(nearest.size() / 5.0), _hyperlane_max_neighbors)
		for k in mini(nearest.size(), max_neighbors):
			var to_id: int = nearest[k].id
			if not _hyperlane_exists(galaxy, sys[i].id, to_id):
				galaxy.hyperlanes.append(Hyperlane.new(sys[i].id, to_id))


func _place_wormholes(galaxy: Galaxy, num_pairs: int) -> void:
	var sys_count: int = galaxy.systems.size()
	if sys_count < 2 or num_pairs <= 0:
		return
	var indices: Array[int] = []
	for i in sys_count:
		indices.append(i)
	indices.shuffle()
	var pairs_to_place: int = mini(num_pairs, int(sys_count / 2.0))
	for i in pairs_to_place:
		var a: int = indices[i * 2]
		var b: int = indices[i * 2 + 1]
		galaxy.wormhole_pairs.append({ "from_id": galaxy.systems[a].id, "to_id": galaxy.systems[b].id })


func _hyperlane_exists(galaxy: Galaxy, from_id: int, to_id: int) -> bool:
	for h in galaxy.hyperlanes:
		if h.from_id == from_id and h.to_id == to_id:
			return true
	return false


func _assign_star_types_and_planets(galaxy: Galaxy) -> void:
	# Normal stars (common) + rare special types
	var normal_star_types: Array[StarSystem.StarType] = [
		StarSystem.StarType.M, StarSystem.StarType.M, StarSystem.StarType.K, StarSystem.StarType.K,
		StarSystem.StarType.G, StarSystem.StarType.G, StarSystem.StarType.F, StarSystem.StarType.A,
		StarSystem.StarType.B, StarSystem.StarType.O
	]
	var special_star_types: Array[StarSystem.StarType] = [
		StarSystem.StarType.BLACK_HOLE,
		StarSystem.StarType.PULSAR,
		StarSystem.StarType.NEUTRON_STAR,
	]
	var planet_types: Array[Planet.PlanetType] = [
		Planet.PlanetType.BARREN, Planet.PlanetType.DESERT, Planet.PlanetType.ARCTIC,
		Planet.PlanetType.TROPICAL, Planet.PlanetType.CONTINENTAL, Planet.PlanetType.OCEAN,
		Planet.PlanetType.GAIA
	]
	for s in galaxy.systems:
		# ~88% normal star, ~4% each for black hole / pulsar / neutron star
		if _rng.randf() < 0.12:
			s.star_type = special_star_types[_rng.randi() % special_star_types.size()]
		else:
			s.star_type = normal_star_types[_rng.randi() % normal_star_types.size()]

		var num_planets: int = _rng.randi_range(0, 6)
		if s.is_special_star():
			num_planets = mini(num_planets, _rng.randi_range(0, 2))  # Fewer planets around special stars
		var used_radii: Array[float] = []
		for p_idx in num_planets:
			var orbit_radius := 80.0 + p_idx * 45.0 + _rng.randf_range(-10, 10)
			used_radii.append(orbit_radius)
			var orbit_angle := _rng.randf() * TAU
			var ptype: Planet.PlanetType = planet_types[_rng.randi() % planet_types.size()]
			var hab: float = 0.0
			if ptype != Planet.PlanetType.BARREN:
				hab = _rng.randf_range(0.3, 1.0)
			var size := _rng.randi_range(8, 20)
			var planet := Planet.new(
				p_idx,
				"%s_planet_%d" % [s.name_key, p_idx],
				ptype,
				hab,
				size,
				orbit_radius,
				orbit_angle
			)
			s.add_planet(planet)

		# Asteroid belts: 0–2 per system, placed between or beyond planet orbits
		var num_belts := _rng.randi_range(0, 2)
		for b_idx in num_belts:
			var inner_r: float = 60.0 + _rng.randf_range(0, 80)
			var outer_r: float = inner_r + 25.0 + _rng.randf_range(0, 40)
			# Avoid overlapping planet orbits
			var overlaps: bool = false
			for r in used_radii:
				if r >= inner_r - 20.0 and r <= outer_r + 20.0:
					overlaps = true
					break
			if overlaps:
				continue
			used_radii.append((inner_r + outer_r) * 0.5)
			var significant: int = _rng.randi_range(0, 15)
			if _rng.randf() < 0.3:
				significant = _rng.randi_range(8, 25)  # Some belts have many significant asteroids
			var belt := AsteroidBelt.new(
				b_idx,
				"%s_belt_%d" % [s.name_key, b_idx],
				inner_r,
				outer_r,
				significant
			)
			s.add_asteroid_belt(belt)


func _assign_resource_deposits(galaxy: Galaxy) -> void:
	for s in galaxy.systems:
		# Star deposits: energy (solar); special stars can have different yields
		var star_energy: float = 2.0 + _rng.randf_range(0, 4.0)
		if s.star_type == StarSystem.StarType.BLACK_HOLE:
			star_energy = _rng.randf_range(0, 2.0)
		elif s.star_type == StarSystem.StarType.PULSAR or s.star_type == StarSystem.StarType.NEUTRON_STAR:
			star_energy = 4.0 + _rng.randf_range(0, 4.0)
		elif s.star_type >= StarSystem.StarType.O:
			star_energy = 5.0 + _rng.randf_range(0, 3.0)
		if star_energy > 0:
			s.star_deposits.append({ "resource_type": GameResources.ResourceType.ENERGY, "amount": star_energy })

		for p in s.planets:
			# Planet deposits: raw resources only. Food comes from farming districts.
			match p.type:
				Planet.PlanetType.BARREN, Planet.PlanetType.DESERT:
					# Dry/rocky: minerals
					if _rng.randf() < 0.75:
						p.deposits.append({ "resource_type": GameResources.ResourceType.MINERALS, "amount": 1.0 + _rng.randi_range(0, 3) })
				Planet.PlanetType.ARCTIC:
					# Cold/icy: either minerals or ice
					if _rng.randf() < 0.5:
						p.deposits.append({ "resource_type": GameResources.ResourceType.MINERALS, "amount": 1.0 + _rng.randi_range(0, 3) })
					else:
						p.deposits.append({ "resource_type": GameResources.ResourceType.ICE, "amount": 1.0 + _rng.randi_range(0, 3) })
				Planet.PlanetType.TROPICAL, Planet.PlanetType.CONTINENTAL, Planet.PlanetType.OCEAN, Planet.PlanetType.GAIA:
					if _rng.randf() < 0.5:
						p.deposits.append({ "resource_type": GameResources.ResourceType.MINERALS, "amount": 1.0 + _rng.randi_range(0, 2) })
					if p.habitability > 0.3 and _rng.randf() < 0.5:
						p.deposits.append({ "resource_type": GameResources.ResourceType.BIOMASS, "amount": 1.0 + _rng.randf_range(0, 2.0) })
				Planet.PlanetType.GAS_GIANT:
					# Gas giants offer gas (and sometimes energy from harvesting)
					p.deposits.append({ "resource_type": GameResources.ResourceType.GAS, "amount": 2.0 + _rng.randi_range(0, 4) })
					if _rng.randf() < 0.5:
						p.deposits.append({ "resource_type": GameResources.ResourceType.ENERGY, "amount": 1.0 + _rng.randf_range(0, 2.0) })
				Planet.PlanetType.LAVA, Planet.PlanetType.HOTHOUSE:
					if _rng.randf() < 0.85:
						p.deposits.append({ "resource_type": GameResources.ResourceType.MINERALS, "amount": 2.0 + _rng.randi_range(0, 4) })
				_:
					if _rng.randf() < 0.5:
						p.deposits.append({ "resource_type": GameResources.ResourceType.MINERALS, "amount": 1.0 + _rng.randi_range(0, 2) })

		for b in s.asteroid_belts:
			# Asteroids / dwarf planets: either minerals or ice
			var yield_val: float = 2.0 + b.significant_asteroids * 0.3 + _rng.randf_range(0, 3.0)
			if _rng.randf() < 0.5:
				b.deposits.append({ "resource_type": GameResources.ResourceType.MINERALS, "amount": yield_val })
			else:
				b.deposits.append({ "resource_type": GameResources.ResourceType.ICE, "amount": yield_val })


func _assign_empire_starts(galaxy: Galaxy, num_empires: int) -> void:
	galaxy.empire_home_system_ids.clear()
	if galaxy.systems.is_empty() or num_empires <= 0:
		return
	# Prefer systems with at least one habitable planet (habitability > 0)
	var candidates: Array[StarSystem] = []
	for s in galaxy.systems:
		if _system_has_habitable_planet(s):
			candidates.append(s)
	if candidates.is_empty():
		candidates = galaxy.systems.duplicate()
	# Minimum Euclidean distance between start positions (squared for comparison)
	const MIN_START_DIST_SQ := 150000.0
	var chosen: Array[StarSystem] = []
	# First pick: random among candidates
	var idx: int = _rng.randi() % candidates.size()
	chosen.append(candidates[idx])
	# Remove chosen from pool for next picks
	var remaining: Array[StarSystem] = []
	for s in candidates:
		if s.id != chosen[0].id:
			remaining.append(s)
	for _i in range(num_empires - 1):
		if remaining.is_empty():
			break
		var best_sys: StarSystem = null
		var best_min_d_sq: float = -1.0
		for s in remaining:
			var min_d_sq: float = INF
			for c in chosen:
				var d_sq: float = s.position.distance_squared_to(c.position)
				min_d_sq = minf(min_d_sq, d_sq)
			if min_d_sq >= MIN_START_DIST_SQ and (best_sys == null or min_d_sq > best_min_d_sq):
				best_min_d_sq = min_d_sq
				best_sys = s
		if best_sys == null:
			# Fallback: pick farthest from any chosen
			for s in remaining:
				var min_d_sq: float = INF
				for c in chosen:
					min_d_sq = minf(min_d_sq, s.position.distance_squared_to(c.position))
				if best_sys == null or min_d_sq > best_min_d_sq:
					best_min_d_sq = min_d_sq
					best_sys = s
		if best_sys == null:
			best_sys = remaining[_rng.randi() % remaining.size()]
		chosen.append(best_sys)
		var new_remaining: Array[StarSystem] = []
		for s in remaining:
			if s.id != best_sys.id:
				new_remaining.append(s)
		remaining = new_remaining
	for s in chosen:
		galaxy.empire_home_system_ids.append(s.id)


func _apply_sol_template_to_home_systems(galaxy: Galaxy) -> void:
	for sid in galaxy.empire_home_system_ids:
		var system: StarSystem = galaxy.get_system_by_id(sid)
		if system != null:
			_apply_sol_template_to_system(system)


func _apply_sol_template_to_system(system: StarSystem) -> void:
	# Overwrite with a Sol-like layout: G star, 4 inner planets (Mercury=LAVA, Venus=Hothouse, Earth=homeworld, Mars=barren), main belt, 4 gas giants, Oort cloud.
	# Orbits scaled up for visibility; gas giants have larger size for visual prominence.
	system.star_type = StarSystem.StarType.G
	system.planets.clear()
	system.asteroid_belts.clear()
	system.star_deposits.clear()
	var prefix: String = system.name_key
	# Inner planets: 1=Mercury (lava), 2=Venus (hothouse), 3=Earth (continental, homeworld), 4=Mars (barren). Orbits expanded for visibility.
	var inner_orbits: Array[float] = [100.0, 145.0, 190.0, 245.0]  # scaled
	for i in inner_orbits.size():
		var orbit_angle: float = _rng.randf() * TAU
		var planet: Planet = null
		match i:
			0:  # Mercury: lava world
				planet = Planet.new(i, "%s_planet_%d" % [prefix, i], Planet.PlanetType.LAVA, 0.0, 8, inner_orbits[i], orbit_angle)
			1:  # Venus: hothouse (0 hab so Earth is first habitable)
				planet = Planet.new(i, "%s_planet_%d" % [prefix, i], Planet.PlanetType.HOTHOUSE, 0.0, 12, inner_orbits[i], orbit_angle)
			2:  # Earth: continental, homeworld (3rd planet)
				planet = Planet.new(i, "%s_planet_%d" % [prefix, i], Planet.PlanetType.CONTINENTAL, 1.0, 19, inner_orbits[i], orbit_angle)
			3:  # Mars: barren
				planet = Planet.new(i, "%s_planet_%d" % [prefix, i], Planet.PlanetType.BARREN, 0.0, 14, inner_orbits[i], orbit_angle)
			_: continue
		if planet != null:
			system.add_planet(planet)
	# Star and inner planet deposits for Sol
	system.star_deposits.append({ "resource_type": GameResources.ResourceType.ENERGY, "amount": 4.0 })
	for p in system.planets:
		if p.type == Planet.PlanetType.LAVA:
			p.deposits.append({ "resource_type": GameResources.ResourceType.MINERALS, "amount": 3.0 })
			p.deposits.append({ "resource_type": GameResources.ResourceType.ENERGY, "amount": 1.5 })
		elif p.type == Planet.PlanetType.HOTHOUSE:
			p.deposits.append({ "resource_type": GameResources.ResourceType.MINERALS, "amount": 2.0 })
		elif p.type == Planet.PlanetType.CONTINENTAL:
			p.deposits.append({ "resource_type": GameResources.ResourceType.MINERALS, "amount": 2.0 })
			p.deposits.append({ "resource_type": GameResources.ResourceType.BIOMASS, "amount": 2.0 })
		elif p.type == Planet.PlanetType.BARREN:
			p.deposits.append({ "resource_type": GameResources.ResourceType.MINERALS, "amount": 4.0 })
	# Main asteroid belt (scaled)
	var belt_inner: float = 305.0
	var belt_outer: float = 380.0
	var belt := AsteroidBelt.new(0, "%s_belt_0" % prefix, belt_inner, belt_outer, 12)
	belt.deposits.append({ "resource_type": GameResources.ResourceType.MINERALS, "amount": 5.0 })
	system.add_asteroid_belt(belt)
	# Gas giants: visibly larger (bigger size value) and expanded orbits
	var gas_orbits: Array[float] = [520.0, 705.0, 890.0, 965.0]  # scaled
	for j in gas_orbits.size():
		var idx: int = 4 + j
		var orbit_angle: float = _rng.randf() * TAU
		var size: int = 28 if j == 0 else (26 if j == 1 else 24)  # Jupiter, Saturn, Uranus/Neptune - larger for visibility
		if j == 3:
			size = 22
		var p: Planet = Planet.new(idx, "%s_planet_%d" % [prefix, idx], Planet.PlanetType.GAS_GIANT, 0.0, size, gas_orbits[j], orbit_angle)
		p.deposits.append({ "resource_type": GameResources.ResourceType.GAS, "amount": 3.0 + _rng.randi_range(0, 2) })
		system.add_planet(p)
	# Oort cloud
	var oort_inner: float = 1110.0
	var oort_outer: float = 1390.0
	var oort_belt := AsteroidBelt.new(1, "%s_belt_1" % prefix, oort_inner, oort_outer, 4)
	oort_belt.deposits.append({ "resource_type": GameResources.ResourceType.MINERALS, "amount": 2.0 })
	system.add_asteroid_belt(oort_belt)


func _normalize_empire_start_planets(galaxy: Galaxy) -> void:
	## Set the starting (capital) planet in each empire home system to size 17-21 for fair starts.
	const START_PLANET_SIZE_MIN := 17
	const START_PLANET_SIZE_MAX := 21
	for sid in galaxy.empire_home_system_ids:
		var sys: StarSystem = galaxy.get_system_by_id(sid)
		if sys == null:
			continue
		for p in sys.planets:
			if p.habitability > 0.0:
				p.size = _rng.randi_range(START_PLANET_SIZE_MIN, START_PLANET_SIZE_MAX)
				break


func _system_has_habitable_planet(system: StarSystem) -> bool:
	for p in system.planets:
		if p.habitability > 0.0:
			return true
	return false


func _place_precursor_anomalies(galaxy: Galaxy) -> void:
	var precursors: Array = _load_precursors()
	if precursors.is_empty():
		return
	var anomaly_id: int = 0
	for p_def in precursors:
		var pid: String = p_def.get("id", "")
		var required: int = p_def.get("anomalies_required", 6)
		var system_ids: Array[int] = []
		for s in galaxy.systems:
			system_ids.append(s.id)
		system_ids.shuffle()
		var placed: int = 0
		for sid in system_ids:
			if placed >= required:
				break
			var a := Anomaly.new(anomaly_id, sid, pid)
			galaxy.anomalies.append(a)
			anomaly_id += 1
			placed += 1


func _load_precursors() -> Array:
	var path: String = ProjectPaths.DATA_PRECURSORS
	if not FileAccess.file_exists(path):
		return []
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var json: JSON = JSON.new()
	if json.parse(f.get_as_text()) != OK:
		f.close()
		return []
	f.close()
	return json.data if json.data is Array else []


func _place_fallen_empires(galaxy: Galaxy) -> void:
	var home_set: Dictionary = {}
	for sid in galaxy.empire_home_system_ids:
		home_set[sid] = true
	var num_fe: int = mini(2, int(galaxy.systems.size() / 30.0))
	if num_fe <= 0:
		return
	var available: Array[int] = []
	for s in galaxy.systems:
		if not (s.id in home_set):
			available.append(s.id)
	if available.size() < 3:
		return
	available.shuffle()
	var idx: int = 0
	var fe_names: Array[String] = ["Vault Keepers", "Elder Guardians"]
	for fe_i in num_fe:
		var fe: FallenEmpire = FallenEmpire.new(fe_i, fe_names[fe_i] if fe_i < fe_names.size() else "Fallen Empire %d" % fe_i)
		var cluster_size: int = _rng.randi_range(2, 4)
		for _k in cluster_size:
			if idx >= available.size():
				break
			fe.system_ids.append(available[idx])
			idx += 1
		if fe.system_ids.size() > 0:
			galaxy.fallen_empires.append(fe)
