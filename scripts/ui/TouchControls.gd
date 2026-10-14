class_name TouchControls
extends CanvasLayer

## On-screen LEFT SLIDE / RIGHT JUMP controls for landscape play.
## Buttons consume pointer events (mouse_filter STOP) so they do not reach
## TouchGestureRouter. Multitouch-safe: each button is independent.

signal jump_pressed
signal slide_pressed

@onready var _root: Control = $Root
@onready var _slide_button: Button = $Root/SlideButton
@onready var _jump_button: Button = $Root/JumpButton


func _ready() -> void:
	layer = 12
	_style_button(_slide_button, Color(0.15, 0.45, 0.75, 0.35), Color(0.75, 0.9, 1.0, 0.95))
	_style_button(_jump_button, Color(0.75, 0.45, 0.12, 0.35), Color(1.0, 0.92, 0.75, 0.95))
	if _slide_button != null and not _slide_button.button_down.is_connected(_on_slide_down):
		_slide_button.button_down.connect(_on_slide_down)
	if _jump_button != null and not _jump_button.button_down.is_connected(_on_jump_down):
		_jump_button.button_down.connect(_on_jump_down)
	set_controls_visible(false)


func set_controls_visible(show: bool) -> void:
	visible = show
	if _root != null:
		_root.visible = show
	if _slide_button != null:
		_slide_button.disabled = not show
	if _jump_button != null:
		_jump_button.disabled = not show


func _on_slide_down() -> void:
	if not visible:
		return
	slide_pressed.emit()


func _on_jump_down() -> void:
	if not visible:
		return
	jump_pressed.emit()


func _style_button(button: Button, fill: Color, text_color: Color) -> void:
	if button == null:
		return
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	button.add_theme_font_size_override("font_size", 42)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_disabled_color", Color(text_color, 0.35))
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = fill if state != "pressed" else Color(fill.r, fill.g, fill.b, minf(fill.a + 0.2, 0.7))
		if state == "disabled":
			box.bg_color = Color(fill.r, fill.g, fill.b, fill.a * 0.35)
		box.set_corner_radius_all(20)
		box.set_content_margin_all(12)
		button.add_theme_stylebox_override(state, box)
