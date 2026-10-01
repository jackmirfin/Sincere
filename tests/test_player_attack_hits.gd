extends Node
class_name TestPlayerAttackHits

const PLAYER_SCENE: PackedScene = preload("res://scenes/knight.tscn")


func test_crouch_attack_gets_fresh_attack_id() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.auto_start = false
	add_child(player)
	await get_tree().process_frame
	player.set_physics_process(false)
	player.call("_change_state", PlayerController.PlayerState.ATTACK1)
	var first_id: int = player.attack_id
	player.call("_change_state", PlayerController.PlayerState.CROUCH_ATTACK)
	assert(player.attack_id == first_id + 1)
	assert(int(player.attack_hitbox.get_meta("attack_id")) == player.attack_id)
	player.queue_free()
	await get_tree().process_frame


func test_new_attack_retriggers_overlapping_hurtbox() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.auto_start = false
	add_child(player)
	var fake_hurt: Area2D = Area2D.new()
	fake_hurt.collision_layer = 8
	fake_hurt.collision_mask = 4
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(140.0, 140.0)
	shape.shape = rect
	fake_hurt.add_child(shape)
	player.add_child(fake_hurt)
	fake_hurt.position = player.attack_hitbox.position
	var hits: Array = [0]
	fake_hurt.area_entered.connect(func(_area: Area2D) -> void: hits[0] += 1)
	player.call("_change_state", PlayerController.PlayerState.ATTACK1)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(player.attack_hitbox.monitoring)
	var baseline: int = hits[0]
	assert(baseline >= 1)
	player.call("_retrigger_attack_overlaps")
	assert(hits[0] > baseline)
	player.queue_free()
	await get_tree().process_frame