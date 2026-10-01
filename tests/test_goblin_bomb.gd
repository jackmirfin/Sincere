extends Node
class_name TestGoblinBomb

const BOMB_SCENE: PackedScene = preload("res://scenes/goblinbomb.tscn")


func test_bomb_spawns_warning_indicator_above_it() -> void:
	var bomb: Area2D = BOMB_SCENE.instantiate() as Area2D
	add_child(bomb)
	await get_tree().process_frame
	var indicator: AttackIndicator = null
	for child: Node in bomb.get_children():
		if child is AttackIndicator:
			indicator = child as AttackIndicator
			break
	assert(indicator != null)
	assert(indicator.position.y < 0.0)
	bomb.queue_free()
	await get_tree().process_frame
