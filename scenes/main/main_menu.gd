extends Control
## Main menu: New Game opens galaxy setup; Quick Start uses preset options and launches.

@onready var new_game_button: Button = $MarginContainer/VBoxContainer/NewGameButton
@onready var quick_start_button: Button = $MarginContainer/VBoxContainer/QuickStartButton
@onready var dev_testing_check: CheckBox = $MarginContainer/VBoxContainer/DevTestingCheck
@onready var quit_button: Button = $MarginContainer/VBoxContainer/QuitButton
@onready var music_play_button: Button = $MusicPlayerPanel/MarginContainer/HBox/MusicPlayButton
@onready var music_pause_button: Button = $MusicPlayerPanel/MarginContainer/HBox/MusicPauseButton
@onready var music_next_button: Button = $MusicPlayerPanel/MarginContainer/HBox/MusicNextButton
@onready var music_volume_slider: HSlider = $MusicPlayerPanel/MarginContainer/HBox/MusicVolumeSlider


func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	quick_start_button.pressed.connect(_on_quick_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	if music_play_button != null:
		music_play_button.pressed.connect(MusicPlayer.play)
	if music_pause_button != null:
		music_pause_button.pressed.connect(MusicPlayer.pause)
	if music_next_button != null:
		music_next_button.pressed.connect(MusicPlayer.next_track)
	if MusicPlayer != null:
		MusicPlayer.playback_state_changed.connect(_on_music_playback_state_changed)
		_on_music_playback_state_changed(MusicPlayer.is_playing())
	if music_volume_slider != null:
		music_volume_slider.value = MusicPlayer.get_volume_linear() if MusicPlayer != null else 0.15
		music_volume_slider.value_changed.connect(_on_music_volume_changed)


func _on_music_playback_state_changed(playing: bool) -> void:
	if music_play_button != null:
		music_play_button.visible = not playing
	if music_pause_button != null:
		music_pause_button.visible = playing


func _on_music_volume_changed(value: float) -> void:
	if MusicPlayer != null:
		MusicPlayer.set_volume_linear(value)


func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file(ProjectPaths.SCENE_GALAXY_SETUP)


func _on_quick_start_pressed() -> void:
	var options: Dictionary = {
		"system_count": 300,
		"galaxy_shape": "spiral_4",
		"hyperlane_density": "medium",
		"wormhole_pairs": 5,
		"num_ai_empires": 6,
		"seed_value": -1
	}
	GalaxyManager.generate_galaxy_from_options(options)
	EmpireManager.create_empires_from_galaxy(GalaxyManager.galaxy, dev_testing_check.button_pressed)
	GameState.start_new_game()
	get_tree().change_scene_to_file(ProjectPaths.SCENE_GAME_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()
