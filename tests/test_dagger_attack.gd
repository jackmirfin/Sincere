extends Node
class_name TestDaggerAttack

const PLAYER_SCENE: PackedScene = preload("res://scenes/knight.tscn")
const DAGGER_IMPACT_FRAMES: Array[int] = [1, 3, 7]


func test_dagger_attack_hitbox_activates_on_frames_one_three_and_seven() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.auto_start = false
	add_child(player)
	await get_tree().process_frame
	player.set_physics_process(false)
	assert(player.animated_sprite.sprite_frames.has_animation(&"daggerattack"))
	assert(player.animated_sprite.sprite_frames.get_frame_count(&"daggerattack") == 8)
	player.state = PlayerController.PlayerState.DAGGER_ATTACK
	player.facing = -1
	player.animated_sprite.play(&"daggerattack")
	var previous_attack_id: int = player.attack_id
	var impact_count: int = 0
	for frame_index: int in range(8):
		player.animated_sprite.frame = frame_index
		player.call("_sync_collision_shape")
		var expected_active: bool = DAGGER_IMPACT_FRAMES.has(frame_index)
		assert(player.attack_hitbox.monitoring == expected_active, "dagger hitbox should only be active on frame indices 1, 3, and 7")
		if expected_active:
			impact_count += 1
			assert(player.attack_id > previous_attack_id, "each dagger strike should use a fresh attack ID")
			previous_attack_id = player.attack_id
			assert(player.swing_audio.playing, "each dagger strike should play the weapon swoosh")
			assert(is_equal_approx(player.velocity.x, -PlayerController.DAGGER_LUNGE_SPEED), "each dagger hit should lunge forward on that impact frame")
	assert(impact_count == 3)
	player.call("_update_animation")
	assert(is_equal_approx(player.animated_sprite.position.y, PlayerController.SPRITE_DAGGER_Y))
	player.call("_change_state", PlayerController.PlayerState.LOCOMOTION)
	player.call("_sync_collision_shape")
	assert(not player.attack_hitbox.monitoring)
	player.queue_free()
	await get_tree().process_frame


func test_j_input_starts_dagger_attack() -> void:
	assert(InputMap.has_action("dagger_attack"), "dagger_attack input action is missing")
	var events: Array[InputEvent] = InputMap.action_get_events("dagger_attack")
	assert(events.size() == 1)
	var key_event: InputEventKey = events[0] as InputEventKey
	assert(key_event != null)
	assert(key_event.physical_keycode == KEY_J, "dagger attack should be bound to J")

	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.auto_start = false
	add_child(player)
	await get_tree().process_frame
	player.set_physics_process(false)
	Input.action_press("dagger_attack")
	player.call("_read_action_edges")
	Input.action_release("dagger_attack")
	assert(player.state == PlayerController.PlayerState.DAGGER_ATTACK)
	assert(player.animated_sprite.animation == &"daggerattack")
	player.queue_free()
	await get_tree().process_frame


func test_weapon_attack_inputs_wait_for_animation_finish_but_abilities_cancel() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.auto_start = false
	add_child(player)
	await get_tree().process_frame
	player.set_physics_process(false)
	player.call("_change_state", PlayerController.PlayerState.ATTACK1)
	player.state_time = 0.3
	player.animated_sprite.frame = 2
	_press_action(player, "attack")
	assert(player.state == PlayerController.PlayerState.ATTACK1, "a weapon input must not interrupt the current sword animation")
	assert(player.attack_queued, "the sword combo input should wait for the current animation to finish")
	_press_action(player, "spear_attack")
	assert(player.state == PlayerController.PlayerState.ATTACK1, "spear input must not interrupt the current sword animation")
	assert(player.has_queued_weapon_attack and player.queued_weapon_attack == PlayerController.PlayerState.SPEAR_ATTACK)
	_press_action(player, "dagger_attack")
	assert(player.state == PlayerController.PlayerState.ATTACK1, "dagger input must not interrupt the current sword animation")
	assert(player.has_queued_weapon_attack and player.queued_weapon_attack == PlayerController.PlayerState.DAGGER_ATTACK)
	assert(player.animated_sprite.frame == 2, "the current animation should keep its frame while another weapon attack is queued")
	player.call("_on_animation_finished")
	assert(player.state == PlayerController.PlayerState.DAGGER_ATTACK, "the latest queued weapon attack should begin after the sword animation completes")
	assert(player.animated_sprite.animation == &"daggerattack")
	player.animated_sprite.frame = 4
	_press_action(player, "dagger_attack")
	assert(player.state == PlayerController.PlayerState.DAGGER_ATTACK)
	assert(player.animated_sprite.frame == 4, "repeating a weapon input should not restart an active weapon animation")
	assert(player.has_queued_weapon_attack)
	_press_action(player, "dodge")
	assert(player.state in [PlayerController.PlayerState.ROLL, PlayerController.PlayerState.DASH], "a dodge ability should cancel the active weapon animation")
	assert(not player.has_queued_weapon_attack, "cancelling with an ability should clear the queued weapon attack")
	player.queue_free()
	await get_tree().process_frame


func _press_action(player: PlayerController, action_name: String) -> void:
	Input.action_release(action_name)
	Input.action_press(action_name)
	player.call("_read_action_edges")
	Input.action_release(action_name)
