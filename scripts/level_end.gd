extends Area2D
class_name LevelEnd

@export_file("*.tscn") var next_scene: String = "res://scenes/midworld.tscn"
var changing_scene: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if changing_scene or not body.is_in_group("player"):
		return
	changing_scene = true
	get_tree().call_deferred("change_scene_to_file", next_scene)
