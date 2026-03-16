class_name OverlayManager
extends RefCounted
## Helper to create overlay containers with dimmer and positioned content.
## Use from GameScene and SolarSystemView to avoid duplicating overlay layout code.

## Creates a full-screen container with optional dimmer and a centered overlay control.
## Returns the container; caller must add it to overlay_layer and connect overlay signals.
## rect: Vector4(left, top, right, bottom) offsets from center. If full_rect is true, overlay fills the screen and rect is ignored.
## show_dimmer: if false, no background dimming (e.g. colony panel — world stays fully visible).
static func create_overlay_container(dimmer_color: Color, overlay_control: Control, rect: Vector4, full_rect: bool = false, show_dimmer: bool = true) -> Control:
	var container: Control = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.offset_left = 0.0
	container.offset_top = 0.0
	container.offset_right = 0.0
	container.offset_bottom = 0.0
	if show_dimmer:
		var dimmer: ColorRect = ColorRect.new()
		dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
		dimmer.color = dimmer_color
		dimmer.add_to_group("dim_overlay")
		container.add_child(dimmer)
	container.add_child(overlay_control)
	if full_rect:
		overlay_control.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay_control.offset_left = 0.0
		overlay_control.offset_top = 0.0
		overlay_control.offset_right = 0.0
		overlay_control.offset_bottom = 0.0
	else:
		overlay_control.set_anchors_preset(Control.PRESET_CENTER)
		overlay_control.anchor_left = 0.5
		overlay_control.anchor_top = 0.5
		overlay_control.anchor_right = 0.5
		overlay_control.anchor_bottom = 0.5
		overlay_control.offset_left = rect.x
		overlay_control.offset_top = rect.y
		overlay_control.offset_right = rect.z
		overlay_control.offset_bottom = rect.w
	return container
