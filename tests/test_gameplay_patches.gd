extends Node
class_name TestGameplayPatches

const CAVE_SCENE: PackedScene = preload("res://scenes/cave.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/knight.tscn")
const PAUSE_SCENE: PackedScene = preload("res://scenes/control.tscn")


func test_cave_pause_layer_is_screen_visible() -> void:
	var cave: Node2D = CAVE_SCENE.instantiate() as Node2D
	var pause_layer: CanvasLayer = cave.get_node("PauseLayer") as CanvasLayer
	assert(pause_layer.visible)
	var pause_menu: Control = cave.get_node("PauseLayer/PauseMenu") as Control
	assert(pause_menu.anchor_right == 1.0 and pause_menu.anchor_bottom == 1.0)
	cave.free()


func test_pause_battery_uses_artwork_indicator_position() -> void:
	var menu: PauseMenu = PAUSE_SCENE.instantiate() as PauseMenu
	add_child(menu)
	await get_tree().process_frame
	var empty_bar: ColorRect = menu.get("battery_empty") as ColorRect
	var artwork: TextureRect = menu.get("artwork") as TextureRect
	var source_position: Vector2 = (empty_bar.position - artwork.position) / artwork.scale
	assert(source_position.distance_to(Vector2(53.0 * 320.0 / 85.0, 20.0 * 308.0 / 85.0)) < 1.0)
	menu.queue_free()
	await get_tree().process_frame


func test_pause_battery_uses_health_as_a_fraction_of_maximum() -> void:
	var menu: PauseMenu = PAUSE_SCENE.instantiate() as PauseMenu
	add_child(menu)
	await get_tree().process_frame
	menu.call("_on_player_health_changed", 3, 12)
	assert(is_equal_approx(float(menu.get("battery_ratio")), 0.25))
	menu.queue_free()
	await get_tree().process_frame


func test_charging_socket_restores_health_and_shows_message() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	var socket: ChargingSocket = preload("res://scenes/chargingsocket.tscn").instantiate() as ChargingSocket
	add_child(player)
	add_child(socket)
	await get_tree().process_frame
	player.health = 2
	socket.player = player
	socket.call("_charging_finished")
	assert(player.health == player.max_health)
	assert(socket.has_node("ChargeRestoredMessage"))
	player.queue_free()
	socket.queue_free()
	await get_tree().process_frame


func test_three_quick_kills_grant_and_refresh_speed_boost() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	add_child(player)
	await get_tree().process_frame
	player.register_enemy_kill()
	player.register_enemy_kill()
	assert(not player.is_speed_boost_active())
	player.register_enemy_kill()
	assert(player.is_speed_boost_active())
	assert(is_equal_approx(player.speed_boost_time, 20.0))
	assert(player.get_effective_move_speed() > 202.0)
	assert(player.get_effective_move_speed() <= 202.0 * 1.25)
	player.speed_boost_time = 2.0
	player.register_enemy_kill()
	player.register_enemy_kill()
	player.register_enemy_kill()
	assert(is_equal_approx(player.speed_boost_time, 20.0))
	player.queue_free()
	await get_tree().process_frame


func test_directional_wall_jump_and_wall_entry_lift() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	add_child(player)
	await get_tree().process_frame
	var wall_normal: Vector2 = Vector2.RIGHT
	var away_jump: Vector2 = player.get_wall_jump_velocity(wall_normal, 1.0)
	var scale_jump: Vector2 = player.get_wall_jump_velocity(wall_normal, -1.0)
	assert(away_jump.x > scale_jump.x)
	assert(away_jump.y < scale_jump.y)
	assert(player.should_apply_wall_entry_lift(false, false, -1.0, wall_normal))
	assert(not player.should_apply_wall_entry_lift(true, false, -1.0, wall_normal))
	player.queue_free()
	await get_tree().process_frame


func test_end_gate_spans_boss_exit_and_opens_on_boss_death() -> void:
	var cave: Node2D = CAVE_SCENE.instantiate() as Node2D
	add_child(cave)
	await get_tree().process_frame
	var gate: CaveGate = cave.get_node("rooms_gates/endgate") as CaveGate
	var gate_shape: RectangleShape2D = (gate.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	var half_height: float = gate_shape.size.y * gate.scale.y * 0.5
	assert(gate.position.y - half_height <= 336.0)
	assert(gate.position.y + half_height >= 480.0)
	var boss_controller: BossFightController = cave.get_node("bossfight") as BossFightController
	boss_controller.call("_on_wizard_death_sequence_finished")
	assert(gate.opening or gate.opened)
	cave.queue_free()
	await get_tree().process_frame


func test_boss_intro_camera_tracks_wizard_and_delays_spawns() -> void:
	var cave: Node2D = CAVE_SCENE.instantiate() as Node2D
	add_child(cave)
	await get_tree().process_frame
	var controller: BossFightController = cave.get_node("bossfight") as BossFightController
	assert(controller.enemy_spawn_delay >= 2.0)
	var camera: Camera2D = Camera2D.new()
	cave.add_child(camera)
	controller.cinematic_camera = camera
	controller.cinematic_follow_wizard = true
	controller.wizard.global_position = Vector2(2300.0, 410.0)
	controller.call("_process", 0.016)
	assert(camera.global_position == controller.wizard.global_position + Vector2(0.0, -24.0))
	var player: PlayerController = cave.get_node("knight") as PlayerController
	player.crouched = true
	player.prepare_for_boss_cinematic()
	assert(not player.crouched)
	assert((player.get_node("CollisionShape2D") as CollisionShape2D).shape == preload("res://resources/player_body_shape.tres"))
	controller.enemy_spawn_delay = 0.08
	controller.call("_start_boss_music_and_fight")
	assert(not controller.wizard.encounter_active)
	await get_tree().create_timer(0.2).timeout
	assert(controller.wizard.encounter_active)
	cave.queue_free()
	await get_tree().process_frame


func test_second_phase_teleport_remains_in_camera_range() -> void:
	var cave: Node2D = CAVE_SCENE.instantiate() as Node2D
	var teleport_marker: Node2D = cave.get_node("bossfight/spawns_wizardteleports/wizardteleport") as Node2D
	assert(teleport_marker != null)
	var wizard: CaveEvilWizard = cave.get_node("bossfight/evilwizard") as CaveEvilWizard
	wizard.visible = true
	wizard.animated_sprite = wizard.get_node("AnimatedSprite2D") as AnimatedSprite2D
	wizard.spell_overlay = null
	wizard.teleport_destination = teleport_marker.global_position
	wizard.pending_summon_count = 6
	wizard.state = CaveEvilWizard.WizardState.TELEPORT_OUT
	wizard.call("_complete_teleport_out")
	assert(wizard.visible and wizard.animated_sprite.visible)
	assert(wizard.state == CaveEvilWizard.WizardState.TELEPORT_IN)
	cave.free()
