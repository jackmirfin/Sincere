extends Node
class_name TestSpearAttack

const PLAYER_SCENE: PackedScene = preload("res://scenes/knight.tscn")

func test_spear_attack_uses_three_hit_frames_and_plays_each_swoosh() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.auto_start = false
	add_child(player)
	await get_tree().process_frame
	player.set_physics_process(false)
	assert(player.animated_sprite.sprite_frames.get_frame_count(&"spearattack") >= 9, "spear animation needs nine frames for three impacts")
	player.state = PlayerController.PlayerState.SPEAR_ATTACK
	player.attack_hitbox.set_meta("attack_id", 0)
	player.animated_sprite.play(&"spearattack")
	var prior_attack_id: int = int(player.attack_hitbox.get_meta("attack_id"))
	var first_spear_lunge_speed: float = 0.0
	for frame_index: int in range(9):
		player.animated_sprite.frame = frame_index
		if frame_index in [4, 6]:
			player.velocity.x = 0.0
		player.call("_sync_collision_shape")
		var is_impact_frame: bool = frame_index in [2, 4, 6]
		assert(player.attack_hitbox.monitoring == is_impact_frame, "spear hitbox should only be active on frames 3, 5, and 7")
		if is_impact_frame:
			assert(int(player.attack_hitbox.get_meta("attack_id")) > prior_attack_id, "each spear strike should have a distinct attack ID")
			prior_attack_id = int(player.attack_hitbox.get_meta("attack_id"))
			assert(player.swing_audio.playing, "each spear strike should play the sword swoosh")
			first_spear_lunge_speed = player.velocity.x
			assert(is_equal_approx(first_spear_lunge_speed, PlayerController.SPEAR_LUNGE_SPEED), "every spear impact should apply a forward lunge")
	player.call("_update_animation")
	assert(is_equal_approx(player.animated_sprite.position.y, -16.0), "spear animation should stay aligned with the grounded pose")
	player.call("_change_state", PlayerController.PlayerState.LOCOMOTION)
	player.call("_change_state", PlayerController.PlayerState.SPEAR_ATTACK)
	assert(not player.spear_lunge_applied, "a new spear swing should reset its lunge state")
	player.queue_free()
	await get_tree().process_frame

func test_spear_swing_moves_player_forward_during_the_first_impact() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.auto_start = false
	add_child(player)
	await get_tree().process_frame
	player.call("_change_state", PlayerController.PlayerState.SPEAR_ATTACK)
	player.animated_sprite.frame = 2
	player.call("_sync_collision_shape")
	var start_x: float = player.global_position.x
	for _frame: int in range(3):
		await get_tree().physics_frame
	assert(player.spear_lunge_applied, "one lunge should be applied during the swing")
	assert(player.global_position.x > start_x, "spear lunge did not move x from %f to %f with velocity %f" % [start_x, player.global_position.x, player.velocity.x])
	player.queue_free()
	await get_tree().process_frame

func test_spear_critical_hits_multiple_enemies_at_once() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.auto_start = false
	add_child(player)
	await get_tree().process_frame
	player.set_physics_process(false)
	player.state = PlayerController.PlayerState.SPEAR_ATTACK
	player.attack_hitbox.set_meta("attack_id", 0)
	player.animated_sprite.play(&"spearattack")
	player.animated_sprite.frame = 2
	player.call("_sync_collision_shape")
	assert(player.attack_hitbox.monitoring, "spear hitbox should activate on frame 3")
	assert(player.get_attack_damage() == 7, "a single spear target should receive reduced baseline damage")
	var enemies: Array[CharacterBody2D] = []
	for enemy_index: int in 2:
		var enemy: CharacterBody2D = CharacterBody2D.new()
		enemy.add_to_group("enemy")
		add_child(enemy)
		enemy.global_position = player.attack_hitbox.global_position
		var hurtbox: Area2D = Area2D.new()
		hurtbox.collision_layer = 8
		hurtbox.collision_mask = 0
		enemy.add_child(hurtbox)
		var collision_shape: CollisionShape2D = CollisionShape2D.new()
		var hurt_shape: RectangleShape2D = RectangleShape2D.new()
		hurt_shape.size = Vector2(100.0, 100.0)
		collision_shape.shape = hurt_shape
		hurtbox.add_child(collision_shape)
		enemies.append(enemy)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(player.call("_count_overlapping_attack_enemies") == 2, "spear hitbox should see both enemies simultaneously")
	assert(player.get_attack_damage() == 15, "multi-target spear hits should deal critical damage")
	for enemy: CharacterBody2D in enemies:
		enemy.queue_free()
	player.queue_free()
	await get_tree().process_frame


func test_spear_animation_finishes_before_switching_to_queued_dagger() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.auto_start = false
	add_child(player)
	await get_tree().process_frame
	player.set_physics_process(false)
	player.call("_change_state", PlayerController.PlayerState.SPEAR_ATTACK)
	player.animated_sprite.frame = 4
	Input.action_release("dagger_attack")
	Input.action_press("dagger_attack")
	player.call("_read_action_edges")
	Input.action_release("dagger_attack")
	assert(player.state == PlayerController.PlayerState.SPEAR_ATTACK, "dagger input should not cancel the spear animation")
	assert(player.animated_sprite.frame == 4)
	assert(player.has_queued_weapon_attack and player.queued_weapon_attack == PlayerController.PlayerState.DAGGER_ATTACK)
	player.call("_on_animation_finished")
	assert(player.state == PlayerController.PlayerState.DAGGER_ATTACK, "queued dagger attack should start after spear finishes")
	assert(player.animated_sprite.animation == &"daggerattack")
	player.queue_free()
	await get_tree().process_frame

func test_l_input_starts_spear_attack_in_air() -> void:
	assert(InputMap.has_action("spear_attack"), "spear_attack input action is missing")
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.auto_start = false
	add_child(player)
	await get_tree().process_frame
	player.set_physics_process(false)
	Input.action_press("spear_attack")
	player.call("_read_action_edges")
	Input.action_release("spear_attack")
	assert(player.state == PlayerController.PlayerState.SPEAR_ATTACK, "spear attack should also start while airborne")
	assert(player.animated_sprite.animation == &"spearattack", "airborne spear input should play the spear animation")
	player.queue_free()
	await get_tree().process_frame
