extends CharacterBody2D
class_name BigSpiderEnemy

enum EnemyState { IDLE, CHASE, ATTACK, RECOVERY, HURT, DEAD }

const GRAVITY: float = 1250.0
const ATTACK_INDICATOR_SCENE: PackedScene = preload("res://scenes/attackindicator.tscn")
const ATTACK_IMPACT_FRAME: int = 2
const ATTACK_WOOSH_PITCH: float = 1.40
const SMALL_SPIDER_SCENE: PackedScene = preload("res://scenes/smallspider.tscn")
const ENEMY_HURT_SOUND: AudioStream = preload("res://assets/sounds/enemyhurt.mp3")
const SPIDER_DESATURATION: float = 0.45
const SPIDER_OVERLAY_COLOR: Color = Color(0.46, 0.46, 0.46, 1.0)
const SPIDER_OVERLAY_STRENGTH: float = 0.20
const SPIDER_BRIGHTNESS: float = 1.0
const SPIDER_VISIBILITY: float = 1.0
const ENEMY_SCENE_TINT_SHADER: Shader = preload("res://shaders/enemy_scene_tint.gdshader")
const SPIDERLING_SPAWN_RADIUS: float = 54.0
const SPIDERLING_LAUNCH_SPEED: float = 320.0

@export var max_health: int = 60
@export var move_speed: float = 82.0
@export var detection_range: float = 560.0
@export var attack_range: float = 68.0
@export var attack_cooldown: float = 0.65
@export var hitstun_duration: float = 0.3
@export var knockback_force: float = 75.0

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
var attack_indicator_hit: bool = false
var attack_leaping: bool = false
var small_spiders_spawned: bool = false
var struck_attack_ids: Dictionary = {}
var player: CharacterBody2D = null
var hurt_audio: AudioStreamPlayer2D = null
var attack_woosh_audio: AudioStreamPlayer2D = null
var hit_effect_index: int = 0
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
	hurt_audio.volume_db = 4.0
	hurt_audio.pitch_scale = 1.07
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
	if dead:
		return
	if state == EnemyState.HURT:
		hitstun_time = maxf(0.0, hitstun_time - delta)
		velocity.x = move_toward(velocity.x, 0.0, 650.0 * delta)
		_apply_gravity(delta)
		move_and_slide()
		_after_move()
		if hitstun_time <= 0.0:
			_change_state(EnemyState.CHASE)
		return
	if state == EnemyState.ATTACK:
		_process_attack(delta)
		return
	if state == EnemyState.RECOVERY:
		velocity.x = move_toward(velocity.x, 0.0, 850.0 * delta)
		_apply_gravity(delta)
		move_and_slide()
		_after_move()
		if state_time >= 0.3:
			_change_state(EnemyState.CHASE)
		return

	player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null:
		_change_state(EnemyState.IDLE)
		velocity.x = move_toward(velocity.x, 0.0, 850.0 * delta)
	else:
		var offset: Vector2 = player.global_position - global_position
		var distance: float = global_position.distance_to(player.global_position)
		if distance > detection_range:
			_change_state(EnemyState.IDLE)
			velocity.x = move_toward(velocity.x, 0.0, 850.0 * delta)
		elif absf(offset.x) <= attack_range and absf(offset.y) <= 48.0 and cooldown_time <= 0.0 and is_on_floor():
			facing = 1 if offset.x >= 0.0 else -1
			_change_state(EnemyState.ATTACK)
			attack_leaping = crawler.surface_normal.dot(Vector2.UP) < 0.9
			if attack_leaping:
				velocity = crawler.attack_launch_velocity(player.global_position, 280.0, Vector2.ZERO)
			else:
				velocity = Vector2.ZERO
		else:
			_change_state(EnemyState.CHASE)
			facing = 1 if offset.x >= 0.0 else -1
			velocity.x = facing * move_speed
			_set_animation(&"move")
	animated_sprite.flip_h = facing < 0
	_apply_gravity(delta)
	move_and_slide()
	_after_move()

func _process_attack(_delta: float) -> void:
	if not attack_leaping:
		velocity.x = 0.0
	_apply_gravity(_delta)
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
			collision_layer = 0
			collision_mask = 0
			_set_animation(&"death", true)
			_spawn_coin_drop()
			if not small_spiders_spawned:
				small_spiders_spawned = true
				call_deferred("_spawn_small_spiders")

func take_damage(amount: int, _attack_level: int = 1, direction: float = 0.0) -> void:
	if dead:
		return
	health -= amount
	if hurt_audio != null:
		hurt_audio.play()
	velocity.x = direction * knockback_force
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
	HitEffect.spawn_hit(get_parent(), global_position, attacker_position, hit_effect_index)
	hit_effect_index = posmod(hit_effect_index + 1, 3)
	var attack_level: int = int(attacker.call("get_attack_level")) if attacker != null and attacker.has_method("get_attack_level") else 1
	var damage: int = int(attacker.call("get_attack_damage")) if attacker != null and attacker.has_method("get_attack_damage") else (10 if attack_level <= 1 else 20)
	HitEffect.apply_attack_damage(self, attacker, [damage, attack_level, signf(global_position.x - attacker_position.x)])

func stun_from_parry(duration: float) -> void:
	if dead:
		return
	hitstun_time = maxf(hitstun_time, duration)
	_change_state(EnemyState.HURT)

func _spawn_attack_indicator() -> void:
	var indicator: AnimatedSprite2D = ATTACK_INDICATOR_SCENE.instantiate() as AnimatedSprite2D
	indicator.position = Vector2(0.0, -52.0)
	indicator.speed_scale = 1.5
	add_child(indicator)

func attack_indicator_frame_reached() -> void:
	if not dead:
		attack_indicator_hit = true

func _set_weapon_active(active: bool) -> void:
	weapon_shape.set_deferred("disabled", not active)
	weapon_hitbox.set_deferred("monitoring", active)
	weapon_hitbox.position.x = 24.0 * facing

func _set_animation(animation_name: StringName, restart: bool = false) -> void:
	if animated_sprite.sprite_frames.has_animation(animation_name) and (restart or animated_sprite.animation != animation_name):
		animated_sprite.play(animation_name)

func _apply_gravity(delta: float) -> void:
	var target_position: Vector2 = player.global_position if is_instance_valid(player) else global_position + Vector2(signf(velocity.x), 0.0)
	crawler.prepare_motion(delta, velocity.x, target_position, attack_leaping)

func _after_move() -> void:
	if attack_leaping and is_on_floor():
		attack_leaping = false
		velocity.x = 0.0

func _spawn_coin_drop() -> void:
	var parent: Node2D = get_parent() as Node2D
	var manager: Node = get_node_or_null("/root/CoinDropManager")
	if parent != null and manager != null and manager.has_method("drop_at"):
		manager.call("drop_at", parent, global_position, {"drop_chance": 1.0, "min_coins": 2, "max_coins": 3, "min_types": 1, "max_types": 2, "value_multiplier": 1.0})

func _spawn_small_spiders() -> void:
	var parent: Node2D = get_parent() as Node2D
	if parent == null:
		return
	var spider_count: int = randi_range(2, 3)
	var outward_normal: Vector2 = crawler.surface_normal.normalized()
	if outward_normal.is_zero_approx():
		outward_normal = Vector2.UP
	var first_angle: float = outward_normal.angle() - PI * 0.5
	for index: int in spider_count:
		var spider: SmallSpiderEnemy = SMALL_SPIDER_SCENE.instantiate() as SmallSpiderEnemy
		parent.add_child(spider)
		var direction_ratio: float = float(index) / float(maxi(1, spider_count - 1))
		var direction: Vector2 = Vector2.RIGHT.rotated(first_angle + PI * direction_ratio).normalized()
		spider.global_position = global_position + direction * SPIDERLING_SPAWN_RADIUS
		spider.launch_from_burst(direction, SPIDERLING_LAUNCH_SPEED)

func _on_animation_finished() -> void:
	if state == EnemyState.DEAD:
		animated_sprite.pause()
