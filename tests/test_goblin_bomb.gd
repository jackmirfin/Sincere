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


func test_exploding_bomb_finishes_its_animation_before_freeing() -> void:
	var bomb: GoblinBomb = BOMB_SCENE.instantiate() as GoblinBomb
	add_child(bomb)
	await get_tree().process_frame
	bomb._explode()
	assert(bomb.exploded)
	assert(not bomb.is_queued_for_deletion())
	assert(bomb.animated_sprite.animation == &"bomb")
	bomb._on_animation_finished()
	assert(bomb.is_queued_for_deletion())
	await get_tree().process_frame
