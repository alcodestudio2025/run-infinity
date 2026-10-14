extends Node

var data: SaveData


func _ready() -> void:
	load_data()
	_connect_game_over()


func load_data() -> void:
	var loaded := ServiceLocator.save_service.load_save()
	data = loaded if loaded != null else SaveData.new()


func save_data() -> void:
	if data == null:
		data = SaveData.new()
	ServiceLocator.save_service.save_data(data)


func reset_data() -> void:
	data = SaveData.new()
	save_data()


func get_selected_character_id() -> String:
	if data == null:
		data = SaveData.new()
	return CharacterCatalog.normalize_id(data.selected_character_id)


func set_selected_character_id(character_id: String) -> void:
	if data == null:
		data = SaveData.new()
	data.selected_character_id = CharacterCatalog.normalize_id(character_id)
	save_data()


func _connect_game_over() -> void:
	if EventBus.game_over.is_connected(_on_game_over):
		return
	EventBus.game_over.connect(_on_game_over)


func _on_game_over(final_score: int, distance: float) -> void:
	if data == null:
		data = SaveData.new()

	var changed := false

	data.total_runs += 1
	changed = true

	if distance > 0.0:
		data.total_distance += distance

	if final_score > data.high_score:
		data.high_score = final_score

	if changed:
		save_data()
