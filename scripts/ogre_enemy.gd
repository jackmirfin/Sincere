extends CharacterBody2D
class_name OgreEnemy

enum OgreState { IDLE, NOTICE, CHASE, WINDUP, ATTACK, RECOVERY, HURT, DEAD }

const ATTACK_INDICATOR_SCENE: PackedScene = preload("res://scenes/attackindicator.tscn")
const ENEMY_HURT_SOUND: AudioStream = preload("res://assets/sounds/enemyhurt.mp3")
const ATTACK_SOUND: AudioStream = preload("res://assets/sounds/bang.mp3")
const ATTACK_WOOSH_PITCH: float = 0.85
const GRAVITY: float = 1250.0
const ATTACK_HIT_FRAMES: Array[int] = [4, 8, 12, 16, 20]
const ATTACK_TURNAROUND_FRAME: int = 15
const ATTACK_HITBOX_OFFSET: Vector2 = Vector2(38.0, -18.0)
const OGRE_DESATURATION: float = 0.10
const OGRE_OVERLAY_COLOR: Color = Color(0.20, 0.28, 0.36, 1.0)
const OGRE_OVERLAY_STRENGTH: float = 0.10
const OGRE_BRIGHTNESS: float = 1.0
const OGRE_VISIBILITY: float = 1.0
const ENEMY_SCENE_TINT_SHADER: Shader = preload("res://shaders/enemy_scene_tint.gdshader")

@export var max_health: int = 60
@export var detection_range: float = 1500.0
@export var move_speed: float = 720.0
@export var attack_windup_duration: float = 0.42
@export var attack_range: float = 70.0
@export var attack_cooldown: float = 0.75
@export var recovery_duration: float = 0.45
@export var hitstun_duration: float = 0.32
@export var knockback_force: float = 90.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var weapon_hitbox: Area2D = $WeaponHitbox
@onready var weapon_shape: CollisionShape2D = $WeaponHitbox/CollisionShape2D

var state: OgreState = OgreState.IDLE
var state_time: float = 0.0
var cooldown_time: float = 0.0
var hitstun_time: float = 0.0
var health: int = 0
var facing: int = 1
var dead: bool = false
var attack_indicator_hit: bool = false
var attack_hit_count: int = 0
var attack_hit_frames_seen: Array[int] = []
var attack_turned_around: bool = false
var struck_attack_ids: Dictionary = {}
var hit_effect_index: int = 0
var player: CharacterBody2D = null
var hurt_audio: AudioStreamPlayer2D = null
var attack_audio: AudioStreamPlayer2D = null
var attack_woosh_audio: AudioStreamPlayer2D = null
var charge_indicator: AttackIndicator = null

func _ready() -> void:
	add_to_group("enemy")
	health = max_health
	var muted_tint: ShaderMaterial = ShaderMaterial.new()
	muted_tint.shader = ENEMY_SCENE_TINT_SHADER
	muted_tint.set_shader_parameter("desaturation", OGRE_DESATURATION)
	muted_tint.set_shader_parameter("overlay_color", OGRE_OVERLAY_COLOR)
	muted_tint.set_shader_parameter("overlay_strength", OGRE_OVERLAY_STRENGTH)
	muted_tint.set_shader_parameter("brightness", OGRE_BRIGHTNESS)
	animated_sprite.material = muted_tint
	animated_sprite.modulate.a = OGRE_VISIBILITY
	collision_layer = 8
	collision_mask = 1
	floor_snap_length = 4.0
	weapon_shape.disabled = true
	weapon_hitbox.monitoring = false
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	animated_sprite.frame_changed.connect(_on_frame_changed)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	hurt_audio = AudioStreamPlayer2D.new()
	hurt_audio.stream = ENEMY_HURT_SOUND
	hurt_audio.volume_db = 4.0
	hurt_audio.pitch_scale = 1.02
	add_child(hurt_audio)
	attack_audio = AudioStreamPlayer2D.new()
	attack_audio.name = "AttackBangSound"
	attack_audio.stream = ATTACK_SOUND
	attack_audio.volume_db = -8.0
	add_child(attack_audio)
	attack_woosh_audio = EnemyAttackAudio.create_player(self, ATTACK_WOOSH_PITCH)
	_set_animation(&"idle", true)

func _physics_process(delta: float) -> void:
	state_time += delta
	cooldown_time = maxf(0.0, cooldown_time - delta)
	if dead:
		return
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D

	if state == OgreState.HURT:
		hitstun_time = maxf(0.0, hitstun_time - delta)
		velocity.x = move_toward(velocity.x, 0.0, 720.0 * delta)
		_apply_gravity(delta)
		move_and_slide()
		if hitstun_time <= 0.0:
			_change_state(OgreState.CHASE if _can_spot_player() else OgreState.IDLE)
		return

	if state == OgreState.ATTACK:
		velocity.x = 0.0
		_apply_gravity(delta)
		move_and_slide()
		return

	if state == OgreState.WINDUP:
		velocity.x = 0.0
		_apply_gravity(delta)
		move_and_slide()
		if state_time >= attack_windup_duration:
			_change_state(OgreState.ATTACK)
		return

	if state == OgreState.RECOVERY:
		velocity.x = 0.0
		_apply_gravity(delta)
		move_and_slide()
		if state_time >= recovery_duration:
			_change_state(OgreState.CHASE if _can_spot_player() else OgreState.IDLE)
		return

	if player == null:
		_change_state(OgreState.IDLE)
		velocity.x = 0.0
		_apply_gravity(delta)
		move_and_slide()
		return

	var offset: Vector2 = player.global_position - global_position
	var distance: float = offset.length()
	if state == OgreState.IDLE:
		if distance <= detection_range and _can_see_player():
			facing = 1 if offset.x >= 0.0 else -1
			animated_sprite.flip_h = facing < 0
			_change_state(OgreState.NOTICE)
	elif state == OgreState.NOTICE:
		if distance > detection_range or not _can_see_player():
			_change_state(OgreState.IDLE)
	elif state == OgreState.CHASE:
		if distance > detection_range or not _can_see_player():
			velocity.x = 0.0
			_change_state(OgreState.IDLE)
		elif absf(offset.x) <= attack_range and absf(offset.y) <= 48.0:
			facing = 1 if offset.x >= 0.0 else -1
			animated_sprite.flip_h = facing < 0
			velocity.x = 0.0
			_change_state(OgreState.WINDUP)
		else:
			facing = 1 if offset.x >= 0.0 else -1
			animated_sprite.flip_h = facing < 0
			velocity.x = facing * move_speed
			_set_animation(&"run")
	_apply_gravity(delta)
	move_and_slide()

func _change_state(next_state: OgreState) -> void:
	if state == next_state:
		return
	state = next_state
	state_time = 0.0
	_set_weapon_active(false)
	if next_state in [OgreState.IDLE, OgreState.RECOVERY, OgreState.HURT, OgreState.DEAD]:
		_clear_charge_indicator()
	match next_state:
		OgreState.IDLE:
			_set_animation(&"idle")
		OgreState.NOTICE:
			attack_indicator_hit = false
			velocity.x = 0.0
			_set_animation(&"notice", true)
			_spawn_attack_indicator()
		OgreState.CHASE:
			_set_animation(&"run")
		OgreState.WINDUP:
			velocity.x = 0.0
			if not is_instance_valid(charge_indicator):
				_spawn_attack_indicator()
			_set_animation(&"notice", true)
		OgreState.ATTACK:
			animated_sprite.flip_h = facing < 0
			attack_woosh_audio.play()
			if not is_instance_valid(charge_indicator):
				_spawn_attack_indicator()
			attack_hit_count = 0
			attack_hit_frames_seen.clear()
			attack_turned_around = false
			struck_attack_ids.clear()
			_set_animation(&"attack", true)
		OgreState.RECOVERY:
			_set_animation(&"idle")
		OgreState.HURT:
			hitstun_time = hitstun_duration
			_set_animation(&"idle", true)
		OgreState.DEAD:
			dead = true
			velocity = Vector2.ZERO
			hurtbox.set_deferred("monitoring", false)
			body_collision.set_deferred("disabled", true)
			collision_layer = 0
			collision_mask = 0
			_set_animation(&"death", true)
			_spawn_coin_drop()

func can_hit_player() -> bool:
	return state == OgreState.ATTACK and ATTACK_HIT_FRAMES.has(animated_sprite.frame)

func _on_frame_changed() -> void:
	if state != OgreState.ATTACK:
		return
	var current_frame: int = animated_sprite.frame
	if not attack_turned_around and current_frame >= ATTACK_TURNAROUND_FRAME:
		attack_turned_around = true
		facing = -facing
		animated_sprite.flip_h = facing < 0
	if ATTACK_HIT_FRAMES.has(current_frame):
		if not attack_hit_frames_seen.has(current_frame):
			attack_hit_frames_seen.append(current_frame)
			attack_hit_count += 1
			if attack_audio != null:
				attack_audio.play()
		_set_weapon_active(true)
	else:
		_set_weapon_active(false)

func _on_animation_finished() -> void:
	if state == OgreState.NOTICE:
		_change_state(OgreState.CHASE)
	elif state == OgreState.ATTACK:
		_set_weapon_active(false)
		cooldown_time = attack_cooldown
		_change_state(OgreState.RECOVERY)
	elif state == OgreState.DEAD:
		animated_sprite.pause()

func _spawn_attack_indicator() -> void:
	_clear_charge_indicator()
	charge_indicator = ATTACK_INDICATOR_SCENE.instantiate() as AttackIndicator
	charge_indicator.position = Vector2(0.0, -88.0)
	charge_indicator.scale = Vector2(1.5, 1.5)
	charge_indicator.speed_scale = 2.0
	charge_indicator.loop_until_removed = true
	add_child(charge_indicator)

func _clear_charge_indicator() -> void:
	if is_instance_valid(charge_indicator):
		charge_indicator.queue_free()
	charge_indicator = null

func attack_indicator_frame_reached() -> void:
	if not dead:
		attack_indicator_hit = true

func _set_weapon_active(active: bool) -> void:
	weapon_shape.set_deferred("disabled", not active)
	weapon_hitbox.set_deferred("monitoring", active)
	weapon_hitbox.position = Vector2(ATTACK_HITBOX_OFFSET.x * facing, ATTACK_HITBOX_OFFSET.y)
	weapon_shape.position = Vector2.ZERO

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if dead or not area.is_in_group("player_attack_hitbox"):
		return
	var attack_id: int = int(area.get_meta("attack_id", -1))
	if attack_id < 0 or struck_attack_ids.has(attack_id):
		return
	struck_attack_ids[attack_id] = true
	var attacker: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var attacker_position: Vector2 = attacker.global_position if attacker != null else global_position
	var attack_level: int = int(attacker.call("get_attack_level")) if attacker != null and attacker.has_method("get_attack_level") else 1
	var damage: int = int(attacker.call("get_attack_damage")) if attacker != null and attacker.has_method("get_attack_damage") else (10 if attack_level <= 1 else 20)
	HitEffect.spawn_hit(get_parent(), global_position + Vector2(0.0, -38.0), attacker_position, hit_effect_index)
	hit_effect_index = posmod(hit_effect_index + 1, 3)
	take_damage(damage, attack_level, signf(global_position.x - attacker_position.x))

func take_damage(amount: int, _attack_level: int = 1, direction: float = 0.0) -> void:
	if dead:
		return
	health -= amount
	if hurt_audio != null:
		hurt_audio.play()
	if state != OgreState.ATTACK:
		velocity.x = direction * knockback_force
	if health <= 0:
		_change_state(OgreState.DEAD)

func stun_from_parry(_duration: float) -> void:
	# Ogre attacks are deliberately not interrupted by damage or parries.
	return

func _spawn_coin_drop() -> void:
	var drop_parent: Node2D = get_parent() as Node2D
	var manager: Node = get_node_or_null("/root/CoinDropManager")
	if drop_parent != null and manager != null and manager.has_method("drop_at"):
		manager.call("drop_at", drop_parent, global_position, {"drop_chance": 1.0, "min_coins": 2, "max_coins": 3, "min_types": 1, "max_types": 2, "value_multiplier": 1.0})

func _can_spot_player() -> bool:
	if player == null or global_position.distance_to(player.global_position) > detection_range:
		return false
	return _can_see_player()

func _can_see_player() -> bool:
	if player == null:
		return false
	var from: Vector2 = global_position + Vector2(0.0, -38.0)
	var to: Vector2 = player.global_position + Vector2(0.0, -28.0)
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, 1)
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0

func _set_animation(animation_name: StringName, restart: bool = false) -> void:
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return
	if restart or animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)
