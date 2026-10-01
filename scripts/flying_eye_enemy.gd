extends CharacterBody2D
class_name FlyingEyeEnemy

enum EnemyState { IDLE, CHASE, ATTACK_WINDUP, ATTACK_ACTIVE, ATTACK_RECOVERY, DEATH_FALLING, DEAD, HURT }

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/flyingeyeprojectile.tscn")
const ATTACK_INDICATOR_SCENE: PackedScene = preload("res://scenes/attackindicator.tscn")
const ENEMY_HURT_SOUND: AudioStream = preload("res://assets/sounds/enemyhurt.mp3")
const GRAVITY: float = 1250.0

@export var max_health: int = 30
@export var move_speed: float = 110.0
@export var detection_range: float = 14.0 * 16.0
@export var preferred_distance: float = 135.0
@export var melee_range: float = 45.0
@export var player_top_offset: float = -36.0
@export var melee_alignment_tolerance: float = 14.0
@export var projectile_range: float = 300.0
@export var attack_windup: float = 0.32
@export var attack_recovery: float = 0.42
@export var attack_cooldown: float = 0.65
@export var hitstun_duration: float = 0.22
@export var projectile_speed: float = 210.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var weapon_hitbox: Area2D = $WeaponHitbox
@onready var weapon_shape: CollisionShape2D = $WeaponHitbox/CollisionShape2D

var state: EnemyState = EnemyState.IDLE
var attack_indicator_hit: bool = false
var state_time: float = 0.0
var cooldown_time: float = 0.0
var health: int = 0
var facing: int = -1
var melee_attack_index: int = 0
var attack_counter: int = 0
var current_attack: StringName = &"attack"
var player: CharacterBody2D
var dead: bool = false
var hurt_audio: AudioStreamPlayer2D
var hit_effect_index: int = 0
var coin_drop_generated: bool = false
var attack_id: int = 0
var struck_attack_ids: Dictionary = {}
var attack_impact_reached: bool = false
const MELEE_IMPACT_FRAME: int = 5

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
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	_set_animation(&"flight", true)
	animated_sprite.frame_changed.connect(_on_attack_frame_changed)

func _physics_process(delta: float) -> void:
	state_time += delta
	cooldown_time = maxf(0.0, cooldown_time - delta)
	if state == EnemyState.DEATH_FALLING:
		velocity.y += GRAVITY * delta
		move_and_slide()
		if is_on_floor():
			state = EnemyState.DEAD
			velocity = Vector2.ZERO
			_set_animation(&"death", true)
		return
	if state == EnemyState.DEAD:
		return
	if state == EnemyState.HURT:
		velocity.y += GRAVITY * delta
		velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
		move_and_slide()
		if state_time >= hitstun_duration:
			_change_state(EnemyState.CHASE)
		return
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null:
		return
	if state in [EnemyState.ATTACK_WINDUP, EnemyState.ATTACK_ACTIVE, EnemyState.ATTACK_RECOVERY]:
		_process_attack(delta)
		return
	var player_side: float = -1.0 if global_position.x < player.global_position.x else 1.0
	var target_position: Vector2 = player.global_position + Vector2(player_side * melee_range, player_top_offset)
	var offset: Vector2 = target_position - global_position
	var distance: float = offset.length()
	if global_position.distance_to(player.global_position) > detection_range:
		_change_state(EnemyState.IDLE)
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * delta * 4.0)
	else:
		_change_state(EnemyState.CHASE)
		facing = 1 if player.global_position.x > global_position.x else -1
		if cooldown_time <= 0.0 and distance <= melee_alignment_tolerance:
			velocity = Vector2.ZERO
			_change_state(EnemyState.ATTACK_WINDUP)
		else:
			var direction: Vector2 = offset.normalized() if not is_zero_approx(distance) else Vector2.ZERO
			velocity = direction * move_speed
			_set_animation(&"flight")
	animated_sprite.flip_h = facing < 0
	move_and_slide()

func _process_attack(_delta: float) -> void:
	velocity = Vector2.ZERO
	if state == EnemyState.ATTACK_WINDUP and state_time >= attack_windup:
		_change_state(EnemyState.ATTACK_ACTIVE)
	elif state == EnemyState.ATTACK_ACTIVE:
		velocity.x = facing * 50.0
		if current_attack == &"attack3":
			_spawn_projectile()
			_change_state(EnemyState.ATTACK_RECOVERY)
		elif animated_sprite.frame >= MELEE_IMPACT_FRAME and not attack_impact_reached:
			attack_impact_reached = true
			_set_weapon_active(true)
		if current_attack != &"attack3" and attack_impact_reached and animated_sprite.frame > MELEE_IMPACT_FRAME:
			_change_state(EnemyState.ATTACK_RECOVERY)
	elif state == EnemyState.ATTACK_RECOVERY and state_time >= attack_recovery:
		_set_weapon_active(false)
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
		EnemyState.IDLE, EnemyState.CHASE:
			_set_animation(&"flight")
		EnemyState.ATTACK_WINDUP:
			attack_id += 1
			struck_attack_ids.clear()
			facing = 1 if player.global_position.x > global_position.x else -1
			current_attack = &"attack2"
			attack_counter += 1
			_set_animation(current_attack, true)
		EnemyState.ATTACK_ACTIVE:
			_set_animation(current_attack)
		EnemyState.HURT:
			_set_animation(&"hurt", true)
		EnemyState.DEATH_FALLING:
			dead = true
			_spawn_coin_drop()
			body_collision.set_deferred("disabled", true)
			hurtbox.set_deferred("monitoring", false)
			_set_animation(&"deathfalling", true)

func _spawn_projectile() -> void:
	var projectile: Node2D = PROJECTILE_SCENE.instantiate() as Node2D
	get_parent().add_child(projectile)
	projectile.global_position = global_position + Vector2(facing * 18.0, 0.0)
	projectile.call("launch", (player.global_position - projectile.global_position).normalized(), projectile_speed)

func take_damage(amount: int, _attack_level: int = 1, direction: float = 0.0) -> void:
	if dead:
		return
	health -= amount
	if hurt_audio != null:
		hurt_audio.play()
	velocity = Vector2(direction * 240.0, -110.0)
	_change_state(EnemyState.HURT)
	_set_animation(&"hurt", true)
	if health <= 0:
		_change_state(EnemyState.DEATH_FALLING)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if dead or not area.is_in_group("player_attack_hitbox"):
		return
	var attack_key: int = int(area.get_meta("attack_id", -1))
	if attack_key < 0 or struck_attack_ids.has(attack_key):
		return
	struck_attack_ids[attack_key] = true
	var attacker: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var attacker_position: Vector2 = attacker.global_position if attacker != null else global_position
	var level: int = int(attacker.call("get_attack_level")) if attacker != null and attacker.has_method("get_attack_level") else 1
	HitEffect.spawn_hit(get_parent(), global_position, attacker_position, hit_effect_index)
	hit_effect_index = posmod(hit_effect_index + 1, 3)
	var damage: int = int(attacker.call("get_attack_damage")) if attacker != null and attacker.has_method("get_attack_damage") else (10 if level == 1 else 20)
	take_damage(damage, level, signf(global_position.x - attacker_position.x))

func _on_attack_frame_changed() -> void:
	return

func _spawn_attack_indicator() -> void:
	var indicator: AnimatedSprite2D = ATTACK_INDICATOR_SCENE.instantiate() as AnimatedSprite2D
	indicator.position = Vector2(0, -48)
	indicator.speed_scale = 1.47
	add_child(indicator)

func attack_indicator_frame_reached() -> void:
	if dead:
		return
	attack_indicator_hit = true

func _set_weapon_active(active: bool) -> void:
	weapon_shape.set_deferred("disabled", not active)
	weapon_hitbox.set_deferred("monitoring", active)
	weapon_hitbox.position.x = 28.0 * facing
	weapon_shape.position.x = absf(weapon_shape.position.x) * float(facing)

func _set_animation(animation_name: StringName, restart: bool = false) -> void:
	if animated_sprite.sprite_frames.has_animation(animation_name) and (restart or animated_sprite.animation != animation_name):
		animated_sprite.play(animation_name)

func _spawn_coin_drop() -> void:
	if coin_drop_generated:
		return
	coin_drop_generated = true
	if is_in_group("wizard_summon"):
		return
	var manager: Node = get_node_or_null("/root/CoinDropManager")
	if manager != null and manager.has_method("drop_at"):
		manager.call("drop_at", get_parent(), global_position, {"drop_chance": 1.0, "min_coins": 4, "max_coins": 5, "min_types": 1, "max_types": 3, "value_multiplier": 1.0})
