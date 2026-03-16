extends Node

const LOG_PREFIX = "[DebugLogger]"

func _ready() -> void:
	print("[DebugLogger] Initialized")
	# Disabled: button tracking floods output during development
	# get_tree().node_added.connect(_on_node_added)
	# get_tree().node_removed.connect(_on_node_removed)

func _on_node_added(node: Node) -> void:
	if node is Button or node is BaseButton:
		print(LOG_PREFIX + " Button added to tree: %s at %s" % [node.name, node.get_path()])
		if not node.pressed.is_connected(_on_any_button_pressed):
			node.pressed.connect(_on_any_button_pressed.bind(node.get_path()))

func _on_node_removed(node: Node) -> void:
	pass  # reserved for future tracking

func _on_any_button_pressed(node_path: NodePath) -> void:
	print(LOG_PREFIX + " Button pressed: %s" % node_path)

func log_info(system: String, message: String) -> void:
	print("[%s] %s" % [system, message])

func log_error(system: String, message: String) -> void:
	push_error("[%s] ERROR: %s" % [system, message])
