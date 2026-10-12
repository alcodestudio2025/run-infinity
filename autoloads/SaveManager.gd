extends Node

var data: SaveData


func _ready() -> void:
	load_data()


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
