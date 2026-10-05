extends Control
class_name StartScreen

const GAME_SCENE_PATH: String = "res://scenes/world.tscn"

@onready var start_button: Button = $StartButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)

func _on_start_pressed() -> void:
	var change_error: Error = get_tree().change_scene_to_file(GAME_SCENE_PATH)
	if change_error != OK:
		push_error("Unable to start game scene %s (error %d)" % [GAME_SCENE_PATH, change_error])
