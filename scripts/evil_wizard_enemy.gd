extends CharacterBody2D
class_name EvilWizardEnemy

enum WizardState { IDLE, RECOVER, MELEE, CAST, SHIELD, TELEPORT_OUT, TELEPORT_IN, HURT, DEAD }
enum ScriptedAction { THUNDER, TELEPORT, SHIELD, HEAL }

const SPELL_SCENE: PackedScene = preload("res://scenes/evilwizardspell.tscn")
const ATTACK_INDICATOR_SCENE: PackedScene = preload("res://scenes/attackindicator.tscn")
const ENEMY_HURT_SOUND: AudioStream = preload("res://assets/sounds/enemyhurt.mp3")
const GRAVITY: float = 1250.0
const MELEE_IMPACT_FRAME: int = 5
const ATTACK_WOOSH_PITCH: float = 0.75
const CAST_TRIGGER_FRAME: int = 4
const ACTION_SCRIPT: Array[ScriptedAction] = [ScriptedAction.THUNDER, ScriptedAction.TELEPORT, ScriptedAction.SHIELD, ScriptedAction.THUNDER]

@export var max_health: int = 180
@export var detection_range: float = 700.0
@export var melee_range: float = 76.0
@export var action_delay: float = 0.9
@export var shield_duration: float = 2.2
@export var heal_amount: int = 30
@export var teleport_distance: float = 170.0
@export var thunder_spacing: float = 58.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var weapon_hitbox: Area2D = $WeaponHitbox
@onready var weapon_shape: CollisionShape2D = $WeaponHitbox/CollisionShape2D

var state: WizardState = WizardState.IDLE
var current_action: ScriptedAction = ScriptedAction.THUNDER
var player: CharacterBody2D
var health: int = 0
var facing: int = -1
var action_index: int = 0
var action_time: float = 0.0
var parry_stun_time: float = 0.0
var shield_time: float = 0.0
var cast_triggered: bool = false
var melee_impact_reached: bool = false
var heal_used: bool = false
var dead: bool = false
var arena_origin: Vector2 = Vector2.ZERO
var teleport_destination: Vector2 = Vector2.ZERO
var struck_attack_ids: Dictionary = {}
var hit_effect_index: int = 0
var spell_overlay: EvilWizardSpellEffect
var hurt_audio: AudioStreamPlayer2D
var attack_woosh_audio: AudioStreamPlayer2D

func _ready() -> void:
	add_to_group("enemy")
	health = max_health
	arena_origin = global_position
	floor_snap_length = 4.0
	weapon_shape.disabled = true
	weapon_hitbox.monitoring = false
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	animated_sprite.frame_changed.connect(_on_body_frame_changed)
	animated_sprite.animation_finished.connect(_on_body_animation_finished)
	spell_overlay = SPELL_SCENE.instantiate() as EvilWizardSpellEffect
	spell_overlay.position = Vector2(0.0, -12.0)
	spell_overlay.z_index = 2
	spell_overlay.effect_finished.connect(_on_spell_effect_finished)
	add_child(spell_overlay)
	hurt_audio = AudioStreamPlayer2D.new()
	hurt_audio.stream = ENEMY_HURT_SOUND
	hurt_audio.pitch_scale = 1.02
	add_child(hurt_audio)
	attack_woosh_audio = EnemyAttackAudio.create_player(self, ATTACK_WOOSH_PITCH)
	_set_animation(&"idle", true)

func _physics_process(delta: float) -> void:
	if dead:
		return
	if parry_stun_time > 0.0:
		parry_stun_time = maxf(0.0, parry_stun_time - delta)
		_apply_gravity(delta)
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		move_and_slide()
		return
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	_apply_gravity(delta)
	velocity.x = 0.0
	if state == WizardState.SHIELD:
		shield_time = maxf(0.0, shield_time - delta)
		if shield_time <= 0.0:
			spell_overlay.stop_effect()
			_enter_recovery()
	elif state == WizardState.RECOVER:
		action_time = maxf(0.0, action_time - delta)
		if action_time <= 0.0:
			_choose_next_action()
	elif state == WizardState.IDLE and player != null:
		if global_position.distance_to(player.global_position) <= detection_range:
			_enter_recovery(0.55)
	if player != null and state not in [WizardState.TELEPORT_OUT, WizardState.TELEPORT_IN]:
		facing = 1 if player.global_position.x > global_position.x else -1
		animated_sprite.flip_h = facing < 0
	move_and_slide()

func _choose_next_action() -> void:
	if player == null:
		_change_state(WizardState.IDLE)
		return
	var distance: float = global_position.distance_to(player.global_position)
	if distance <= melee_range:
		_start_melee()
		return
	if health <= int(max_health * 0.45) and not heal_used:
		heal_used = true
		_start_cast(ScriptedAction.HEAL)
		return
	var scripted_action: ScriptedAction = ACTION_SCRIPT[action_index % ACTION_SCRIPT.size()]
	action_index += 1
	_start_cast(scripted_action)

func _start_melee() -> void:
	attack_woosh_audio.play()
	_change_state(WizardState.MELEE)
	melee_impact_reached = false
	struck_attack_ids.clear()
	_spawn_melee_indicator()
	_set_animation(&"attack", true)

func _start_cast(action: ScriptedAction) -> void:
	attack_woosh_audio.play()
	current_action = action
	cast_triggered = false
	_change_state(WizardState.CAST)
	_set_animation(&"cast", true)

func _on_body_frame_changed() -> void:
	if state == WizardState.MELEE:
		if animated_sprite.frame >= MELEE_IMPACT_FRAME and not melee_impact_reached:
			melee_impact_reached = true
			_set_weapon_active(true)
		elif melee_impact_reached and animated_sprite.frame > MELEE_IMPACT_FRAME:
			_set_weapon_active(false)
	elif state == WizardState.CAST and animated_sprite.frame >= CAST_TRIGGER_FRAME and not cast_triggered:
		_trigger_cast_action()

func _trigger_cast_action() -> void:
	cast_triggered = true
	match current_action:
		ScriptedAction.THUNDER:
			_spawn_thunder_barrage()
		ScriptedAction.TELEPORT:
			teleport_destination = _find_teleport_destination()
			state = WizardState.TELEPORT_OUT
			spell_overlay.scale = Vector2.ONE
			spell_overlay.play_effect(&"teleport")
		ScriptedAction.SHIELD:
			state = WizardState.SHIELD
			shield_time = shield_duration
			spell_overlay.scale = Vector2(1.25, 1.25)
			spell_overlay.play_effect(&"shield")
		ScriptedAction.HEAL:
			health = mini(max_health, health + heal_amount)
			spell_overlay.scale = Vector2(1.08, 1.08)
			spell_overlay.play_effect(&"heal")

func _on_body_animation_finished() -> void:
	if dead:
		animated_sprite.pause()
		return
	if state == WizardState.MELEE:
		_set_weapon_active(false)
		_enter_recovery()
	elif state == WizardState.CAST:
		if not cast_triggered:
			_trigger_cast_action()
		if current_action in [ScriptedAction.THUNDER, ScriptedAction.HEAL]:
			_enter_recovery()
	elif state == WizardState.HURT:
		_enter_recovery(0.45)

func _on_spell_effect_finished(animation_name: StringName) -> void:
	if dead:
		return
	if animation_name == &"teleport" and state == WizardState.TELEPORT_OUT:
		global_position = teleport_destination
		animated_sprite.visible = true
		state = WizardState.TELEPORT_IN
		spell_overlay.scale = Vector2.ONE
		spell_overlay.play_effect(&"teleportappear")
	elif animation_name == &"teleportappear" and state == WizardState.TELEPORT_IN:
		_enter_recovery(0.55)

func _spawn_thunder_barrage() -> void:
	if player == null:
		return
	var offsets: Array[float] = [-thunder_spacing, 0.0, thunder_spacing]
	for offset: float in offsets:
		var target_x: float = player.global_position.x + offset
		var floor_point: Vector2 = _floor_point_at(target_x, player.global_position.y)
		var warning: EvilWizardStrikeWarning = EvilWizardStrikeWarning.new()
		get_parent().add_child(warning)
		warning.global_position = floor_point
		warning.setup(self)

func _find_teleport_destination() -> Vector2:
	var direction: float = -1.0 if player != null and player.global_position.x > arena_origin.x else 1.0
	var target_x: float = arena_origin.x + direction * teleport_distance
	var floor_point: Vector2 = _floor_point_at(target_x, arena_origin.y)
	return floor_point - Vector2(0.0, 43.0)

func _floor_point_at(target_x: float, reference_y: float) -> Vector2:
	var from: Vector2 = Vector2(target_x, reference_y - 180.0)
	var to: Vector2 = Vector2(target_x, reference_y + 320.0)
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, 1)
	query.exclude = [self]
	var result: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	return result.get("position", Vector2(target_x, reference_y + 43.0)) as Vector2

func _spawn_melee_indicator() -> void:
	var indicator: AnimatedSprite2D = ATTACK_INDICATOR_SCENE.instantiate() as AnimatedSprite2D
	indicator.position = Vector2(0.0, -58.0)
	indicator.speed_scale = 1.45
	add_child(indicator)

func attack_indicator_frame_reached() -> void:
	pass

func _set_weapon_active(active: bool) -> void:
	weapon_shape.set_deferred("disabled", not active)
	weapon_hitbox.set_deferred("monitoring", active)
	weapon_hitbox.position = Vector2(43.0 * facing, 10.0)
	weapon_shape.position.x = absf(weapon_shape.position.x) * float(facing)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if dead or state == WizardState.SHIELD or not area.is_in_group("player_attack_hitbox"):
		return
	var attack_id: int = int(area.get_meta("attack_id", -1))
	if attack_id < 0 or struck_attack_ids.has(attack_id):
		return
	struck_attack_ids[attack_id] = true
	var attacker: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var attacker_position: Vector2 = attacker.global_position if attacker != null else global_position
	var attack_level: int = int(attacker.call("get_attack_level")) if attacker != null and attacker.has_method("get_attack_level") else 1
	HitEffect.spawn_hit(get_parent(), global_position + Vector2(0.0, -22.0), attacker_position, hit_effect_index)
	hit_effect_index = posmod(hit_effect_index + 1, 3)
	var damage: int = int(attacker.call("get_attack_damage")) if attacker != null and attacker.has_method("get_attack_damage") else (10 if attack_level == 1 else 20)
	take_damage(damage)

func stun_from_parry(duration: float) -> void:
	if dead or state == WizardState.SHIELD:
		return
	parry_stun_time = maxf(parry_stun_time, duration)
	_set_weapon_active(false)
	spell_overlay.stop_effect()
	_change_state(WizardState.HURT)
	_set_animation(&"hurt", true)

func take_damage(amount: int, _attack_level: int = 1, _direction: float = 0.0) -> void:
	if dead or state == WizardState.SHIELD:
		return
	health -= amount
	hurt_audio.play()
	_set_weapon_active(false)
	spell_overlay.stop_effect()
	if health <= 0:
		_die()
	else:
		_change_state(WizardState.HURT)
		_set_animation(&"hurt", true)

func _die() -> void:
	dead = true
	state = WizardState.DEAD
	velocity = Vector2.ZERO
	_set_weapon_active(false)
	spell_overlay.stop_effect()
	hurtbox.set_deferred("monitoring", false)
	body_collision.set_deferred("disabled", true)
	_set_animation(&"death", true)
	var manager: Node = get_node_or_null("/root/CoinDropManager")
	if manager != null and manager.has_method("drop_at"):
		manager.call("drop_at", get_parent(), global_position, {"drop_chance": 1.0, "min_coins": 10, "max_coins": 14, "min_types": 2, "max_types": 3, "value_multiplier": 1.5})

func _enter_recovery(duration: float = -1.0) -> void:
	_change_state(WizardState.RECOVER)
	action_time = action_delay if duration < 0.0 else duration
	_set_animation(&"idle", true)

func _change_state(next_state: WizardState) -> void:
	state = next_state
	if next_state not in [WizardState.MELEE]:
		_set_weapon_active(false)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0

func _set_animation(animation_name: StringName, restart: bool = false) -> void:
	if animated_sprite.sprite_frames.has_animation(animation_name) and (restart or animated_sprite.animation != animation_name):
		animated_sprite.play(animation_name)
