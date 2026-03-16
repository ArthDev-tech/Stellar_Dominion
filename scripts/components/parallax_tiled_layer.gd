extends ParallaxLayer
## Replaces the first child Sprite2D with a grid of the same texture so the background tiles.
## Ensures the parallax background repeats seamlessly when the camera moves.
## Counter-scales with camera zoom so the background is less affected by scroll-wheel zoom.

@export var grid_radius: int = 4  ## Half-size of grid (e.g. 4 = 9x9 tiles)
@export_range(0.0, 1.0) var zoom_compensation: float = 1.0  ## 1 = parallax ignores zoom; 0 = parallax zooms with camera


func _ready() -> void:
	_build_tiled_grid()


func _process(_delta: float) -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
	var inv_zoom: Vector2 = Vector2.ONE / cam.zoom
	var target_scale: Vector2 = inv_zoom.lerp(Vector2.ONE, 1.0 - zoom_compensation)
	# ParallaxLayer's own scale/position can be ignored by the parallax system;
	# apply zoom compensation to each child Sprite2D so it takes effect.
	for child in get_children():
		if child is Sprite2D:
			(child as Sprite2D).scale = target_scale


func _build_tiled_grid() -> void:
	if get_child_count() == 0:
		return
	var child: Node = get_child(0)
	if not child is Sprite2D:
		return
	var sprite: Sprite2D = child as Sprite2D
	var tex: Texture2D = sprite.texture
	if tex == null:
		return
	var sz: Vector2 = tex.get_size()
	if sz.x <= 0 or sz.y <= 0:
		sz = Vector2(1024, 1024)
	remove_child(sprite)
	sprite.queue_free()
	var r: int = grid_radius
	for i in range(-r, r + 1):
		for j in range(-r, r + 1):
			var s: Sprite2D = Sprite2D.new()
			s.texture = tex
			s.position = Vector2(i * sz.x, j * sz.y)
			add_child(s)
