extends Node
class_name TestSpearAttack

const PLAYER_SCENE: PackedScene = preload("res://scenes/knight.tscn")

func test_spear_attack_uses_two_hit_frames() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.auto_start = false
	add_child(player)
	await get_tree().process_frame
	player.set_physics_process(false)
	assert(player.animated_sprite.sprite_frames.get_frame_count(&"spearattack") == 8)
	player.state = PlayerController.PlayerState.SPEAR_ATTACK
	player.animated_sprite.play(&"spearattack")
	player.animated_sprite.frame = 3
	player.call("_sync_collision_shape")
	assert(not player.attack_hitbox.monitoring, "spear must not hit before frame 5")
	player.animated_sprite.frame = 4
	player.call("_sync_collision_shape")
	assert(player.attack_hitbox.monitoring, "spear should hit on frame 5")
	var first_impact_id: int = int(player.attack_hitbox.get_meta("attack_id"))
	player.animated_sprite.frame = 5
	player.call("_sync_collision_shape")
	assert(not player.attack_hitbox.monitoring, "spear hitbox should close between strikes")
	player.animated_sprite.frame = 6
	player.call("_sync_collision_shape")
	assert(player.attack_hitbox.monitoring, "spear should hit on frame 7")
	assert(int(player.attack_hitbox.get_meta("attack_id")) > first_impact_id, "each strike should count as a distinct hit")
	player.animated_sprite.frame = 7
	player.call("_sync_collision_shape")
	assert(not player.attack_hitbox.monitoring, "spear should not hit after frame 7")
	player.queue_free()
	await get_tree().process_frame

func test_l_input_starts_spear_animation() -> void:
	assert(InputMap.has_action("spear_attack"), "spear_attack input action is missing")
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.auto_start = false
	add_child(player)
	await get_tree().process_frame
	player.set_physics_process(false)
	Input.action_press("spear_attack")
	player.call("_read_action_edges")
	Input.action_release("spear_attack")
	assert(player.state == PlayerController.PlayerState.SPEAR_ATTACK)
	assert(player.animated_sprite.animation == &"spearattack")
	player.queue_free()
	await get_tree().process_frame
