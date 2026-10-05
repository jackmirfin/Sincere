extends Node
class_name TestAxeAttack

const PLAYER_SCENE: PackedScene = preload("res://scenes/knight.tscn")
const AXE_IMPACT_FRAMES: Array[int] = [1, 4, 8]

func test_axe_attack_hitbox_activates_on_frames_one_four_and_eight() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.auto_start = false
	add_child(player)
	await get_tree().process_frame
	player.set_physics_process(false)
	assert(player.animated_sprite.sprite_frames.has_animation(&"axeattack"), "axe attack animation should be generated from axeattack.png")
	var axe_frame_count: int = player.animated_sprite.sprite_frames.get_frame_count(&"axeattack")
	assert(axe_frame_count >= 9, "axe timeline must include frame 8")
	player.state = PlayerController.PlayerState.AXE_ATTACK
	player.animated_sprite.play(&"axeattack")
	var previous_attack_id: int = player.attack_id
	player.velocity.x = 0.0
	for frame_index: int in range(9):
		player.animated_sprite.frame = frame_index
		if frame_index in [4, 8]:
			player.velocity.x = 0.0
		player.call("_sync_collision_shape")
		var expected_active: bool = AXE_IMPACT_FRAMES.has(frame_index)
		assert(player.attack_hitbox.monitoring == expected_active, "axe hitbox should only activate on indices 1, 4, and 8")
		if frame_index in [4, 8]:
			assert(player.is_attack_critical(), "the second and third axe hits should always be critical")
			assert(player.is_attack_critical_for(null), "axe criticals should apply to every target")
			assert(player.get_attack_damage() == 18, "axe critical hits should deal 18 damage")
		elif expected_active:
			assert(not player.is_attack_critical(), "the first axe hit should not be critical")
			assert(player.get_attack_damage() == 8, "the first axe hit should deal slightly more than the standard 7 damage")
		if expected_active:
			assert(is_equal_approx(player.velocity.x, float(player.facing) * PlayerController.AXE_LUNGE_SPEED), "each axe strike should lunge forward")
			assert(player.attack_id > previous_attack_id, "each axe strike should receive a fresh attack ID")
			previous_attack_id = player.attack_id
			assert(player.swing_audio.playing, "each axe impact should play the weapon swing")
	player.call("_update_animation")
	assert(is_equal_approx(player.animated_sprite.position.y, PlayerController.SPRITE_AXE_Y))
	player.call("_change_state", PlayerController.PlayerState.LOCOMOTION)
	player.call("_sync_collision_shape")
	assert(not player.attack_hitbox.monitoring)
	player.queue_free()
	await get_tree().process_frame

func test_axe_swing_moves_player_forward() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.auto_start = false
	add_child(player)
	await get_tree().process_frame
	player.velocity.x = 0.0
	player.call("_change_state", PlayerController.PlayerState.AXE_ATTACK)
	player.animated_sprite.frame = 1
	player.call("_sync_collision_shape")
	var start_x: float = player.global_position.x
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(player.global_position.x > start_x, "axe lunge should move the player forward")
	player.queue_free()
	await get_tree().process_frame

func test_axe_input_queues_until_the_current_weapon_animation_finishes() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.auto_start = false
	add_child(player)
	await get_tree().process_frame
	player.set_physics_process(false)
	player.call("_change_state", PlayerController.PlayerState.ATTACK1)
	player.state_time = 0.3
	Input.action_release("axe_attack")
	Input.action_press("axe_attack")
	player.call("_read_action_edges")
	Input.action_release("axe_attack")
	assert(player.state == PlayerController.PlayerState.ATTACK1, "axe input should not interrupt the current weapon animation")
	assert(player.has_queued_weapon_attack and player.queued_weapon_attack == PlayerController.PlayerState.AXE_ATTACK)
	player.call("_on_animation_finished")
	assert(player.state == PlayerController.PlayerState.AXE_ATTACK)
	assert(player.animated_sprite.animation == &"axeattack")
	player.queue_free()
	await get_tree().process_frame

func test_o_input_starts_axe_attack() -> void:
	assert(InputMap.has_action("axe_attack"), "axe_attack input action is missing")
	var events: Array[InputEvent] = InputMap.action_get_events("axe_attack")
	assert(events.size() == 1, "axe_attack should have one default binding")
	var key_event: InputEventKey = events[0] as InputEventKey
	assert(key_event != null and key_event.physical_keycode == KEY_O, "axe attack should be bound to O")
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.auto_start = false
	add_child(player)
	await get_tree().process_frame
	player.set_physics_process(false)
	Input.action_release("axe_attack")
	Input.action_press("axe_attack")
	player.call("_read_action_edges")
	Input.action_release("axe_attack")
	assert(player.state == PlayerController.PlayerState.AXE_ATTACK)
	assert(player.animated_sprite.animation == &"axeattack")
	player.queue_free()
	await get_tree().process_frame
