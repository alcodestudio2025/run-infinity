class_name CharacterSelectionScreen
extends CanvasLayer

## Title → Character select → Play. Persists choice via SaveManager; no collision logic.

signal character_confirmed(character_id: String)
signal back_pressed

@onready var _subtitle_label: Label = $CenterRoot/Content/SubtitleLabel
@onready var _kai_button: Button = $CenterRoot/Content/Choices/KaiButton
@onready var _nova_button: Button = $CenterRoot/Content/Choices/NovaButton
@onready var _confirm_button: Button = $CenterRoot/Content/ConfirmButton
@onready var _back_button: Button = $CenterRoot/Content/BackButton
@onready var _hint_label: Label = $CenterRoot/Content/HintLabel

var _selected_id: String = CharacterCatalog.DEFAULT_ID


func _ready() -> void:
	layer = maxi(layer, 21)
	if _kai_button != null and not _kai_button.pressed.is_connected(_on_kai_pressed):
		_kai_button.pressed.connect(_on_kai_pressed)
	if _nova_button != null and not _nova_button.pressed.is_connected(_on_nova_pressed):
		_nova_button.pressed.connect(_on_nova_pressed)
	if _confirm_button != null and not _confirm_button.pressed.is_connected(_on_confirm_pressed):
		_confirm_button.pressed.connect(_on_confirm_pressed)
	if _back_button != null and not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)
	_selected_id = _read_saved_character_id()
	_refresh_choice_visuals()
	set_visible_menu(false)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept"):
		_on_confirm_pressed()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_left"):
		_select(CharacterCatalog.ID_KAI)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_right"):
		_select(CharacterCatalog.ID_NOVA)
		get_viewport().set_input_as_handled()


func set_visible_menu(show: bool) -> void:
	visible = show
	if show:
		_selected_id = _read_saved_character_id()
		_refresh_choice_visuals()
		if _confirm_button != null:
			_confirm_button.grab_focus()


func get_selected_character_id() -> String:
	return CharacterCatalog.normalize_id(_selected_id)


func _on_kai_pressed() -> void:
	_select(CharacterCatalog.ID_KAI)


func _on_nova_pressed() -> void:
	_select(CharacterCatalog.ID_NOVA)


func _on_confirm_pressed() -> void:
	if not visible:
		return
	var id: String = CharacterCatalog.normalize_id(_selected_id)
	_write_saved_character_id(id)
	character_confirmed.emit(id)


func _on_back_pressed() -> void:
	if not visible:
		return
	back_pressed.emit()


func _select(character_id: String) -> void:
	_selected_id = CharacterCatalog.normalize_id(character_id)
	_refresh_choice_visuals()


func _refresh_choice_visuals() -> void:
	var kai_def: CharacterDefinition = CharacterCatalog.get_definition(CharacterCatalog.ID_KAI)
	var nova_def: CharacterDefinition = CharacterCatalog.get_definition(CharacterCatalog.ID_NOVA)
	if _kai_button != null:
		_kai_button.text = "%s\n%s" % [kai_def.display_name, kai_def.tagline]
		_kai_button.modulate = (
			Color(1.15, 1.1, 0.85, 1.0)
			if _selected_id == CharacterCatalog.ID_KAI
			else Color(0.75, 0.75, 0.75, 1.0)
		)
	if _nova_button != null:
		_nova_button.text = "%s\n%s" % [nova_def.display_name, nova_def.tagline]
		_nova_button.modulate = (
			Color(1.15, 0.9, 1.1, 1.0)
			if _selected_id == CharacterCatalog.ID_NOVA
			else Color(0.75, 0.75, 0.75, 1.0)
		)
	if _hint_label != null:
		var selected: CharacterDefinition = CharacterCatalog.get_definition(_selected_id)
		_hint_label.text = "Selected: %s — Confirm to play" % selected.display_name
	if _subtitle_label != null:
		_subtitle_label.text = "Choose your runner"


func _read_saved_character_id() -> String:
	var save_manager := _get_save_manager()
	if save_manager != null and save_manager.has_method("get_selected_character_id"):
		return CharacterCatalog.normalize_id(str(save_manager.call("get_selected_character_id")))
	var data = null
	if save_manager != null:
		data = save_manager.get("data")
	if data == null:
		return CharacterCatalog.DEFAULT_ID
	return CharacterCatalog.normalize_id(str(data.get("selected_character_id")))


func _write_saved_character_id(character_id: String) -> void:
	var save_manager := _get_save_manager()
	if save_manager == null:
		return
	if save_manager.has_method("set_selected_character_id"):
		save_manager.call("set_selected_character_id", character_id)
		return
	var data = save_manager.get("data")
	if data == null:
		return
	data.set("selected_character_id", CharacterCatalog.normalize_id(character_id))
	if save_manager.has_method("save_data"):
		save_manager.call("save_data")


func _get_save_manager() -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("SaveManager")
