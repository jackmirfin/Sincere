extends CharacterBody2D
class_name SkeletonEnemy

enum EnemyState { IDLE, CHASE, SHIELD, ATTACK_WINDUP, ATTACK_ACTIVE, ATTACK_RECOVERY, HURT, KNOCKBACK, DEAD }

const ENEMY_HURT_SOUND: AudioStream = preload("res://assets/sounds/enemyhurt.mp3")
const SKELETON_SWING_SOUND: AudioStream = preload("res://assets/sounds/skeletonswordswing.mp3")
const SWING_VOLUME_DB: float = -1.94
const ATTACK_INDICATOR_SCENE: PackedScene = preload("res://scenes/attackindicator.tscn")
const SHIELD_IMPACT_SOUND: AudioStream = preload("res://assets/sounds/shieldimpact.mp3")
const GRAVITY: float = 1250.0

@export var max_health: int = 45
@export var move_speed: float = 140.0
@export var jump_velocity: float = -350.0
@export var detection_range: float = 900.0
@export var attack_range: float = 68.0
@export var attack_windup: float = 0.20
@export var attack_active_time: float = 0.14
@export var attack_recovery: float = 0.28
@export var attack_cooldown: float = 0.35
@export var shield_duration: float = 1.7
@export var shield_cooldown: float = 2.8
@export var hitstun_duration: float = 0.30
@export var knockback_force: float = 70.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var weapon_hitbox: Area2D = $WeaponHitbox
@onready var weapon_shape: CollisionShape2D = $WeaponHitbox/CollisionShape2D

var state: EnemyState = EnemyState.IDLE
var attack_indicator_hit: bool = false
var state_time: float = 0.0
var cooldown_time: float = 0.0
var shield_cooldown_time: float = 0.0
var hitstun_time: float = 0.0
var health: int = 0
var facing: int = -1
var attack_index: int = 0
var attack_id: int = 0
var struck_attack_ids: Dictionary = {}
var current_attack: StringName = &"attack"
var dead: bool = false
var coin_drop_generated: bool = false
var player: CharacterBody2D
var hurt_audio: AudioStreamPlayer2D
var swing_audio: AudioStreamPlayer2D
var shield_audio: AudioStreamPlayer2D
var hit_effect_index: int = 0
var attack_impact_reached: bool = false
var attacks_since_shield: int = 0
var passthrough_player: CharacterBody2D
const ATTACK_IMPACT_FRAME: int = 6

func _ready() -> void:
	hurt_audio = AudioStreamPlayer2D.new()
	hurt_audio.stream = ENEMY_HURT_SOUND
	hurt_audio.volume_db = 4.0
	hurt_audio.pitch_scale = 1.17
	add_child(hurt_audio)
	swing_audio = AudioStreamPlayer2D.new()
	swing_audio.name = "SkeletonSwordSwingSound"
	swing_audio.stream = SKELETON_SWING_SOUND
	swing_audio.volume_db = SWING_VOLUME_DB
	add_child(swing_audio)
	shield_audio = AudioStreamPlayer2D.new()
	shield_audio.stream = SHIELD_IMPACT_SOUND
	shield_audio.volume_db = 4.0
	add_child(shield_audio)
	add_to_group("enemy")
	# Skeletons collide with the world, never with character bodies.
	collision_layer = 0
	collision_mask = 1
	health = max_health
	weapon_shape.disabled = true
	weapon_hitbox.monitoring = false
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	_set_animation(&"idle", true)
	animated_sprite.frame_changed.connect(_on_attack_frame_changed)
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player != null:
		_ensure_player_passthrough()

func _physics_process(delta: float) -> void:
	state_time += delta
	cooldown_time = maxf(0.0, cooldown_time - delta)
	shield_cooldown_time = maxf(0.0, shield_cooldown_time - delta)
	if dead:
		return
	if state in [EnemyState.HURT, EnemyState.KNOCKBACK]:
		hitstun_time = maxf(0.0, hitstun_time - delta)
		_apply_gravity(delta)
		move_and_slide()
		if hitstun_time <= 0.0:
			_change_state(EnemyState.CHASE)
		return
	if state == EnemyState.SHIELD:
		_apply_gravity(delta)
		move_and_slide()
		if state_time >= shield_duration:
			shield_cooldown_time = shield_cooldown
			_change_state(EnemyState.CHASE)
		return
	if state in [EnemyState.ATTACK_WINDUP, EnemyState.ATTACK_ACTIVE, EnemyState.ATTACK_RECOVERY]:
		_process_attack(delta)
		return
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null:
		_change_state(EnemyState.IDLE)
		_apply_gravity(delta)
		move_and_slide()
		return
	_ensure_player_passthrough()
	var distance: float = global_position.distance_to(player.global_position)
	var can_see_player: bool = _can_see_player()
	if distance > detection_range or not can_see_player:
		_change_state(EnemyState.IDLE)
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	else:
		var offset: Vector2 = player.global_position - global_position
		var close_enough_to_attack: bool = absf(offset.x) <= attack_range and absf(offset.y) <= 48.0
		if close_enough_to_attack and cooldown_time <= 0.0:
			# Attack first and often. Shield only after every third committed swing.
			if shield_cooldown_time <= 0.0 and attacks_since_shield >= 3:
				attacks_since_shield = 0
				_change_state(EnemyState.SHIELD)
			else:
				attacks_since_shield += 1
				_change_state(EnemyState.ATTACK_WINDUP)
			velocity.x = 0.0
		else:
			_pursue_player(offset)
	animated_sprite.flip_h = facing < 0
	_apply_gravity(delta)
	move_and_slide()

func _ensure_player_passthrough() -> void:
	if player == passthrough_player:
		return
	if is_instance_valid(passthrough_player):
		remove_collision_exception_with(passthrough_player)
		passthrough_player.remove_collision_exception_with(self)
	passthrough_player = player
	if is_instance_valid(passthrough_player):
		add_collision_exception_with(passthrough_player)
		passthrough_player.add_collision_exception_with(self)

func _pursue_player(offset: Vector2) -> void:
	_change_state(EnemyState.CHASE)
	if absf(offset.x) > 4.0:
		facing = 1 if offset.x > 0.0 else -1
	velocity.x = float(facing) * move_speed
	# A visible player above the skeleton remains a valid target. Jump toward
	# upper platforms instead of dropping aggro because of vertical separation.
	if offset.y < -40.0 and is_on_floor():
		velocity.y = jump_velocity
	_set_animation(&"run")

func _process_attack(_delta: float) -> void:
	_apply_gravity(_delta)
	velocity.x = 0.0
	if state == EnemyState.ATTACK_WINDUP and state_time >= attack_windup:
		_change_state(EnemyState.ATTACK_ACTIVE)
	elif state == EnemyState.ATTACK_ACTIVE:
		if animated_sprite.frame >= ATTACK_IMPACT_FRAME and not attack_impact_reached:
			attack_impact_reached = true
			_set_weapon_active(true)
		if attack_impact_reached and animated_sprite.frame > ATTACK_IMPACT_FRAME:
			_change_state(EnemyState.ATTACK_RECOVERY)
	elif state == EnemyState.ATTACK_RECOVERY and state_time >= attack_recovery:
		cooldown_time = attack_cooldown
		_change_state(EnemyState.CHASE)
	move_and_slide()

func _change_state(next_state: EnemyState) -> void:
	if state == next_state:
		return
	state = next_state
	state_time = 0.0
	if next_state == EnemyState.ATTACK_WINDUP:
		attack_indicator_hit = false
		attack_impact_reached = false
		_spawn_attack_indicator()
	_set_weapon_active(false)
	match next_state:
		EnemyState.IDLE:
			_set_animation(&"idle")
		EnemyState.CHASE:
			_set_animation(&"run")
		EnemyState.SHIELD:
			_set_animation(&"shield", true)
		EnemyState.ATTACK_WINDUP:
			current_attack = &"attack" if attack_index == 0 else &"attack2"
			attack_index = 1 - attack_index
			_set_animation(current_attack, true)
		EnemyState.ATTACK_ACTIVE:
			swing_audio.play()
			_set_animation(current_attack)
		EnemyState.HURT, EnemyState.KNOCKBACK:
			_set_animation(&"hurt", true)
		EnemyState.DEAD:
			dead = true
			_spawn_coin_drop()
			_set_weapon_active(false)
			hurtbox.set_deferred("monitoring", false)
			body_collision.set_deferred("disabled", true)
			_finalize_death_collision_cleanup.call_deferred()
			_set_animation(&"death", true)

func _finalize_death_collision_cleanup() -> void:
	collision_layer = 0
	collision_mask = 0
	body_collision.disabled = true
	hurtbox.monitoring = false
	hurtbox.monitorable = false
	hurtbox.collision_layer = 0
	hurtbox.collision_mask = 0
	weapon_hitbox.monitoring = false
	weapon_hitbox.monitorable = false
	weapon_hitbox.collision_layer = 0
	weapon_hitbox.collision_mask = 0
	weapon_shape.disabled = true
	if is_instance_valid(passthrough_player):
		remove_collision_exception_with(passthrough_player)
		passthrough_player.remove_collision_exception_with(self)
	passthrough_player = null


func stun_from_parry(duration: float) -> void:
	if dead:
		return
	hitstun_time = maxf(hitstun_time, duration)
	_change_state(EnemyState.KNOCKBACK)
	_set_animation(&"hurt", true)

func take_damage(amount: int, _attack_level: int = 1, direction: float = 0.0) -> void:
	if dead:
		return
	if state == EnemyState.SHIELD and not is_zero_approx(direction) and direction == -float(facing):
		return
	health -= amount
	if hurt_audio != null:
		hurt_audio.play()
	velocity.x = direction * knockback_force
	hitstun_time = hitstun_duration
	_change_state(EnemyState.KNOCKBACK)
	_set_animation(&"hurt", true)
	if health <= 0:
		_change_state(EnemyState.DEAD)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if dead or not area.is_in_group("player_attack_hitbox"):
		return
	var attack_key: int = int(area.get_meta("attack_id", -1))
	if attack_key < 0 or struck_attack_ids.has(attack_key):
		return
	struck_attack_ids[attack_key] = true
	var attacker: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var attacker_position: Vector2 = attacker.global_position if attacker != null else global_position
	var attack_level: int = int(attacker.call("get_attack_level")) if attacker != null and attacker.has_method("get_attack_level") else 1
	var direction: float = signf(global_position.x - attacker_position.x)
	var shielded: bool = state == EnemyState.SHIELD and not is_zero_approx(direction) and direction == -float(facing)
	if shielded:
		HitEffect.spawn_shield(get_parent(), global_position, attacker_position)
		shield_audio.play()
		return
	HitEffect.spawn_hit(get_parent(), global_position, attacker_position, hit_effect_index)
	hit_effect_index = posmod(hit_effect_index + 1, 3)
	var damage: int = int(attacker.call("get_attack_damage")) if attacker != null and attacker.has_method("get_attack_damage") else (10 if attack_level == 1 else 20)
	HitEffect.apply_attack_damage(self, attacker, [damage, attack_level, direction])

func _on_attack_frame_changed() -> void:
	return

func _spawn_attack_indicator() -> void:
	var indicator: AnimatedSprite2D = ATTACK_INDICATOR_SCENE.instantiate() as AnimatedSprite2D
	indicator.position = Vector2(0, -42)
	indicator.speed_scale = 1.5
	add_child(indicator)

func attack_indicator_frame_reached() -> void:
	if dead:
		return
	attack_indicator_hit = true

func _set_weapon_active(active: bool) -> void:
	weapon_shape.set_deferred("disabled", not active)
	weapon_hitbox.set_deferred("monitoring", active)
	weapon_hitbox.position.x = 22.0 * facing
	weapon_shape.position.x = absf(weapon_shape.position.x) * float(facing)

func _set_animation(animation_name: StringName, restart: bool = false) -> void:
	if animated_sprite.sprite_frames.has_animation(animation_name) and (restart or animated_sprite.animation != animation_name):
		animated_sprite.play(animation_name)

func _can_see_player() -> bool:
	if player == null:
		return false
	# Cast torso-to-torso. A feet-to-feet ray clips platform lips whenever the
	# player stands on a different level, even when they are plainly visible.
	var ray_start: Vector2 = global_position + Vector2(0.0, -30.0)
	var ray_end: Vector2 = player.global_position + Vector2(0.0, -24.0)
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(ray_start, ray_end, 1)
	query.exclude = [self]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0

func _spawn_coin_drop() -> void:
	if coin_drop_generated:
		return
	coin_drop_generated = true
	if is_in_group("wizard_summon"):
		return
	var manager: Node = get_node_or_null("/root/CoinDropManager")
	if manager != null and manager.has_method("drop_at"):
		manager.call("drop_at", get_parent(), global_position, {"drop_chance": 1.0, "min_coins": 4, "max_coins": 5, "min_types": 1, "max_types": 3, "value_multiplier": 1.0})
