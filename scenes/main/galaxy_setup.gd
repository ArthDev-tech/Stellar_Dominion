extends Control
## Galaxy setup menu: options for galaxy shape, size, hyperlanes, wormholes, AI. Start Game generates and launches.

@onready var stars_option: OptionButton = $MarginContainer/ScrollContainer/VBox/OptionsGrid/StarsOption
@onready var shape_option: OptionButton = $MarginContainer/ScrollContainer/VBox/OptionsGrid/ShapeOption
@onready var hyperlane_option: OptionButton = $MarginContainer/ScrollContainer/VBox/OptionsGrid/HyperlaneOption
@onready var wormhole_spin: SpinBox = $MarginContainer/ScrollContainer/VBox/OptionsGrid/WormholeSpin
@onready var ai_spin: SpinBox = $MarginContainer/ScrollContainer/VBox/OptionsGrid/AISpin
@onready var seed_edit: LineEdit = $MarginContainer/ScrollContainer/VBox/OptionsGrid/SeedEdit
@onready var dev_testing_check: CheckBox = $MarginContainer/ScrollContainer/VBox/OptionsGrid/DevTestingCheck
@onready var start_button: Button = $MarginContainer/ScrollContainer/VBox/Buttons/StartButton
@onready var back_button: Button = $MarginContainer/ScrollContainer/VBox/Buttons/BackButton


func _ready() -> void:
	_populate_stars()
	_populate_shape()
	_populate_hyperlane()
	wormhole_spin.min_value = 0
	wormhole_spin.max_value = 20
	wormhole_spin.value = 0
	ai_spin.min_value = 0
	ai_spin.max_value = 4
	ai_spin.value = 2
	seed_edit.placeholder_text = "Random"
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)


func _populate_stars() -> void:
	stars_option.clear()
	stars_option.add_item("50", 50)
	stars_option.add_item("100", 100)
	stars_option.add_item("150", 150)
	stars_option.add_item("200", 200)
	stars_option.add_item("300", 300)
	stars_option.add_item("400", 400)
	stars_option.selected = 1  # 100


func _populate_shape() -> void:
	shape_option.clear()
	shape_option.add_item("Elliptical", 0)
	shape_option.add_item("Spiral 2-Arm", 1)
	shape_option.add_item("Spiral 4-Arm", 2)
	shape_option.add_item("Ring", 3)


func _populate_hyperlane() -> void:
	hyperlane_option.clear()
	hyperlane_option.add_item("Low", 0)
	hyperlane_option.add_item("Medium", 1)
	hyperlane_option.add_item("High", 2)
	hyperlane_option.selected = 1


func _get_shape_key() -> String:
	match shape_option.selected:
		1: return "spiral_2"
		2: return "spiral_4"
		3: return "ring"
		_: return "elliptical"


func _get_hyperlane_key() -> String:
	match hyperlane_option.selected:
		0: return "low"
		2: return "high"
		_: return "medium"


func _on_start_pressed() -> void:
	var system_count: int = int(stars_option.get_item_id(stars_option.selected))
	var seed_value: int = -1
	if seed_edit.text.strip_edges().is_valid_int():
		seed_value = int(seed_edit.text.strip_edges())
	var options: Dictionary = {
		"system_count": system_count,
		"galaxy_shape": _get_shape_key(),
		"hyperlane_density": _get_hyperlane_key(),
		"wormhole_pairs": int(wormhole_spin.value),
		"num_ai_empires": int(ai_spin.value),
		"seed_value": seed_value
	}
	GalaxyManager.generate_galaxy_from_options(options)
	EmpireManager.create_empires_from_galaxy(GalaxyManager.galaxy, dev_testing_check.button_pressed)
	GameState.start_new_game()
	get_tree().change_scene_to_file(ProjectPaths.SCENE_GAME_SCENE)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(ProjectPaths.SCENE_MAIN_MENU)
