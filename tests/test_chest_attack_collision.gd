extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/knight.tscn")
const CHEST_SCENE: PackedScene = preload("res://scenes/chest.tscn")

func test_player_attack_opens_a_chest_by_overlap() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	var chest: TreasureChest = CHEST_SCENE.instantiate() as TreasureChest
	add_child(player)
	add_child(chest)
	player.global_position = Vector2(0.0, -4.0)
	chest.global_position = Vector2(24.0, 0.0)
	await get_tree().process_frame
	player.state = PlayerController.PlayerState.ATTACK1
	player.attack_id = 1
	player.attack_hitbox.set_meta("attack_id", player.attack_id)
	for _i: int in range(5):
		await get_tree().physics_frame
	assert(chest.opened, "the player's active attack hitbox did not open the chest")
	assert(chest.animated_sprite.animation == &"opening")
	player.queue_free()
	chest.queue_free()
	await get_tree().process_frame
