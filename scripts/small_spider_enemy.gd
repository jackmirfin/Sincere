extends CharacterBody2D
class_name SmallSpiderEnemy

enum EnemyState { IDLE, CHASE, ATTACK, RECOVERY, HURT, DEAD }

const GRAVITY: float = 1250.0
const ATTACK_INDICATOR_SCENE: PackedScene = preload("res://scenes/attackindicator.tscn")
const ATTACK_IMPACT_FRAME: int = 4 # Fifth displayed frame (zero-indexed).
const ENEMY_HURT_SOUND: AudioStream = preload("res://assets/sounds/enemyhurt.mp3")
const ATTACK_WOOSH_PITCH: float = 1.60
const SPIDER_DESATURATION: float = 0.15
const SPIDER_OVERLAY_COLOR: Color = Color(0.28, 0.36, 0.52, 1.0)
const SPIDER_OVERLAY_STRENGTH: float = 0.15
const SPIDER_BRIGHTNESS: float = 1.0
const SPIDER_VISIBILITY: float = 1.0
const ENEMY_SCENE_TINT_SHADER: Shader = preload("res://shaders/enemy_scene_tint.gdshader")

@export var max_health: int = 2
@export var move_speed: float = 105.0
@export var detection_range: float = 420.0
@export var attack_range: float = 52.0
@export var jump_velocity: float = -310.0
@export var attack_cooldown: float = 0.8
@export var hitstun_duration: float = 0.24

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var weapon_hitbox: Area2D = $WeaponHitbox
@onready var weapon_shape: CollisionShape2D = $WeaponHitbox/CollisionShape2D

var state: EnemyState = EnemyState.IDLE
var health: int = 0
var dead: bool = false
var facing: int = -1
var state_time: float = 0.0
var cooldown_time: float = 0.0
var hitstun_time: float = 0.0
var attack_impact_reached: bool = false
var attack_leaping: bool = false
var attack_indicator_hit: bool = false
var burst_launch_time: float = 0.0
var struck_attack_ids: Dictionary = {}
var player: CharacterBody2D = null
var hurt_audio: AudioStreamPlayer2D = null
var attack_woosh_audio: AudioStreamPlayer2D = null
var crawler: SpiderSurfaceCrawler = SpiderSurfaceCrawler.new()

func _ready() -> void:
	add_to_group("enemy")
	crawler.configure(self, body_collision, float(facing))
	health = max_health
	collision_layer = 8
	collision_mask = 1
	weapon_shape.disabled = true
	weapon_hitbox.monitoring = false
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	hurt_audio = AudioStreamPlayer2D.new()
	hurt_audio.stream = ENEMY_HURT_SOUND
	hurt_audio.volume_db = 2.0
	hurt_audio.pitch_scale = 1.02
	add_child(hurt_audio)
	attack_woosh_audio = EnemyAttackAudio.create_player(self, ATTACK_WOOSH_PITCH)
	var scene_tint: ShaderMaterial = ShaderMaterial.new()
	scene_tint.shader = ENEMY_SCENE_TINT_SHADER
	scene_tint.set_shader_parameter("desaturation", SPIDER_DESATURATION)
	scene_tint.set_shader_parameter("overlay_color", SPIDER_OVERLAY_COLOR)
	scene_tint.set_shader_parameter("overlay_strength", SPIDER_OVERLAY_STRENGTH)
	scene_tint.set_shader_parameter("brightness", SPIDER_BRIGHTNESS)
	animated_sprite.material = scene_tint
	animated_sprite.modulate.a = SPIDER_VISIBILITY
	_set_animation(&"idle", true)

func _physics_process(delta: float) -> void:
	state_time += delta
	cooldown_time = maxf(0.0, cooldown_time - delta)
	if state == EnemyState.DEAD:
		return
	if burst_launch_time > 0.0:
		burst_launch_time = maxf(0.0, burst_launch_time - delta)
		crawler.prepare_motion(delta, velocity.x, global_position + Vector2(signf(velocity.x), 0.0), true)
		move_and_slide()
		return
	if state == EnemyState.HURT:
		hitstun_time = maxf(0.0, hitstun_time - delta)
		_apply_gravity(delta)
		move_and_slide()
		_after_move()
		if hitstun_time <= 0.0:
			_change_state(EnemyState.IDLE)
		return

	player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if state == EnemyState.ATTACK:
		_process_attack(delta)
		return
	if state == EnemyState.RECOVERY:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		_apply_gravity(delta)
		move_and_slide()
		_after_move()
		if state_time >= 0.28:
			_change_state(EnemyState.CHASE)
		return
	if player == null:
		_change_state(EnemyState.IDLE)
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	else:
		var offset: Vector2 = player.global_position - global_position
		var distance: float = global_position.distance_to(player.global_position)
		if distance > detection_range:
			_change_state(EnemyState.IDLE)
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		elif absf(offset.x) <= attack_range and absf(offset.y) <= 56.0 and cooldown_time <= 0.0 and is_on_floor():
			facing = 1 if offset.x >= 0.0 else -1
			_change_state(EnemyState.ATTACK)
			attack_leaping = true
			var grounded_launch: Vector2 = Vector2(facing * move_speed * 1.25, jump_velocity)
			velocity = crawler.attack_launch_velocity(player.global_position, 340.0, grounded_launch)
		else:
			_change_state(EnemyState.CHASE)
			facing = 1 if offset.x >= 0.0 else -1
			velocity.x = facing * move_speed
			_set_animation(&"move")
	animated_sprite.flip_h = facing < 0
	_apply_gravity(delta)
	move_and_slide()
	_after_move()

func _process_attack(delta: float) -> void:
	if player != null and state_time < 0.20:
		facing = 1 if player.global_position.x >= global_position.x else -1
	animated_sprite.flip_h = facing < 0
	_apply_gravity(delta)
	move_and_slide()
	_after_move()
	if animated_sprite.frame >= ATTACK_IMPACT_FRAME and not attack_impact_reached:
		attack_impact_reached = true
		_set_weapon_active(true)
	elif attack_impact_reached and animated_sprite.frame > ATTACK_IMPACT_FRAME:
		_set_weapon_active(false)
		cooldown_time = attack_cooldown
		_change_state(EnemyState.RECOVERY)

func _change_state(next_state: EnemyState) -> void:
	if state == next_state:
		return
	state = next_state
	state_time = 0.0
	_set_weapon_active(false)
	match next_state:
		EnemyState.IDLE:
			_set_animation(&"idle")
		EnemyState.CHASE:
			_set_animation(&"move")
		EnemyState.ATTACK:
			attack_woosh_audio.play()
			attack_impact_reached = false
			attack_indicator_hit = false
			struck_attack_ids.clear()
			_spawn_attack_indicator()
			_set_animation(&"attack", true)
		EnemyState.RECOVERY:
			_set_animation(&"idle")
		EnemyState.HURT:
			_set_animation(&"idle", true)
		EnemyState.DEAD:
			dead = true
			velocity = Vector2.ZERO
			hurtbox.set_deferred("monitoring", false)
			body_collision.set_deferred("disabled", true)
			_set_animation(&"death", true)
			_spawn_coin_drop()

func take_damage(_amount: int = 1, _attack_level: int = 1, direction: float = 0.0) -> void:
	if dead:
		return
	# Every distinct player strike is one hit, so ordinary attacks take exactly two.
	health -= 1
	if hurt_audio != null:
		hurt_audio.play()
	velocity.x = direction * 90.0
	hitstun_time = hitstun_duration
	_change_state(EnemyState.HURT)
	if health <= 0:
		_change_state(EnemyState.DEAD)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if dead or not area.is_in_group("player_attack_hitbox"):
		return
	var attack_id: int = int(area.get_meta("attack_id", -1))
	if attack_id < 0 or struck_attack_ids.has(attack_id):
		return
	struck_attack_ids[attack_id] = true
	var attacker: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var attacker_position: Vector2 = attacker.global_position if attacker != null else global_position
	HitEffect.spawn_hit(get_parent(), global_position, attacker_position, 0)
	take_damage(1, 1, signf(global_position.x - attacker_position.x))

func stun_from_parry(duration: float) -> void:
	if dead:
		return
	hitstun_time = maxf(hitstun_time, duration)
	_change_state(EnemyState.HURT)

func _spawn_attack_indicator() -> void:
	var indicator: AnimatedSprite2D = ATTACK_INDICATOR_SCENE.instantiate() as AnimatedSprite2D
	indicator.position = Vector2(0.0, -42.0)
	indicator.speed_scale = 1.5
	add_child(indicator)

func attack_indicator_frame_reached() -> void:
	if not dead:
		attack_indicator_hit = true

func _set_weapon_active(active: bool) -> void:
	weapon_shape.set_deferred("disabled", not active)
	weapon_hitbox.set_deferred("monitoring", active)
	weapon_hitbox.position.x = 14.0 * facing

func _set_animation(animation_name: StringName, restart: bool = false) -> void:
	if animated_sprite.sprite_frames.has_animation(animation_name) and (restart or animated_sprite.animation != animation_name):
		animated_sprite.play(animation_name)

func launch_from_burst(direction: Vector2, launch_speed: float) -> void:
	if direction.is_zero_approx() or dead:
		return
	burst_launch_time = 0.38
	state = EnemyState.IDLE
	crawler.launch_impulse(direction.normalized() * launch_speed)
	_set_animation(&"move", true)


func _apply_gravity(delta: float) -> void:
	var target_position: Vector2 = player.global_position if is_instance_valid(player) else global_position + Vector2(signf(velocity.x), 0.0)
	crawler.prepare_motion(delta, velocity.x, target_position, attack_leaping)

func _after_move() -> void:
	if attack_leaping and is_on_floor():
		attack_leaping = false
		velocity.x = 0.0

func _spawn_coin_drop() -> void:
	var drop_parent: Node2D = get_parent() as Node2D
	var manager: Node = get_node_or_null("/root/CoinDropManager")
	if drop_parent != null and manager != null and manager.has_method("drop_at"):
		manager.call("drop_at", drop_parent, global_position, {"drop_chance": 1.0, "min_coins": 1, "max_coins": 2, "min_types": 1, "max_types": 1, "value_multiplier": 1.0})

func _on_animation_finished() -> void:
	if state == EnemyState.DEAD:
		animated_sprite.pause()
