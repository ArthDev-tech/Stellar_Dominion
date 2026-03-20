extends Node
## Autoload: galaxy ship selection by ShipData; filter for FleetPanel display only.

var selected_ships: Array[ShipData] = []
var selection_filter: String = "all"
## Registered galaxy ship icon nodes; used for click/box selection so new icons are always included.
var _icon_registry: Array = []

signal selection_changed(ships: Array)
signal filter_changed(filter: String)


func _ready() -> void:
	selected_ships.clear()


func register_ship_icon(icon: Node) -> void:
	if icon != null and icon not in _icon_registry:
		_icon_registry.append(icon)


func unregister_ship_icon(icon: Node) -> void:
	_icon_registry.erase(icon)


func clear_icon_registry() -> void:
	_icon_registry.clear()


func get_registered_icons() -> Array:
	return _icon_registry.duplicate()


func set_selection(ships_data: Array) -> void:
	_all_icons_galaxy_selected(false)
	selected_ships.clear()
	for item in ships_data:
		if item is ShipData:
			var sd: ShipData = (item as ShipData).duplicate_selection()
			_apply_live_ship_to_ship_data(sd)
			selected_ships.append(sd)
	_highlight_matching_icons()
	_emit_selection_once()


func add_to_selection(ships_data: Array) -> void:
	for item in ships_data:
		if not item is ShipData:
			continue
		var sd: ShipData = item as ShipData
		if _has_ship_entry(sd):
			continue
		var copy: ShipData = sd.duplicate_selection()
		_apply_live_ship_to_ship_data(copy)
		selected_ships.append(copy)
	_highlight_matching_icons()
	_emit_selection_once()


func clear_selection() -> void:
	_all_icons_galaxy_selected(false)
	if selected_ships.is_empty():
		return
	selected_ships.clear()
	_emit_selection_once()


func set_selection_filter(f: String) -> void:
	if selection_filter == f:
		return
	selection_filter = f
	filter_changed.emit(f)


func has_ship_selection_at_system(system_id: int) -> bool:
	for sd in selected_ships:
		if sd.galaxy_system_id == system_id:
			return true
	return false


func sync_selected_ship_locations_from_empire() -> void:
	if EmpireManager == null:
		return
	var emp: Empire = EmpireManager.get_player_empire()
	if emp == null:
		return
	for sd in selected_ships:
		for s in emp.ships:
			var ship: Ship = s as Ship
			if ship == null:
				continue
			if sd.galaxy_selection_instance_id != 0:
				if ship.get_instance_id() != sd.galaxy_selection_instance_id:
					continue
			elif ship.name_key != sd.ship_name or ship.empire_id != sd.galaxy_empire_id:
				continue
			sd.galaxy_system_id = ship.system_id
			_apply_live_ship_to_ship_data(sd)
			break


func _apply_live_ship_to_ship_data(sd: ShipData) -> void:
	if EmpireManager == null:
		return
	var emp: Empire = EmpireManager.get_player_empire()
	if emp == null:
		return
	for s in emp.ships:
		var ship: Ship = s as Ship
		if ship == null:
			continue
		if sd.galaxy_selection_instance_id != 0:
			if ship.get_instance_id() != sd.galaxy_selection_instance_id:
				continue
		elif ship.name_key != sd.ship_name or ship.empire_id != sd.galaxy_empire_id:
			continue
		sd.galaxy_system_id = ship.system_id
		if ship.in_hyperlane:
			sd.transit_days_total = ship.hyperlane_transit_days
			sd.transit_days_remaining = ceili((1.0 - ship.hyperlane_progress) * float(ship.hyperlane_transit_days))
		else:
			sd.transit_days_remaining = 0
			sd.transit_days_total = 0
		break


func get_selected_live_ships_in_system(system_id: int) -> Array:
	var out: Array = []
	if EmpireManager == null:
		return out
	var emp: Empire = EmpireManager.get_player_empire()
	if emp == null:
		return out
	for sd in selected_ships:
		if sd.galaxy_system_id != system_id:
			continue
		for s in emp.ships:
			var ship: Ship = s as Ship
			if ship != null and sd.matches_ship(ship):
				out.append(ship)
				break
	return out


func _has_ship_entry(sd: ShipData) -> bool:
	for e in selected_ships:
		if sd.galaxy_selection_instance_id != 0 and e.galaxy_selection_instance_id == sd.galaxy_selection_instance_id:
			return true
		if sd.galaxy_selection_instance_id == 0 and e.ship_name == sd.ship_name and e.galaxy_system_id == sd.galaxy_system_id and e.galaxy_empire_id == sd.galaxy_empire_id:
			return true
	return false


func _all_icons_galaxy_selected(off: bool) -> void:
	var icons: Array = get_registered_icons()
	if icons.is_empty():
		var tree: SceneTree = get_tree()
		if tree != null:
			icons = tree.get_nodes_in_group("galaxy_ship_icons")
	for n in icons:
		if is_instance_valid(n) and n.has_method("set_galaxy_selected"):
			n.call("set_galaxy_selected", off)


func _highlight_matching_icons() -> void:
	sync_selected_ship_locations_from_empire()
	var icons: Array = get_registered_icons()
	if icons.is_empty():
		var tree: SceneTree = get_tree()
		if tree != null:
			icons = tree.get_nodes_in_group("galaxy_ship_icons")
	for n in icons:
		if not is_instance_valid(n) or not n.has_method("set_galaxy_selected") or not n.has_method("get_galaxy_ship"):
			continue
		var sh: Ship = n.call("get_galaxy_ship") as Ship
		var on: bool = false
		for sd in selected_ships:
			if sh != null and sd.matches_ship(sh):
				on = true
				break
		n.call("set_galaxy_selected", on)


func refresh_after_galaxy_ship_rebuild() -> void:
	_highlight_matching_icons()


func _emit_selection_once() -> void:
	var dup: Array = []
	for sd in selected_ships:
		dup.append(sd.duplicate_selection())
	selection_changed.emit(dup)
