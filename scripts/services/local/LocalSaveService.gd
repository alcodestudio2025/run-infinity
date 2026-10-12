class_name LocalSaveService
extends ISaveService

const SAVE_PATH := "user://save_data.json"


func load_save() -> SaveData:
	if not FileAccess.file_exists(SAVE_PATH):
		return null

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("LocalSaveService: failed to read %s" % SAVE_PATH)
		return null

	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()

	if parse_error != OK or not (json.data is Dictionary):
		push_error("LocalSaveService: invalid JSON in %s" % SAVE_PATH)
		return null

	return SaveData.from_dict(json.data)


func save_data(data: SaveData) -> void:
	if data == null:
		push_error("LocalSaveService: cannot save null SaveData")
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("LocalSaveService: failed to write %s" % SAVE_PATH)
		return

	file.store_string(JSON.stringify(data.to_dict()))
	file.close()


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
