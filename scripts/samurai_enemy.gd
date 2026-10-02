extends CharacterBody2D
class_name SamuraiEnemy

const ENEMY_HURT_SOUND: AudioStream = preload("res://assets/sounds/enemyhurt.mp3")
const ATTACK_INDICATOR_SCENE: PackedScene = preload("res://scenes/attackindicator.tscn")

enum EnemyState { IDLE, ALERT, CHASE, ATTACK_WINDUP, ATTACK_ACTIVE, ATTACK_RECOVERY, HURT, KNOCKBACK, DEAD }

@export var max_health: int = 90
@export var approach_speed: float = 115.0
@export var detection_range: float = 600.0
@export var enemy_jump_velocity: float = -280.0
@export var enemy_jump_cooldown: float = 0.75
@export var attack_range: float = 62.0
@export var attack_damage: int = 10
@export var attack_windup: float = 0.30
@export var attack_active_time: float = 0.10
@export var attack_recovery: float = 0.45
@export var attack_cooldown: float = 0.35
@export var attack_knockback: float = 180.0
@export var hitstun_attack_1: float = 0.33
@export var hitstun_attack_2: float = 0.47
@export var attack_1_knockback: float = 45.0
@export var attack_2_knockback: float = 160.0
@export var hit_stop_duration: float = 0.05
@export_group("Coin Drop")
@export var drops_coins: bool = true
@export_range(0.0, 1.0) var drop_chance: float = 1.0
@export var minimum_coins: int = 4
@export var maximum_coins: int = 5
@export var minimum_coin_types: int = 1
@export var maximum_coin_types: int = 3
@export var coin_value_multiplier: float = 1.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var weapon_hitbox: Area2D = $WeaponHitbox
@onready var weapon_shape: CollisionShape2D = $WeaponHitbox/CollisionShape2D

var state: EnemyState = EnemyState.IDLE
var state_time: float = 0.0
var cooldown_time: float = 0.0
var hitstun_time: float = 0.0
var health: int
var facing: int = -1
var dead: bool = false
var swing_id: int = 0
var struck_swing_ids: Dictionary = {}
var player: CharacterBody2D
var hurt_audio: AudioStreamPlayer2D
var hit_effect_index: int = 0
var coin_drop_generated: bool = false
var jump_cooldown_time: float = 0.0
var attack_impact_reached: bool = false
const ATTACK_IMPACT_FRAME: int = 6

func _ready() -> void:
	hurt_audio = AudioStreamPlayer2D.new()
	hurt_audio.stream = ENEMY_HURT_SOUND
	hurt_audio.volume_db = 4.0
	hurt_audio.pitch_scale = 1.15
	add_child(hurt_audio)
	add_to_group("enemy")
	health = max_health
	weapon_shape.disabled = true
	weapon_hitbox.monitoring = false
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)
	if not hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	_set_animation(&"idle", true)
	_validate_animations()

func _physics_process(delta: float) -> void:
	state_time += delta
	cooldown_time = maxf(0.0, cooldown_time - delta)
	jump_cooldown_time = maxf(0.0, jump_cooldown_time - delta)
	if dead:
		return
	if state in [EnemyState.HURT, EnemyState.KNOCKBACK]:
		hitstun_time = maxf(0.0, hitstun_time - delta)
		velocity.y += 1250.0 * delta
		move_and_slide()
		if hitstun_time <= 0.0:
			_change_state(EnemyState.IDLE)
		return
	player = _find_player()
	if player == null:
		_change_state(EnemyState.IDLE)
		_apply_gravity(delta)
		move_and_slide()
		return
	var distance: float = global_position.distance_to(player.global_position)
	if state in [EnemyState.ATTACK_WINDUP, EnemyState.ATTACK_ACTIVE, EnemyState.ATTACK_RECOVERY]:
		_process_attack(delta)
		return
	if distance > detection_range or not _can_see_player():
		_change_state(EnemyState.IDLE)
		velocity.x = move_toward(velocity.x, 0.0, 1000.0 * delta)
	else:
		_change_state(EnemyState.ALERT if distance > attack_range * 1.8 else EnemyState.CHASE)
		if distance > attack_range:
			if _can_step_toward_player():
				facing = 1 if player.global_position.x > global_position.x else -1
				velocity.x = facing * approach_speed
				_set_animation(&"run")
			else:
				velocity.x = 0.0
		else:
			velocity.x = 0.0
			if cooldown_time <= 0.0:
				_change_state(EnemyState.ATTACK_WINDUP)
	_try_jump_over_wall()
	_apply_gravity(delta)
	move_and_slide()

func _try_jump_over_wall() -> void:
	if state not in [EnemyState.CHASE, EnemyState.ALERT] or not is_on_floor() or jump_cooldown_time > 0.0:
		return
	var player_on_ledge: bool = player != null and player.global_position.y < global_position.y - 8.0 and absf(player.global_position.x - global_position.x) < 260.0
	if not is_on_wall() and not player_on_ledge:
		return
	velocity.y = enemy_jump_velocity
	jump_cooldown_time = enemy_jump_cooldown

func _process_attack(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = 0.0
	if state == EnemyState.ATTACK_WINDUP:
		if state_time >= attack_windup:
			_change_state(EnemyState.ATTACK_ACTIVE)
	elif state == EnemyState.ATTACK_ACTIVE:
		if animated_sprite.frame >= ATTACK_IMPACT_FRAME and not attack_impact_reached:
			attack_impact_reached = true
			_set_weapon_active(true)
		if attack_impact_reached and animated_sprite.frame > ATTACK_IMPACT_FRAME:
			_change_state(EnemyState.ATTACK_RECOVERY)
	elif state == EnemyState.ATTACK_RECOVERY:
		if state_time >= attack_recovery:
			cooldown_time = attack_cooldown
			_change_state(EnemyState.CHASE)
	move_and_slide()

func _change_state(next_state: EnemyState) -> void:
	if state == next_state:
		return
	state = next_state
	state_time = 0.0
	if next_state == EnemyState.ATTACK_WINDUP:
		attack_impact_reached = false
		_spawn_attack_indicator()
	_set_weapon_active(false)
	match next_state:
		EnemyState.IDLE, EnemyState.ALERT:
			_set_animation(&"idle")
		EnemyState.CHASE:
			_set_animation(&"run")
		EnemyState.ATTACK_WINDUP:
			swing_id += 1
			struck_swing_ids.clear()
			_set_animation(&"attack", true)
			if player != null:
				facing = 1 if player.global_position.x > global_position.x else -1
		EnemyState.ATTACK_ACTIVE:
			pass
		EnemyState.ATTACK_RECOVERY:
			_set_weapon_active(false)
		EnemyState.HURT:
			_set_weapon_active(false)
			_set_animation(&"hurt", true)
		EnemyState.KNOCKBACK:
			_set_weapon_active(false)
			_set_animation(&"hurt", true)
		EnemyState.DEAD:
			dead = true
			_spawn_coin_drop()
			velocity = Vector2.ZERO
			_set_weapon_active(false)
			hurtbox.set_deferred("monitoring", false)
			body_collision.set_deferred("disabled", true)
			_set_animation(&"hurt", true)

func _on_animation_finished() -> void:
	if state == EnemyState.DEAD:
		animated_sprite.pause()

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if dead or not area.is_in_group("player_attack_hitbox"):
		return
	var attack_id: int = int(area.get_meta("attack_id", -1))
	if attack_id < 0 or struck_swing_ids.has(attack_id):
		return
	struck_swing_ids[attack_id] = true
	var attacker: Node = get_tree().get_first_node_in_group("player")
	var attack_level: int = 1
	if attacker != null and attacker.has_method("get_attack_level"):
		attack_level = attacker.get_attack_level()
	var damage: int = int(attacker.call("get_attack_damage")) if attacker != null and attacker.has_method("get_attack_damage") else (10 if attack_level == 1 else 20)
	var attacker_position: Vector2 = attacker.global_position if attacker != null else global_position
	var direction: float = signf(global_position.x - attacker_position.x)
	HitEffect.spawn_hit(get_parent(), global_position, attacker_position, hit_effect_index)
	hit_effect_index = posmod(hit_effect_index + 1, 3)
	if attacker != null:
		take_damage(damage, attack_level, direction)
		if attacker.has_method("apply_hitstop"):
			attacker.apply_hitstop(hit_stop_duration)

func stun_from_parry(duration: float) -> void:
	if dead:
		return
	hitstun_time = maxf(hitstun_time, duration)
	_change_state(EnemyState.KNOCKBACK)
	_set_animation(&"hurt", true)

func take_damage(amount: int, attack_level: int, direction: float) -> void:
	if dead:
		return
	health -= amount
	if hurt_audio != null:
		hurt_audio.play()
	var duration: float = hitstun_attack_2 if attack_level >= 2 else hitstun_attack_1
	var force: float = attack_2_knockback if attack_level >= 2 else attack_1_knockback
	velocity.x = direction * force
	hitstun_time = duration
	_change_state(EnemyState.KNOCKBACK if attack_level >= 2 else EnemyState.HURT)
	_set_animation(&"hurt", true)
	modulate = Color(1.0, 0.65, 0.65, 1.0)
	get_tree().create_timer(0.06).timeout.connect(_clear_hit_flash, CONNECT_ONE_SHOT)
	if health <= 0:
		_change_state(EnemyState.DEAD)

func apply_hitstop(duration: float) -> void:
	set_physics_process(false)
	get_tree().create_timer(duration).timeout.connect(_resume_after_hitstop, CONNECT_ONE_SHOT)

func _resume_after_hitstop() -> void:
	if is_inside_tree() and not dead:
		set_physics_process(true)

func _clear_hit_flash() -> void:
	if is_inside_tree() and not dead:
		modulate = Color.WHITE

func _spawn_attack_indicator() -> void:
	var indicator: AnimatedSprite2D = ATTACK_INDICATOR_SCENE.instantiate() as AnimatedSprite2D
	indicator.position = Vector2(0, -48)
	indicator.speed_scale = 2.4
	add_child(indicator)

func attack_indicator_frame_reached() -> void:
	if dead:
		return
	# The attack animation frame authoritatively controls impact timing.

func _set_weapon_active(active: bool) -> void:
	weapon_shape.set_deferred("disabled", not active)
	weapon_hitbox.set_deferred("monitoring", active)
	weapon_hitbox.position.x = 30.0 * facing
	weapon_shape.position.x = absf(weapon_shape.position.x) * float(facing)

func _set_animation(animation_name: StringName, restart: bool = false) -> void:
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return
	if restart or animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)

func _can_see_player() -> bool:
	if player == null:
		return false
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, player.global_position, 1)
	query.exclude = [self]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 1250.0 * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0

func _find_player() -> CharacterBody2D:
	return get_tree().get_first_node_in_group("player") as CharacterBody2D

func _can_step_toward_player() -> bool:
	if is_on_wall():
		return false
	return true

func _spawn_coin_drop() -> void:
	if coin_drop_generated or not drops_coins:
		return
	coin_drop_generated = true
	var manager: Node = get_node_or_null("/root/CoinDropManager")
	if manager == null or not manager.has_method("drop_at"):
		return
	var profile: Dictionary = {
		"drop_chance": drop_chance,
		"min_coins": minimum_coins,
		"max_coins": maximum_coins,
		"min_types": minimum_coin_types,
		"max_types": maximum_coin_types,
		"value_multiplier": coin_value_multiplier
	}
	manager.call("drop_at", get_parent(), global_position, profile)

func _validate_animations() -> void:
	for animation_name: StringName in [&"idle", &"run", &"attack", &"hurt"]:
		if not animated_sprite.sprite_frames.has_animation(animation_name):
			push_warning("SamuraiEnemy missing animation: %s" % animation_name)
