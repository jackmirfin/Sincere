extends LevelExit
class_name World1LevelExit

const WORLD_2_SCENE: String = "res://scenes/world_2.tscn"

func _ready() -> void:
	next_scene = WORLD_2_SCENE
	super._ready()
