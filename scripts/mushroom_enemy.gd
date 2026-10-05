extends CharacterBody2D
class_name MushroomEnemy

enum EnemyState { IDLE, ALERT, CHASE, ATTACK_WINDUP, ATTACK_ACTIVE, ATTACK_RECOVERY, HURT, KNOCKBACK, DEAD }

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/mushroomprojectile.tscn")
const ATTACK_INDICATOR_SCENE: PackedScene = preload("res://scenes/attackindicator.tscn")
const ENEMY_HURT_SOUND: AudioStream = preload("res://assets/sounds/enemyhurt.mp3")

@export var max_health: int = 3
@export var move_speed: float = 108.0
@export var detection_range: float = 600.0
@export var enemy_jump_velocity: float = -280.0
@export var enemy_jump_cooldown: float = 0.75
@export var melee_range: float = 60.0
@export var projectile_range: float = 155.0
@export var melee_windup: float = 0.55
@export var melee_active_time: float = 0.12
@export var melee_recovery: float = 0.38
@export var projectile_windup: float = 0.40
@export var projectile_recovery: float = 0.40
@export var attack_cooldown: float = 0.45
@export var hitstun_duration: float = 0.33
@export var knockback_force: float = 65.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var weapon_hitbox: Area2D = $WeaponHitbox
@onready var weapon_shape: CollisionShape2D = $WeaponHitbox/CollisionShape2D

var state: EnemyState = EnemyState.IDLE
var attack_indicator_hit: bool = false
var state_time: float = 0.0
var cooldown_time: float = 0.0
var hitstun_time: float = 0.0
var health: int
var facing: int = -1
var melee_attack_index: int = 0
var melee_hit_targets: Dictionary = {}
var projectile_spawned: bool = false
var dead: bool = false
var coin_drop_generated: bool = false
var player: CharacterBody2D
var hurt_audio: AudioStreamPlayer2D
var attack_woosh_audio: AudioStreamPlayer2D
var hit_effect_index: int = 0
var jump_cooldown_time: float = 0.0
var attack_impact_reached: bool = false
const MELEE_IMPACT_FRAME: int = 6
const ATTACK_WOOSH_PITCH: float = 1.05
const PROJECTILE_RELEASE_FRAME: int = 6

func _ready() -> void:
	hurt_audio = AudioStreamPlayer2D.new()
	hurt_audio.stream = ENEMY_HURT_SOUND
	hurt_audio.volume_db = 4.0
	hurt_audio.pitch_scale = 1.17
	add_child(hurt_audio)
	attack_woosh_audio = EnemyAttackAudio.create_player(self, ATTACK_WOOSH_PITCH)
	add_to_group("enemy")
	health = max_health
	weapon_shape.disabled = true
	weapon_hitbox.monitoring = false
	animated_sprite.animation_finished.connect(_on_animation_finished)
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	_set_animation(&"idle", true)
	animated_sprite.frame_changed.connect(_on_attack_frame_changed)
	_validate_animations()

func _physics_process(delta: float) -> void:
	state_time += delta
	cooldown_time = maxf(0.0, cooldown_time - delta)
	jump_cooldown_time = maxf(0.0, jump_cooldown_time - delta)
	if dead:
		return
	if state in [EnemyState.HURT, EnemyState.KNOCKBACK]:
		hitstun_time = maxf(0.0, hitstun_time - delta)
		_apply_gravity(delta)
		move_and_slide()
		if hitstun_time <= 0.0:
			_change_state(EnemyState.IDLE)
		return
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D
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
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	elif distance <= melee_range:
		velocity.x = 0.0
		_change_state(EnemyState.ALERT)
		if cooldown_time <= 0.0:
			_change_state(EnemyState.ATTACK_WINDUP)
	else:
		_change_state(EnemyState.CHASE)
		facing = 1 if player.global_position.x > global_position.x else -1
		velocity.x = facing * move_speed
		_set_animation(&"run")
	animated_sprite.flip_h = facing < 0
	_try_jump_over_wall()
	_apply_gravity(delta)
	move_and_slide()

func _try_jump_over_wall() -> void:
	if state != EnemyState.CHASE or not is_on_floor() or jump_cooldown_time > 0.0:
		return
	var player_on_ledge: bool = player != null and player.global_position.y < global_position.y - 8.0 and absf(player.global_position.x - global_position.x) < 260.0
	if not is_on_wall() and not player_on_ledge:
		return
	velocity.y = enemy_jump_velocity
	jump_cooldown_time = enemy_jump_cooldown

func _process_attack(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = 0.0
	var projectile_attack: bool = animated_sprite.animation == &"attack3"
	var windup: float = projectile_windup if projectile_attack else melee_windup
	var recovery: float = projectile_recovery if projectile_attack else melee_recovery
	if state == EnemyState.ATTACK_WINDUP and state_time >= windup:
		_change_state(EnemyState.ATTACK_ACTIVE)
	elif state == EnemyState.ATTACK_ACTIVE:
		if not projectile_attack:
			velocity.x = facing * 45.0
		var impact_frame: int = PROJECTILE_RELEASE_FRAME if projectile_attack else MELEE_IMPACT_FRAME
		if animated_sprite.frame >= impact_frame and not attack_impact_reached:
			attack_impact_reached = true
			if projectile_attack:
				_spawn_projectile()
			else:
				_set_weapon_active(true)
		if attack_impact_reached and animated_sprite.frame > impact_frame:
			_change_state(EnemyState.ATTACK_RECOVERY)
	elif state == EnemyState.ATTACK_RECOVERY and state_time >= recovery:
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
	animated_sprite.flip_h = facing < 0
	_set_weapon_active(false)
	match next_state:
		EnemyState.IDLE, EnemyState.ALERT:
			_set_animation(&"idle")
		EnemyState.CHASE:
			_set_animation(&"run")
		EnemyState.ATTACK_WINDUP:
			projectile_spawned = false
			melee_hit_targets.clear()
			if player != null:
				facing = 1 if player.global_position.x > global_position.x else -1
			if absf(global_position.x - (player.global_position.x if player != null else global_position.x)) > projectile_range:
				_set_animation(&"attack3", true)
			else:
				_set_animation(&"attack" if melee_attack_index == 0 else &"attack2", true)
				melee_attack_index = 1 - melee_attack_index
		EnemyState.ATTACK_ACTIVE:
			attack_woosh_audio.play()
		EnemyState.ATTACK_RECOVERY:
			_set_weapon_active(false)
		EnemyState.HURT, EnemyState.KNOCKBACK:
			_set_animation(&"hurt", true)
		EnemyState.DEAD:
			dead = true
			_spawn_coin_drop()
			velocity = Vector2.ZERO
			_set_weapon_active(false)
			hurtbox.set_deferred("monitoring", false)
			body_collision.set_deferred("disabled", true)
			_set_animation(&"death", true)

func _on_animation_finished() -> void:
	if state == EnemyState.DEAD:
		animated_sprite.pause()

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if dead or not area.is_in_group("player_attack_hitbox"):
		return
	var attack_id: int = int(area.get_meta("attack_id", -1))
	if attack_id < 0 or melee_hit_targets.has(attack_id):
		return
	melee_hit_targets[attack_id] = true
	var attacker: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var attacker_position: Vector2 = attacker.global_position if attacker != null else global_position
	var direction: float = signf(global_position.x - attacker_position.x)
	HitEffect.spawn_hit(get_parent(), global_position, attacker_position, hit_effect_index)
	hit_effect_index = posmod(hit_effect_index + 1, 3)
	HitEffect.apply_attack_damage(self, attacker, [1, direction], false)
	if attacker != null and attacker.has_method("apply_hitstop"):
		attacker.apply_hitstop(0.05)

func stun_from_parry(duration: float) -> void:
	if dead:
		return
	hitstun_time = maxf(hitstun_time, duration)
	_change_state(EnemyState.KNOCKBACK)
	_set_animation(&"hurt", true)

func take_damage(amount: int, direction_or_level: float = 0.0, optional_direction: float = 0.0) -> void:
	if dead:
		return
	var direction: float = optional_direction if not is_zero_approx(optional_direction) else direction_or_level
	health -= amount
	if hurt_audio != null:
		hurt_audio.play()
	velocity.x = direction * knockback_force
	hitstun_time = hitstun_duration
	_change_state(EnemyState.KNOCKBACK)
	_set_animation(&"hurt", true)
	modulate = Color(1.0, 0.65, 0.65, 1.0)
	get_tree().create_timer(0.06).timeout.connect(_clear_flash, CONNECT_ONE_SHOT)
	if health <= 0:
		_change_state(EnemyState.DEAD)

func _spawn_projectile() -> void:
	projectile_spawned = true
	var projectile: MushroomProjectile = PROJECTILE_SCENE.instantiate() as MushroomProjectile
	get_parent().add_child(projectile)
	projectile.global_position = global_position + Vector2(facing * 24.0, -22.0)
	projectile.set_direction(Vector2(facing, 0.0))

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
	# The attack animation frame, rather than the warning marker, authoritatively controls impact timing.

func _set_weapon_active(active: bool) -> void:
	weapon_shape.set_deferred("disabled", not active)
	weapon_hitbox.set_deferred("monitoring", active)
	weapon_hitbox.position.x = 20.0 * facing
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

func _clear_flash() -> void:
	if is_inside_tree() and not dead:
		modulate = Color.WHITE

func _spawn_coin_drop() -> void:
	if coin_drop_generated:
		return
	coin_drop_generated = true
	if is_in_group("wizard_summon"):
		return
	var manager: Node = get_node_or_null("/root/CoinDropManager")
	if manager == null or not manager.has_method("drop_at"):
		return
	var profile: Dictionary = {
		"drop_chance": 1.0,
		"min_coins": 4,
		"max_coins": 5,
		"min_types": 1,
		"max_types": 3,
		"value_multiplier": 1.0
	}
	manager.call("drop_at", get_parent(), global_position, profile)

func _validate_animations() -> void:
	for animation_name: StringName in [&"idle", &"run", &"attack", &"attack2", &"attack3", &"hurt", &"death"]:
		if not animated_sprite.sprite_frames.has_animation(animation_name):
			push_warning("MushroomEnemy missing animation: %s" % animation_name)
