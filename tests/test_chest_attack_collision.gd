extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/knight.tscn")
const CHEST_SCENE: PackedScene = preload("res://scenes/chest.tscn")

func test_player_attack_opens_a_chest_and_spawns_original_coin_reward() -> void:
	var world: Node2D = Node2D.new()
	add_child(world)
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.auto_start = false
	var chest: TreasureChest = CHEST_SCENE.instantiate() as TreasureChest
	world.add_child(player)
	world.add_child(chest)
	player.global_position = Vector2(0.0, -4.0)
	chest.global_position = Vector2(24.0, 0.0)
	await get_tree().process_frame
	player.state = PlayerController.PlayerState.ATTACK1
	player.attack_id = 1
	player.attack_hitbox.set_meta("attack_id", player.attack_id)
	for _frame: int in range(5):
		await get_tree().physics_frame
	assert(chest.opened, "the player's active attack hitbox did not open the chest")
	assert(chest.animated_sprite.animation == &"opening")
	for _frame: int in range(60):
		if chest.animated_sprite.animation == &"open":
			break
		await get_tree().physics_frame
	assert(chest.animated_sprite.animation == &"open")
	var spawned_coins: int = 0
	for child: Node in world.get_children():
		if child is CoinPickup:
			spawned_coins += 1
	assert(spawned_coins >= 18 and spawned_coins <= 27, "standard chests should keep their original 18-27 physical coin pickups")
	world.queue_free()
	await get_tree().process_frame
