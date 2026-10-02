extends CharacterBody2D
class_name GoblinEnemy

enum EnemyState { IDLE, CHASE, ATTACK_WINDUP, ATTACK_ACTIVE, ATTACK_RECOVERY, BOMB_RETREAT, HURT, KNOCKBACK, DEATH_FALLING, DEAD }

const BOMB_SCENE: PackedScene = preload("res://scenes/goblinbomb.tscn")
const ATTACK_INDICATOR_SCENE: PackedScene = preload("res://scenes/attackindicator.tscn")
const ENEMY_HURT_SOUND: AudioStream = preload("res://assets/sounds/enemyhurt.mp3")
const GRAVITY: float = 1250.0

@export var max_health: int = 30
@export var move_speed: float = 125.0
@export var detection_range: float = 600.0
@export var attack_range: float = 66.0
@export var bomb_range: float = 105.0
@export var attack_windup: float = 0.30
@export var attack_recovery: float = 0.40
@export var attack_cooldown: float = 0.45
@export var bomb_retreat_time: float = 0.70
@export var bomb_retreat_speed: float = 150.0
@export var enemy_jump_velocity: float = -280.0
@export var enemy_jump_cooldown: float = 0.75

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
var grounded_before_hit: bool = false
var grounded_hit_lock: bool = false
var grounded_hit_y: float = 0.0
var health: int = 0
var facing: int = -1
var melee_attack_index: int = 0
var attack_counter: int = 0
var current_attack: StringName = &"attack"
var bomb_planted: bool = false
var jump_cooldown_time: float = 0.0
var dead: bool = false
var player: CharacterBody2D
var hurt_audio: AudioStreamPlayer2D
var hit_effect_index: int = 0
var struck_attack_ids: Dictionary = {}
var attack_id: int = 0
var attack_impact_reached: bool = false
const MELEE_IMPACT_FRAME: int = 6
const BOMB_RELEASE_FRAME: int = 6

func _ready() -> void:
	hurt_audio = AudioStreamPlayer2D.new()
	hurt_audio.stream = ENEMY_HURT_SOUND
	hurt_audio.volume_db = 4.0
	hurt_audio.pitch_scale = 1.15
	add_child(hurt_audio)
	add_to_group("enemy")
	health = max_health
	floor_snap_length = 4.0
	weapon_shape.disabled = true
	weapon_hitbox.monitoring = false
	animated_sprite.animation_finished.connect(_on_animation_finished)
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	_set_animation(&"idle", true)
	animated_sprite.frame_changed.connect(_on_attack_frame_changed)

func _physics_process(delta: float) -> void:
	state_time += delta
	cooldown_time = maxf(0.0, cooldown_time - delta)
	jump_cooldown_time = maxf(0.0, jump_cooldown_time - delta)
	grounded_before_hit = is_on_floor()
	if state == EnemyState.DEATH_FALLING:
		if grounded_hit_lock:
			global_position.y = grounded_hit_y
			_change_state(EnemyState.DEAD)
			return
		_apply_gravity(delta)
		move_and_slide()
		if is_on_floor():
			_change_state(EnemyState.DEAD)
		return
	if dead:
		return
	if state in [EnemyState.HURT, EnemyState.KNOCKBACK]:
		hitstun_time = maxf(0.0, hitstun_time - delta)
		if grounded_hit_lock:
			global_position.y = grounded_hit_y
			velocity.y = 0.0
		else:
			_apply_gravity(delta)
		move_and_slide()
		if grounded_hit_lock:
			global_position.y = grounded_hit_y
		if hitstun_time <= 0.0:
			grounded_hit_lock = false
			_change_state(EnemyState.CHASE)
		return
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null:
		_change_state(EnemyState.IDLE)
		_apply_gravity(delta)
		move_and_slide()
		return
	if state == EnemyState.ATTACK_WINDUP or state == EnemyState.ATTACK_ACTIVE or state == EnemyState.ATTACK_RECOVERY:
		_process_attack(delta)
		return
	if state == EnemyState.BOMB_RETREAT:
		velocity.x = -facing * bomb_retreat_speed
		_set_animation(&"run")
		if state_time >= bomb_retreat_time:
			_change_state(EnemyState.CHASE)
	else:
		var distance: float = global_position.distance_to(player.global_position)
		if distance > detection_range or not _can_see_player():
			_change_state(EnemyState.IDLE)
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		elif distance <= bomb_range and cooldown_time <= 0.0 and attack_counter % 3 == 2:
			velocity.x = 0.0
			_change_state(EnemyState.ATTACK_WINDUP)
		elif distance <= attack_range and cooldown_time <= 0.0:
			velocity.x = 0.0
			_change_state(EnemyState.ATTACK_WINDUP)
		else:
			_change_state(EnemyState.CHASE)
			facing = 1 if player.global_position.x > global_position.x else -1
			velocity.x = facing * move_speed
			_set_animation(&"run")
	animated_sprite.flip_h = facing < 0
	_try_jump_over_ledge()
	_apply_gravity(delta)
	move_and_slide()

func _process_attack(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = 0.0
	if state == EnemyState.ATTACK_WINDUP and state_time >= attack_windup:
		_change_state(EnemyState.ATTACK_ACTIVE)
	elif state == EnemyState.ATTACK_ACTIVE:
		if current_attack != &"attack3":
			velocity.x = facing * 45.0
		if animated_sprite.frame >= (BOMB_RELEASE_FRAME if current_attack == &"attack3" else MELEE_IMPACT_FRAME) and not attack_impact_reached:
			attack_impact_reached = true
			if current_attack == &"attack3":
				_spawn_bomb()
			else:
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
		EnemyState.IDLE:
			_set_animation(&"idle")
		EnemyState.CHASE:
			_set_animation(&"run")
		EnemyState.ATTACK_WINDUP:
			facing = 1 if player.global_position.x > global_position.x else -1
			if attack_counter % 3 == 2 and global_position.distance_to(player.global_position) <= bomb_range:
				current_attack = &"attack3"
				bomb_planted = false
			else:
				current_attack = &"attack" if melee_attack_index == 0 else &"attack2"
				melee_attack_index = 1 - melee_attack_index
			attack_counter += 1
			_set_animation(current_attack, true)
		EnemyState.ATTACK_ACTIVE:
			_set_animation(current_attack)
		EnemyState.BOMB_RETREAT:
			_set_animation(&"run")
		EnemyState.HURT, EnemyState.KNOCKBACK:
			_set_animation(&"hurt", true)
		EnemyState.DEATH_FALLING:
			dead = true
			_spawn_coin_drop()
			_set_weapon_active(false)
			hurtbox.set_deferred("monitoring", false)
			velocity.y = maxf(velocity.y, 0.0)
			_set_animation(&"death", true)
		EnemyState.DEAD:
			dead = true
			_spawn_coin_drop()
			_set_weapon_active(false)
			hurtbox.set_deferred("monitoring", false)
			body_collision.set_deferred("disabled", true)
			_set_animation(&"death", true)

func _try_jump_over_ledge() -> void:
	if state != EnemyState.CHASE or not is_on_floor() or jump_cooldown_time > 0.0:
		return
	var player_above: bool = player != null and player.global_position.y < global_position.y - 8.0 and absf(player.global_position.x - global_position.x) < 260.0
	if not is_on_wall() and not player_above:
		return
	velocity.y = enemy_jump_velocity
	jump_cooldown_time = enemy_jump_cooldown

func _spawn_bomb() -> void:
	var bomb: GoblinBomb = BOMB_SCENE.instantiate() as GoblinBomb
	bomb.global_position = global_position + Vector2(facing * 18.0, -8.0)
	bomb.horizontal_velocity = facing * 170.0
	bomb.vertical_velocity = -260.0
	get_parent().add_child(bomb)
	bomb_planted = true

func _spawn_coin_drop() -> void:
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

func stun_from_parry(duration: float) -> void:
	if dead:
		return
	hitstun_time = maxf(hitstun_time, duration)
	_change_state(EnemyState.KNOCKBACK)
	_set_animation(&"hurt", true)

func take_damage(amount: int, _attack_level: int = 1, direction: float = 0.0) -> void:
	if dead:
		return
	health -= amount
	if hurt_audio != null:
		hurt_audio.play()
	velocity.x = direction * 70.0
	if is_on_floor() or grounded_before_hit:
		grounded_hit_lock = true
		grounded_hit_y = global_position.y
		velocity.y = 0.0
	hitstun_time = 0.30
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
	HitEffect.spawn_hit(get_parent(), global_position, attacker_position, hit_effect_index)
	hit_effect_index = posmod(hit_effect_index + 1, 3)
	var damage: int = int(attacker.call("get_attack_damage")) if attacker != null and attacker.has_method("get_attack_damage") else (10 if attack_level == 1 else 20)
	take_damage(damage, attack_level, signf(global_position.x - attacker_position.x))

func _on_attack_frame_changed() -> void:
	return

func _spawn_attack_indicator() -> void:
	var indicator: AnimatedSprite2D = ATTACK_INDICATOR_SCENE.instantiate() as AnimatedSprite2D
	indicator.position = Vector2(0, -48)
	indicator.speed_scale = 1.35
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
		velocity.y += GRAVITY * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0

func _on_animation_finished() -> void:
	if state == EnemyState.ATTACK_ACTIVE and current_attack == &"attack3" and not bomb_planted:
		_spawn_bomb()
		_change_state(EnemyState.BOMB_RETREAT)
		return
	if state == EnemyState.DEAD:
		animated_sprite.pause()
