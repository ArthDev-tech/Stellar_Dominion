extends Node
## Autoload: owns galaxy (and system view) ship selection state. Drives selected property on ship nodes.

var selected_ships: Array[Node] = []

signal selection_changed(ships: Array)


func set_selection(ships: Array) -> void:
	for s in selected_ships:
		if is_instance_valid(s) and "selected" in s:
			s.selected = false
	selected_ships.clear()
	for n in ships:
		selected_ships.append(n)
	for s in selected_ships:
		if is_instance_valid(s) and "selected" in s:
			s.selected = true
	selection_changed.emit(selected_ships)


func add_to_selection(ships: Array) -> void:
	for s in ships:
		if s not in selected_ships:
			selected_ships.append(s)
			if is_instance_valid(s) and "selected" in s:
				s.selected = true
	selection_changed.emit(selected_ships)


func clear_selection() -> void:
	set_selection([])
