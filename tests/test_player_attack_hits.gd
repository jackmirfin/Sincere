extends Node
class_name TestPlayerAttackHits

const PLAYER_SCENE: PackedScene = preload("res://scenes/knight.tscn")
const GOBLIN_SCENE: PackedScene = preload("res://scenes/goblin.tscn")


func test_sword_baseline_and_speed_boost_critical_damage() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.auto_start = false
	add_child(player)
	await get_tree().process_frame
	player.set_physics_process(false)
	player.state = PlayerController.PlayerState.ATTACK1
	assert(player.get_attack_damage() == 7, "standard sword damage should be 70% of its old 10 damage")
	player.speed_boost_time = 1.0
	assert(player.get_attack_damage() == 15, "sword should deal 150% damage during a speed boost")
	player.state = PlayerController.PlayerState.ATTACK2
	assert(player.get_attack_damage() == 30, "heavy sword critical should deal 150% of its old 20 damage")
	player.speed_boost_time = 0.0
	assert(player.get_attack_damage() == 14, "heavy sword baseline should be reduced to 70%")
	player.state = PlayerController.PlayerState.ATTACK1
	player.add_attack_damage(5)
	assert(player.get_attack_damage() == 11, "flat upgrades should be included before the baseline reduction")
	player.speed_boost_time = 1.0
	assert(player.get_attack_damage() == 23, "critical damage should scale the upgraded weapon damage too")
	player.queue_free()
	await get_tree().process_frame


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


func test_front_block_reduces_damage_and_knocks_back_attacker() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.auto_start = false
	add_child(player)
	await get_tree().process_frame
	player.set_physics_process(false)
	player.position = Vector2.ZERO
	player.facing = 1
	player.state = PlayerController.PlayerState.BLOCKING
	player.state_time = 1.0
	var attacker: CharacterBody2D = CharacterBody2D.new()
	attacker.position = Vector2(20.0, 0.0)
	add_child(attacker)
	var initial_health: int = player.health
	player.speed_boost_time = 5.0
	player.handle_enemy_attack(attacker, 180.0)
	assert(player.health == initial_health - 1)
	assert(player.speed_boost_time == 0.0, "blocked damage should also cancel an active speed boost")
	assert(player.velocity.x < 0.0)
	assert(attacker.velocity.x > 0.0)
	assert(player.hit_slowdown_active)
	Engine.time_scale = 1.0
	player.hit_slowdown_active = false
	player.hit_slowmo_token += 1
	attacker.queue_free()
	player.queue_free()
	await get_tree().process_frame


func test_front_parry_prevents_damage_and_recoils_attacker() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.auto_start = false
	add_child(player)
	await get_tree().process_frame
	player.set_physics_process(false)
	player.position = Vector2.ZERO
	player.facing = 1
	player.state = PlayerController.PlayerState.PARRY
	player.state_time = 0.1
	var attacker: CharacterBody2D = CharacterBody2D.new()
	attacker.position = Vector2(20.0, 0.0)
	add_child(attacker)
	var initial_health: int = player.health
	player.handle_enemy_attack(attacker, 180.0)
	assert(player.health == initial_health)
	assert(attacker.velocity.x > 0.0)
	player.block_slowmo_token += 1
	player.block_slowmo_active = false
	Engine.time_scale = 1.0
	attacker.queue_free()
	player.queue_free()
	await get_tree().process_frame


func test_parry_stuns_enemy_and_shows_indicator() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	var goblin: GoblinEnemy = GOBLIN_SCENE.instantiate() as GoblinEnemy
	player.auto_start = false
	player.set_physics_process(false)
	goblin.set_physics_process(false)
	player.position = Vector2.ZERO
	goblin.position = Vector2(20.0, 0.0)
	add_child(player)
	add_child(goblin)
	await get_tree().process_frame
	player.facing = 1
	player.state = PlayerController.PlayerState.PARRY
	player.state_time = 0.1
	var initial_health: int = player.health
	player.handle_enemy_attack(goblin, 180.0)
	assert(player.health == initial_health)
	assert(goblin.hitstun_time >= PlayerController.PARRY_STUN_DURATION)
	assert(goblin.state == GoblinEnemy.EnemyState.KNOCKBACK)
	assert(goblin.velocity.x > 0.0)
	assert(goblin.has_node("ParryStunIndicator"))
	player.block_slowmo_token += 1
	player.block_slowmo_active = false
	Engine.time_scale = 1.0
	player.queue_free()
	goblin.queue_free()
	await get_tree().process_frame


func test_player_damage_has_no_hit_invulnerability_and_strong_feedback() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.auto_start = false
	add_child(player)
	await get_tree().process_frame
	player.set_physics_process(false)
	var initial_health: int = player.health
	var boost_states: Array[bool] = []
	player.speed_boost_changed.connect(func(active: bool, _time_remaining: float) -> void: boost_states.append(active))
	player.speed_boost_time = 10.0
	player.receive_hit(false)
	assert(player.health == initial_health - 1)
	assert(is_zero_approx(player.invulnerable_time), "Taking damage should not grant follow-up hit immunity")
	assert(player.speed_boost_time == 0.0, "Taking damage should immediately cancel the speed boost")
	assert(not boost_states.is_empty() and not boost_states.back(), "Cancelling the boost should notify listeners")
	assert(player.hit_slowdown_active)
	assert(is_equal_approx(Engine.time_scale, PlayerController.HIT_SLOWMO_SCALE))
	assert(player.animated_sprite.modulate == PlayerController.HIT_FLASH_COLOR, "Player should flash visibly on hit")
	var before_second_hit_timer: SceneTreeTimer = get_tree().create_timer(0.65, true, false, true)
	await before_second_hit_timer.timeout
	player.receive_hit(false)
	assert(player.health == initial_health - 2, "A second hit should damage the player immediately")
	var refreshed_slowmo_timer: SceneTreeTimer = get_tree().create_timer(0.5, true, false, true)
	await refreshed_slowmo_timer.timeout
	assert(player.hit_slowdown_active, "A later hit should refresh the one-second slow-motion window")
	var slowmo_expiry_timer: SceneTreeTimer = get_tree().create_timer(0.55, true, false, true)
	await slowmo_expiry_timer.timeout
	assert(not player.hit_slowdown_active, "Hit slow motion should end after one second from the latest hit")
	assert(is_equal_approx(Engine.time_scale, 1.0), "Game speed should return to normal when hit slow motion ends")
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