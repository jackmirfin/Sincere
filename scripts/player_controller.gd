extends CharacterBody2D
class_name PlayerController

signal gameplay_state_changed(state: StringName)
signal health_changed(current_health: int, maximum_health: int)
signal speed_boost_changed(active: bool, time_remaining: float)

enum PlayerState { LOCOMOTION, TURN, CROUCH_TRANSITION, CROUCH, CROUCH_ATTACK, SLIDE_START, SLIDE, SLIDE_END, WALL_HANG, WALL_CLIMB, WALL_SLIDE, ATTACK1, ATTACK2, ATTACK3, GROUND_POUND, GROUND_POUND_SLAM, JUMP, JUMP_TRANSITION, FALL, HIT, DEATH, ROLL, DASH }

const REQUIRED_ANIMATIONS: Array[StringName] = [&"idle", &"run", &"turn_around", &"crouch", &"crouch_transition", &"crouchwalk", &"crouchattack", &"slide", &"slide_transitionstart", &"slidefull", &"wallhang", &"wallclimb", &"wallclimb_no_movement", &"wallslide", &"attack", &"attack_no_movement", &"attack2", &"attack2_no_movement", &"attackcombo", &"attackcombo_no_movement", &"jump", &"jump_fall_inbetween", &"fall", &"hit", &"death", &"death_no_movement", &"roll", &"dash"]
const EXPECTED_FRAME_COUNTS: Dictionary = {&"idle": 10, &"run": 10, &"turn_around": 3, &"crouch_transition": 1, &"crouch": 1, &"crouchwalk": 8, &"crouchattack": 4, &"slide": 2, &"slide_transitionstart": 1, &"wallhang": 1, &"wallclimb": 17, &"wallclimb_no_movement": 7, &"wallslide": 3, &"attack": 4, &"attack_no_movement": 8, &"attack2": 6, &"attack2_no_movement": 6, &"jump": 3, &"jump_fall_inbetween": 2, &"fall": 3, &"hit": 1, &"death": 10, &"death_no_movement": 10, &"roll": 12, &"dash": 2}
const MOVE_SPEED: float = 202.0
const CROUCH_SPEED: float = 108.0
const ACCELERATION: float = 1200.0
const FRICTION: float = 1500.0
const JUMP_VELOCITY: float = -325.0
const WALL_SLIDE_SPEED: float = 90.0
const TURN_SPEED_THRESHOLD: float = 35.0
const HIT_STUN_DURATION: float = 0.18
const HIT_INVULNERABILITY_DURATION: float = 1.0
const COMBO_BUFFER_DURATION: float = 0.45
const DASH_DURATION: float = 0.12
const ROLL_DURATION: float = 0.55
const ROLL_SPEED: float = 125.0
const ACTION_SPEED: float = 190.0
const ACTION_DURATION: float = 0.55
const WALL_JUMP_VELOCITY: Vector2 = Vector2(260.0, -360.0)
const WALL_AWAY_JUMP_VELOCITY: Vector2 = Vector2(360.0, -500.0)
const WALL_ENTRY_LIFT_SPEED: float = -85.0
const MANTLE_UP_DISTANCE: float = 22.0
const MANTLE_FORWARD_DISTANCE: float = 8.0
const MANTLE_DURATION: float = 0.12
const PLAYER_HURT_SOUND: AudioStream = preload("res://assets/sounds/playerhurt.mp3")
const STANDING_SHAPE: Shape2D = preload("res://resources/player_body_shape.tres")
const CROUCH_SHAPE: Shape2D = preload("res://resources/player_crouch_shape.tres")
const SPRITE_STANDING_Y: float = -36.0
const SPRITE_LOW_Y: float = -31.0
const SPRITE_WALL_Y: float = -36.0
const MENU_SPRITE_OFFSET_X: float = -5.0
const MENU_SPRITE_OFFSET_Y: float = 20.0

@export_enum("Colour 1", "Colour 2") var colour_variant: int = 0
@export var outline_enabled: bool = true
@export var auto_start: bool = true
@export var play_outofbattery_on_landing: bool = false
@export_range(1, 6, 1) var max_health: int = 6

@export_group("Kill Speed Boost")
@export var quick_kill_window: float = 4.0
@export var speed_boost_duration: float = 20.0
@export var speed_boost_multiplier: float = 1.25

@export_group("Jump Feel")
@export var jump_height: float = 76.0
@export var time_to_apex: float = 0.36
@export var time_to_fall: float = 0.28
@export_range(0.0, 1.0) var early_release_velocity_ratio: float = 0.45
@export var max_fall_speed: float = 700.0
@export var coyote_time_duration: float = 0.05
@export var jump_buffer_duration: float = 0.083
@export var floor_snap_distance: float = 3.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D
@onready var ground_pound_hitbox: Area2D = $GroundPoundHitbox
@onready var ground_pound_shape: CollisionShape2D = $GroundPoundHitbox/CollisionShape2D

var state: PlayerState = PlayerState.LOCOMOTION
var facing: int = 1
var turn_target_facing: int = 1
var state_time: float = 0.0
var hit_stun_time: float = 0.0
var menu_animation_lock: bool = false
var menu_animation_callback: Callable
var menu_frame_one_callback: Callable
var menu_frame_two_callback: Callable
var combo_buffer_time: float = 0.0
var combo_link_time: float = 0.0
var jump_transition_started: bool = false
var attack_queued: bool = false
var was_grounded: bool = false
var crouched: bool = false
var dead: bool = false
var health: int = 6
var attack_id: int = 0
var hit_stop_time: float = 0.0
var coyote_time: float = 0.0
var wall_jump_lock_time: float = 0.0
var invulnerable_time: float = 0.0
var wall_contact_normal: Vector2 = Vector2.ZERO
var jump_velocity: float = 0.0
var rising_gravity: float = 0.0
var falling_gravity: float = 0.0
var jump_buffer_time: float = 0.0
var down_tap_time: float = 0.0
var charging_sequence_active: bool = false
var slide_momentum_active: bool = false
var slide_queued: bool = false
var mantle_time: float = 0.0
var teleport_locked: bool = false
var exit_run_active: bool = false
var exit_run_speed: float = 240.0
var intro_run_active: bool = false
var intro_run_remaining: float = 0.0
var intro_run_speed: float = 90.0
var elevator_ride_active: bool = false
var attack_damage_bonus: int = 0
var move_speed_multiplier: float = 1.0
var hit_slowdown_active: bool = false
var hit_freeze_active: bool = false
var speed_boost_time: float = 0.0
var quick_kill_time: float = 0.0
var quick_kill_count: int = 0
var enemy_death_states: Dictionary = {}
var hurt_audio: AudioStreamPlayer2D

func _add_sheet_animation(animation_name: StringName, texture_path: String, frame_size: Vector2, frame_count: int, speed: float, loop: bool) -> void:
	if animated_sprite.sprite_frames.has_animation(animation_name):
		return
	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		return
	var frames: SpriteFrames = animated_sprite.sprite_frames
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, speed)
	frames.set_animation_loop(animation_name, loop)
	for frame_index: int in frame_count:
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(Vector2(frame_index * int(frame_size.x), 0), frame_size)
		frames.add_frame(animation_name, atlas)

func _configure_stop_charging_animation() -> void:
	var texture: Texture2D = load("res://assets/characters/knight/chargemp3.png") as Texture2D
	if texture == null:
		return
	var frames: SpriteFrames = animated_sprite.sprite_frames
	if frames.has_animation(&"stopchargingmp3"):
		frames.remove_animation(&"stopchargingmp3")
	frames.add_animation(&"stopchargingmp3")
	frames.set_animation_speed(&"stopchargingmp3", 7.0)
	frames.set_animation_loop(&"stopchargingmp3", false)
	for frame_index: int in [1, 0]:
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(Vector2(frame_index * 120, 0), Vector2(120, 80))
		frames.add_frame(&"stopchargingmp3", atlas)

func _ensure_special_animations() -> void:
	_configure_stop_charging_animation()
	_add_sheet_animation(&"groundpound", "res://assets/characters/knight/groundpound.png", Vector2(60, 80), 6, 10.0, true)
	_add_sheet_animation(&"groundpoundslam", "res://assets/characters/knight/groundpoundslam.png", Vector2(60, 80), 8, 10.0, false)
	_add_sheet_animation(&"shrug", "res://assets/characters/knight/shrug.png", Vector2(120, 80), 5, 7.0, false)

func _recalculate_jump_values() -> void:
	var safe_apex_time: float = maxf(0.01, time_to_apex)
	var safe_fall_time: float = maxf(0.01, time_to_fall)
	jump_velocity = -2.0 * jump_height / safe_apex_time
	rising_gravity = 2.0 * jump_height / (safe_apex_time * safe_apex_time)
	falling_gravity = 2.0 * jump_height / (safe_fall_time * safe_fall_time)

func _ready() -> void:
	health = max_health
	_recalculate_jump_values()
	_ensure_special_animations()
	ground_pound_shape.disabled = true
	ground_pound_hitbox.monitoring = false
	# Midworld used to play the out-of-battery landing animation on the knight's
	# first landing; it is only played now when a scene explicitly asks for it.
	hurt_audio = AudioStreamPlayer2D.new()
	hurt_audio.stream = PLAYER_HURT_SOUND
	add_child(hurt_audio)
	floor_snap_length = floor_snap_distance
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)
	if not animated_sprite.frame_changed.is_connected(_on_menu_frame_changed):
		animated_sprite.frame_changed.connect(_on_menu_frame_changed)
	if not animated_sprite.frame_changed.is_connected(_sync_special_animation_grounding):
		animated_sprite.frame_changed.connect(_sync_special_animation_grounding)
	if not hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	_validate_animations()
	_set_animation(&"idle", true)
	was_grounded = is_on_floor()

func _physics_process(delta: float) -> void:
	_update_enemy_kill_tracking()
	_update_speed_boost(delta)
	if exit_run_active:
		_update_exit_run(delta)
		return
	if intro_run_active:
		_update_intro_run(delta)
		return
	if elevator_ride_active:
		velocity = Vector2.ZERO
		animated_sprite.position = Vector2(0.0, SPRITE_STANDING_Y)
		_set_animation(&"idle")
		was_grounded = is_on_floor()
		return
	if teleport_locked:
		velocity = Vector2.ZERO
		return
	state_time += delta
	mantle_time = maxf(0.0, mantle_time - delta)
	down_tap_time = maxf(0.0, down_tap_time - delta)
	if menu_animation_lock:
		velocity = Vector2.ZERO
		return
	if hit_stop_time > 0.0:
		hit_stop_time = maxf(0.0, hit_stop_time - delta)
		return
	if mantle_time > 0.0:
		velocity = Vector2.ZERO
		floor_snap_length = floor_snap_distance
		move_and_slide()
		was_grounded = is_on_floor()
		return
	if was_grounded and not is_on_floor():
		coyote_time = coyote_time_duration
	else:
		coyote_time = maxf(0.0, coyote_time - delta)
	jump_buffer_time = maxf(0.0, jump_buffer_time - delta)
	wall_jump_lock_time = maxf(0.0, wall_jump_lock_time - delta)
	invulnerable_time = maxf(0.0, invulnerable_time - delta)
	if hit_stun_time > 0.0:
		hit_stun_time = maxf(0.0, hit_stun_time - delta)
	if combo_buffer_time > 0.0:
		combo_buffer_time = maxf(0.0, combo_buffer_time - delta)
	combo_link_time = maxf(0.0, combo_link_time - delta)
	_read_action_edges()
	_apply_physics(delta)
	_update_gameplay_state(delta)
	_sync_collision_shape()
	_update_animation()
	was_grounded = is_on_floor()

func _update_enemy_kill_tracking() -> void:
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		var enemy: Node2D = node as Node2D
		if enemy == null or enemy == self:
			continue
		var enemy_id: int = enemy.get_instance_id()
		var dead_now: bool = enemy.get("dead") == true
		if not enemy_death_states.has(enemy_id):
			enemy_death_states[enemy_id] = dead_now
		elif enemy_death_states[enemy_id] != true and dead_now:
			enemy_death_states[enemy_id] = true
			register_enemy_kill()


func _update_speed_boost(delta: float) -> void:
	if quick_kill_time > 0.0:
		quick_kill_time = maxf(0.0, quick_kill_time - delta)
		if quick_kill_time <= 0.0:
			quick_kill_count = 0
	if speed_boost_time > 0.0:
		speed_boost_time = maxf(0.0, speed_boost_time - delta)
		if speed_boost_time <= 0.0:
			speed_boost_changed.emit(false, 0.0)


func register_enemy_kill() -> void:
	if quick_kill_time <= 0.0:
		quick_kill_count = 0
	quick_kill_count += 1
	quick_kill_time = quick_kill_window
	if quick_kill_count < 3:
		return
	quick_kill_count = 0
	quick_kill_time = 0.0
	speed_boost_time = speed_boost_duration
	speed_boost_changed.emit(true, speed_boost_time)


func is_speed_boost_active() -> bool:
	return speed_boost_time > 0.0


func get_effective_move_speed() -> float:
	return MOVE_SPEED * move_speed_multiplier * (speed_boost_multiplier if is_speed_boost_active() else 1.0)


func _has_slide_cancel_input() -> bool:
	return Input.is_action_just_pressed("left") or Input.is_action_just_pressed("right") or Input.is_action_just_pressed("crouch") or Input.is_action_just_pressed("dodge") or Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("interact")

func _has_held_slide_movement() -> bool:
	return Input.is_action_pressed("left") or Input.is_action_pressed("right")

func _read_action_edges() -> void:
	if state in [PlayerState.SLIDE_START, PlayerState.SLIDE] and Input.is_action_just_pressed("jump"):
		crouched = false
		slide_queued = false
		velocity.y = jump_velocity
		jump_transition_started = false
		jump_buffer_time = 0.0
		_change_state(PlayerState.JUMP)
		return
	if state in [PlayerState.SLIDE_START, PlayerState.SLIDE] and _has_slide_cancel_input():
		_change_state(_locomotion_state())
		return
	if state == PlayerState.SLIDE and slide_momentum_active and state_time >= ACTION_DURATION - 0.08 and _has_held_slide_movement():
		_change_state(_locomotion_state())
		return
	if Input.is_action_just_pressed("crouch") and not is_on_floor() and state not in [PlayerState.GROUND_POUND, PlayerState.GROUND_POUND_SLAM]:
		if absf(Input.get_axis("left", "right")) > 0.01:
			slide_queued = true
		if down_tap_time > 0.0:
			slide_queued = false
			velocity.y = maxf(velocity.y, 520.0)
			_change_state(PlayerState.GROUND_POUND)
			down_tap_time = 0.0
			return
		down_tap_time = 0.25
	if Input.is_action_just_pressed("dodge") and not dead:
		attack_queued = false
		combo_buffer_time = 0.0
		combo_link_time = 0.0
		crouched = false
		_change_state(PlayerState.ROLL if is_on_floor() else PlayerState.DASH)
		return
	if Input.is_action_just_pressed("crouch") and is_on_floor() and absf(velocity.x) > TURN_SPEED_THRESHOLD:
		_change_state(PlayerState.SLIDE_START)
	if Input.is_action_just_pressed("attack"):
		if state in [PlayerState.ROLL, PlayerState.SLIDE_START, PlayerState.SLIDE]:
			_change_state(PlayerState.CROUCH_ATTACK if crouched else PlayerState.ATTACK1)
		elif state in [PlayerState.ATTACK1, PlayerState.ATTACK2] and state_time > 0.04:
			attack_queued = true
			combo_buffer_time = COMBO_BUFFER_DURATION
		elif state == PlayerState.LOCOMOTION and combo_link_time > 0.0:
			combo_link_time = 0.0
			_change_state(PlayerState.ATTACK2)
		elif _can_start_attack():
			_change_state(PlayerState.CROUCH_ATTACK if crouched else PlayerState.ATTACK1)
	if Input.is_action_just_pressed("dodge") and _can_start_dodge():
		_change_state(PlayerState.ROLL if is_on_floor() else PlayerState.DASH)
	if Input.is_action_just_pressed("jump"):
		jump_buffer_time = jump_buffer_duration
	if jump_buffer_time > 0.0:
		if state in [PlayerState.ROLL, PlayerState.SLIDE_START, PlayerState.SLIDE]:
			crouched = false
			velocity.y = jump_velocity
			jump_transition_started = false
			jump_buffer_time = 0.0
			_change_state(PlayerState.JUMP)
		elif _can_jump():
			if _is_wall_attached():
				var wall_normal: Vector2 = wall_contact_normal if absf(wall_contact_normal.x) > 0.1 else get_wall_normal()
				var horizontal_input: float = Input.get_axis("left", "right")
				velocity = get_wall_jump_velocity(wall_normal, horizontal_input)
				facing = 1 if velocity.x > 0.0 else -1
				wall_jump_lock_time = 0.22 if horizontal_input * wall_normal.x > 0.1 else 0.16
			else:
				velocity.y = jump_velocity
			jump_transition_started = false
			jump_buffer_time = 0.0
			_change_state(PlayerState.JUMP)

func get_wall_jump_velocity(wall_normal: Vector2, horizontal_input: float) -> Vector2:
	var away_direction: float = signf(wall_normal.x)
	var jumping_away: bool = horizontal_input * wall_normal.x > 0.1
	if jumping_away:
		return Vector2(away_direction * WALL_AWAY_JUMP_VELOCITY.x, WALL_AWAY_JUMP_VELOCITY.y)
	return Vector2(away_direction * WALL_JUMP_VELOCITY.x, jump_velocity)


func should_apply_wall_entry_lift(was_touching_wall: bool, grounded: bool, horizontal_input: float, wall_normal: Vector2) -> bool:
	return not was_touching_wall and not grounded and absf(wall_normal.x) > 0.7 and horizontal_input * wall_normal.x < -0.1


func _apply_physics(delta: float) -> void:
	var horizontal_input: float = Input.get_axis("left", "right")
	var was_touching_wall: bool = is_on_wall()
	if state == PlayerState.TURN and animated_sprite.frame >= 1:
		facing = turn_target_facing
	var grounded: bool = is_on_floor()
	if not grounded:
		var gravity: float = rising_gravity if velocity.y < 0.0 else falling_gravity
		velocity.y += gravity * delta
		if state == PlayerState.JUMP and not Input.is_action_pressed("jump") and velocity.y < 0.0:
			velocity.y = maxf(velocity.y, jump_velocity * early_release_velocity_ratio)
		velocity.y = minf(velocity.y, max_fall_speed)
	if state == PlayerState.GROUND_POUND:
		velocity.x = 0.0
		velocity.y = maxf(velocity.y, 520.0)
	elif wall_jump_lock_time > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	elif state == PlayerState.DEATH:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	elif state in [PlayerState.ATTACK1, PlayerState.ATTACK2, PlayerState.ATTACK3, PlayerState.CROUCH_ATTACK, PlayerState.HIT, PlayerState.TURN, PlayerState.CROUCH_TRANSITION, PlayerState.SLIDE_END]:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	elif state == PlayerState.DASH:
		velocity.x = facing * get_effective_move_speed() * 1.7
	elif state == PlayerState.ROLL:
		velocity.x = facing * ACTION_SPEED
	elif state in [PlayerState.SLIDE_START, PlayerState.SLIDE]:
		if slide_momentum_active:
			velocity.x = facing * ACTION_SPEED
		else:
			velocity.x = 0.0
			invulnerable_time = maxf(invulnerable_time, 0.05)
	elif state == PlayerState.WALL_SLIDE:
		velocity.x = 0.0
		velocity.y = minf(velocity.y, WALL_SLIDE_SPEED)
	else:
		var boost_multiplier: float = speed_boost_multiplier if is_speed_boost_active() else 1.0
		var target_speed: float = CROUCH_SPEED * boost_multiplier if crouched else get_effective_move_speed()
		velocity.x = move_toward(velocity.x, horizontal_input * target_speed, ACCELERATION * boost_multiplier * delta if absf(horizontal_input) > 0.01 else FRICTION * delta)
	if horizontal_input != 0.0 and state in [PlayerState.ROLL, PlayerState.SLIDE_START, PlayerState.SLIDE]:
		facing = 1 if horizontal_input > 0.0 else -1
	if horizontal_input != 0.0 and state in [PlayerState.ATTACK1, PlayerState.ATTACK2, PlayerState.ATTACK3, PlayerState.CROUCH_ATTACK]:
		facing = 1 if horizontal_input > 0.0 else -1
	if horizontal_input != 0.0 and wall_jump_lock_time <= 0.0 and state not in [PlayerState.ATTACK1, PlayerState.ATTACK2, PlayerState.ATTACK3, PlayerState.DEATH, PlayerState.HIT, PlayerState.ROLL, PlayerState.SLIDE_START, PlayerState.SLIDE, PlayerState.DASH]:
		var new_facing: int = 1 if horizontal_input > 0.0 else -1
		if new_facing != facing and grounded and absf(velocity.x) >= TURN_SPEED_THRESHOLD and state == PlayerState.LOCOMOTION:
			turn_target_facing = new_facing
			_change_state(PlayerState.TURN)
		elif state != PlayerState.TURN:
			facing = new_facing
	animated_sprite.flip_h = turn_target_facing > 0 if state == PlayerState.TURN else facing < 0
	floor_snap_length = floor_snap_distance
	wall_contact_normal = Vector2.ZERO
	move_and_slide()
	for collision_index: int in get_slide_collision_count():
		var collision: KinematicCollision2D = get_slide_collision(collision_index)
		if absf(collision.get_normal().x) > 0.7:
			wall_contact_normal = collision.get_normal()
			break
	if should_apply_wall_entry_lift(was_touching_wall, grounded, horizontal_input, wall_contact_normal):
		velocity.y = minf(velocity.y, WALL_ENTRY_LIFT_SPEED)
	_try_forgiving_mantle()

func _try_forgiving_mantle() -> void:
	if is_on_floor() or wall_contact_normal == Vector2.ZERO or velocity.y < -80.0:
		return
	if state in [PlayerState.ATTACK1, PlayerState.ATTACK2, PlayerState.ATTACK3, PlayerState.HIT, PlayerState.DEATH, PlayerState.ROLL, PlayerState.DASH]:
		return
	var wall_direction: float = -signf(wall_contact_normal.x)
	if is_zero_approx(wall_direction):
		return
	var upward_motion: Vector2 = Vector2(0.0, -MANTLE_UP_DISTANCE)
	if test_move(global_transform, upward_motion):
		return
	var elevated_transform: Transform2D = global_transform
	elevated_transform.origin += upward_motion
	var forward_motion: Vector2 = Vector2(wall_direction * MANTLE_FORWARD_DISTANCE, 0.0)
	if test_move(elevated_transform, forward_motion):
		return
	global_position += upward_motion + forward_motion
	velocity = Vector2.ZERO
	wall_contact_normal = Vector2.ZERO
	mantle_time = MANTLE_DURATION
	_change_state(_locomotion_state())

func _update_gameplay_state(_delta: float) -> void:
	if dead:
		return
	if state == PlayerState.HIT:
		if hit_stun_time <= 0.0:
			_change_state(_locomotion_state())
		return
	if state == PlayerState.DEATH:
		return
	if mantle_time > 0.0:
		return
	if state == PlayerState.GROUND_POUND and is_on_floor():
		velocity = Vector2.ZERO
		_change_state(PlayerState.GROUND_POUND_SLAM)
		return
	if state in [PlayerState.GROUND_POUND, PlayerState.GROUND_POUND_SLAM]:
		return
	if is_on_floor() and state in [PlayerState.FALL, PlayerState.JUMP, PlayerState.JUMP_TRANSITION]:
		jump_transition_started = false
		var land_input_x: float = Input.get_axis("left", "right")
		var should_slide_on_landing: bool = slide_queued and absf(land_input_x) > 0.01
		slide_queued = false
		if should_slide_on_landing:
			_change_state(PlayerState.SLIDE_START)
			return
		if play_outofbattery_on_landing:
			play_outofbattery_on_landing = false
			_play_landing_animation()
		else:
			_change_state(_locomotion_state())
		return
	if state in [PlayerState.ATTACK1, PlayerState.ATTACK2, PlayerState.ATTACK3, PlayerState.CROUCH_ATTACK, PlayerState.ROLL, PlayerState.DASH, PlayerState.TURN, PlayerState.CROUCH_TRANSITION, PlayerState.SLIDE_START, PlayerState.SLIDE, PlayerState.SLIDE_END]:
		if state == PlayerState.DASH and state_time >= DASH_DURATION:
			_change_state(_locomotion_state())
		elif state == PlayerState.ROLL and state_time >= ACTION_DURATION:
			_change_state(_locomotion_state())
		elif state == PlayerState.SLIDE and state_time >= ACTION_DURATION:
			slide_momentum_active = false
			velocity.x = 0.0
		elif state == PlayerState.SLIDE and not is_on_floor():
			_change_state(PlayerState.FALL)
		return
	if _is_wall_attached():
		if not is_on_floor() and velocity.y > 20.0:
			_change_state(PlayerState.WALL_SLIDE)
		elif absf(velocity.y) > 5.0:
			_change_state(PlayerState.WALL_CLIMB)
		else:
			_change_state(PlayerState.WALL_HANG)
		return
	if not is_on_floor():
		if velocity.y < -30.0:
			if state != PlayerState.JUMP:
				_change_state(PlayerState.JUMP)
		elif not jump_transition_started and velocity.y >= -30.0:
			jump_transition_started = true
			_change_state(PlayerState.JUMP_TRANSITION)
		elif state != PlayerState.JUMP_TRANSITION:
			_change_state(PlayerState.FALL)
		return
	if crouched:
		if not Input.is_action_pressed("crouch") and _has_headroom():
			crouched = false
			_change_state(PlayerState.LOCOMOTION)
		elif state not in [PlayerState.CROUCH, PlayerState.CROUCH_ATTACK]:
			_change_state(PlayerState.CROUCH)
	else:
		var input_x: float = Input.get_axis("left", "right")
		if Input.is_action_pressed("crouch"):
			crouched = true
			_change_state(PlayerState.CROUCH_TRANSITION)
		elif state == PlayerState.LOCOMOTION:
			if absf(input_x) > 0.01:
				_set_animation(&"run")
			else:
				_set_animation(&"idle")

func _sync_wall_facing() -> void:
	if state not in [PlayerState.WALL_HANG, PlayerState.WALL_CLIMB, PlayerState.WALL_SLIDE]:
		return
	var wall_normal: Vector2 = wall_contact_normal if absf(wall_contact_normal.x) > 0.1 else get_wall_normal()
	if absf(wall_normal.x) > 0.1:
		facing = 1 if -wall_normal.x > 0.0 else -1
		if state == PlayerState.WALL_SLIDE:
			animated_sprite.flip_h = facing >= 0
		else:
			animated_sprite.flip_h = facing < 0

func _play_landing_animation() -> void:
	if not animated_sprite.sprite_frames.has_animation(&"outofbattery"):
		_change_state(_locomotion_state())
		return
	menu_animation_lock = true
	animated_sprite.position.y = -16.0
	animated_sprite.play(&"outofbattery")
	_sync_special_animation_grounding()

func _update_animation() -> void:
	if menu_animation_lock:
		return
	if mantle_time > 0.0:
		animated_sprite.position.y = SPRITE_WALL_Y
		_set_animation(&"wallclimb_no_movement")
		return
	_sync_wall_facing()
	if state in [PlayerState.WALL_HANG, PlayerState.WALL_CLIMB, PlayerState.WALL_SLIDE]:
		animated_sprite.position.y = SPRITE_WALL_Y
	elif state in [PlayerState.CROUCH_TRANSITION, PlayerState.CROUCH, PlayerState.CROUCH_ATTACK, PlayerState.SLIDE_START, PlayerState.SLIDE, PlayerState.SLIDE_END]:
		animated_sprite.position.y = SPRITE_LOW_Y
	else:
		animated_sprite.position.y = SPRITE_STANDING_Y
	match state:
		PlayerState.LOCOMOTION:
			_set_animation(&"run" if absf(velocity.x) > 8.0 else &"idle")
		PlayerState.CROUCH:
			_set_animation(&"crouchwalk" if absf(velocity.x) > 8.0 else &"crouch")
		PlayerState.WALL_HANG:
			_set_animation(&"wallhang")
		PlayerState.WALL_CLIMB:
			_set_animation(&"wallclimb_no_movement")
		PlayerState.WALL_SLIDE:
			_set_animation(&"wallslide")
		PlayerState.FALL:
			_set_animation(&"fall")
		PlayerState.JUMP:
			_set_animation(&"jump")
		PlayerState.JUMP_TRANSITION:
			_set_animation(&"jump_fall_inbetween")
		PlayerState.HIT:
			_set_animation(&"hit")

func _change_state(next_state: PlayerState) -> void:
	if state == next_state:
		return
	var previous: PlayerState = state
	state = next_state
	state_time = 0.0
	if next_state in [PlayerState.ROLL, PlayerState.SLIDE_START, PlayerState.SLIDE]:
		invulnerable_time = ACTION_DURATION
		if next_state in [PlayerState.SLIDE_START, PlayerState.SLIDE]:
			slide_momentum_active = true
	elif previous in [PlayerState.ROLL, PlayerState.SLIDE_START, PlayerState.SLIDE]:
		invulnerable_time = 0.0
	if next_state != PlayerState.ATTACK1:
		if previous == PlayerState.ATTACK1 and next_state != PlayerState.ATTACK2:
			attack_queued = false
	if next_state in [PlayerState.HIT, PlayerState.DEATH, PlayerState.FALL]:
		attack_queued = false
	if next_state == PlayerState.CROUCH_TRANSITION:
		_set_animation(&"crouch_transition", true)
	elif next_state == PlayerState.ATTACK1:
		attack_id += 1
		attack_hitbox.set_meta("attack_id", attack_id)
		_set_animation(_movement_safe(&"attack", &"attack_no_movement"), true)
		_retrigger_attack_overlaps()
	elif next_state == PlayerState.ATTACK2:
		attack_id += 1
		attack_hitbox.set_meta("attack_id", attack_id)
		_set_animation(_movement_safe(&"attack2_no_movement", &"attack2"), true)
		_retrigger_attack_overlaps()
	elif next_state == PlayerState.ATTACK3:
		attack_id += 1
		attack_hitbox.set_meta("attack_id", attack_id)
		_set_animation(_movement_safe(&"attackcombo_no_movement", &"attackcombo"), true)
		_retrigger_attack_overlaps()
	elif next_state == PlayerState.GROUND_POUND:
		_set_animation(&"groundpound", true)
	elif next_state == PlayerState.GROUND_POUND_SLAM:
		_set_animation(&"groundpoundslam", true)
	elif next_state == PlayerState.CROUCH_ATTACK:
		attack_id += 1
		attack_hitbox.set_meta("attack_id", attack_id)
		_set_animation(&"crouchattack", true)
		_retrigger_attack_overlaps()
	elif next_state == PlayerState.TURN:
		animated_sprite.flip_h = turn_target_facing > 0
		_set_animation(&"turn_around", true)
	elif next_state == PlayerState.SLIDE_START:
		crouched = true
		_set_animation(&"slide_transitionstart", true)
	elif next_state == PlayerState.SLIDE:
		_set_animation(&"slide", true)
	elif next_state == PlayerState.SLIDE_END:
		_set_animation(&"idle", true)
	elif next_state == PlayerState.ROLL:
		_set_animation(&"roll", true)
	elif next_state == PlayerState.DASH:
		_set_animation(&"dash", true)
	elif next_state == PlayerState.HIT:
		hit_stun_time = HIT_STUN_DURATION
		_set_animation(&"hit", true)
	elif next_state == PlayerState.DEATH:
		dead = true
		velocity = Vector2.ZERO
		_set_animation(_movement_safe(&"death_no_movement", &"death"), true)
	gameplay_state_changed.emit(StringName(PlayerState.keys()[next_state].to_lower()))

func _sync_special_animation_grounding() -> void:
	match animated_sprite.animation:
		&"outofbattery":
			animated_sprite.position.y = -16.0
		&"chargemp3":
			animated_sprite.position.y = -36.0 if animated_sprite.frame >= 6 else -16.0
		&"chargingmp3":
			animated_sprite.position.y = -36.0
		&"stopchargingmp3":
			animated_sprite.position.y = -36.0 if animated_sprite.frame < 2 else -16.0
		&"shrug":
			animated_sprite.position = Vector2(0.0, SPRITE_STANDING_Y)

func _on_menu_frame_changed() -> void:
	if not menu_animation_lock or animated_sprite.animation != &"resume":
		return
	if animated_sprite.frame == 1:
		var frame_one_callback: Callable = menu_frame_one_callback
		menu_frame_one_callback = Callable()
		if frame_one_callback.is_valid():
			frame_one_callback.call()
	elif animated_sprite.frame == 2:
		var frame_two_callback: Callable = menu_frame_two_callback
		menu_frame_two_callback = Callable()
		if frame_two_callback.is_valid():
			frame_two_callback.call()

func _on_animation_finished() -> void:
	var finished: StringName = animated_sprite.animation
	if menu_animation_lock and finished == &"outofbattery":
		menu_animation_lock = false
		_change_state(_locomotion_state())
		return
	if menu_animation_lock and finished in [&"pause", &"resume"]:
		menu_animation_lock = false
		var callback: Callable = menu_animation_callback
		menu_animation_callback = Callable()
		if callback.is_valid():
			callback.call()
		return
	if state == PlayerState.ATTACK1 and finished in [&"attack", &"attack_no_movement"]:
		if attack_queued and combo_buffer_time > 0.0:
			attack_queued = false
			_change_state(PlayerState.ATTACK2)
		else:
			combo_link_time = COMBO_BUFFER_DURATION
			_change_state(_locomotion_state())
	elif state == PlayerState.ATTACK2 and finished in [&"attack2", &"attack2_no_movement"]:
		if attack_queued and combo_buffer_time > 0.0:
			attack_queued = false
			_change_state(PlayerState.ATTACK3)
		else:
			_change_state(_locomotion_state())
	elif state == PlayerState.ATTACK3 or state == PlayerState.CROUCH_ATTACK or state == PlayerState.GROUND_POUND_SLAM:
		_change_state(_locomotion_state())
	elif state == PlayerState.TURN:
		_change_state(_locomotion_state())
	elif state == PlayerState.CROUCH_TRANSITION:
		_change_state(PlayerState.CROUCH)
	elif state == PlayerState.SLIDE_START:
		_change_state(PlayerState.SLIDE)
	elif state == PlayerState.SLIDE_END:
		crouched = false
		_change_state(_locomotion_state())
		if absf(Input.get_axis("left", "right")) > 0.01:
			_set_animation(&"run", true)
	elif state == PlayerState.JUMP_TRANSITION:
		_change_state(PlayerState.FALL)
	elif state == PlayerState.ROLL:
		if state_time >= ACTION_DURATION:
			_change_state(_locomotion_state())
		else:
			animated_sprite.pause()
	elif state == PlayerState.DASH:
		if state_time >= DASH_DURATION:
			_change_state(_locomotion_state())
		else:
			animated_sprite.pause()
	elif state == PlayerState.DEATH:
		animated_sprite.pause()

func prepare_for_boss_cinematic() -> void:
	crouched = false
	slide_queued = false
	slide_momentum_active = false
	attack_queued = false
	velocity = Vector2.ZERO
	body_collision.shape = STANDING_SHAPE
	floor_snap_length = floor_snap_distance
	state = PlayerState.LOCOMOTION
	animated_sprite.position = Vector2(0.0, SPRITE_STANDING_Y)
	_set_animation(&"idle", true)
	if is_on_floor():
		global_position.y -= 2.0


func set_teleport_locked(locked: bool) -> void:
	teleport_locked = locked
	if locked:
		velocity = Vector2.ZERO

func begin_exit_run(speed: float) -> void:
	exit_run_active = true
	exit_run_speed = speed
	teleport_locked = false
	crouched = false
	dead = false
	facing = 1
	turn_target_facing = 1
	state = PlayerState.LOCOMOTION
	velocity = Vector2.ZERO
	animated_sprite.flip_h = false
	animated_sprite.position = Vector2(0.0, SPRITE_STANDING_Y)
	body_collision.shape = STANDING_SHAPE
	attack_shape.disabled = true
	attack_hitbox.monitoring = false
	_set_animation(&"run", true)

func _update_exit_run(delta: float) -> void:
	velocity.x = exit_run_speed
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y = minf(velocity.y + falling_gravity * delta, max_fall_speed)
	move_and_slide()
	animated_sprite.flip_h = false
	_set_animation(&"run")
	_sync_collision_shape()
	_update_animation()
	was_grounded = is_on_floor()

func begin_intro_run(distance: float, speed: float = 90.0) -> void:
	intro_run_active = true
	intro_run_remaining = maxf(0.0, distance)
	intro_run_speed = speed
	teleport_locked = false
	crouched = false
	dead = false
	facing = 1
	turn_target_facing = 1
	state = PlayerState.LOCOMOTION
	velocity = Vector2.ZERO
	animated_sprite.flip_h = false
	animated_sprite.position = Vector2(0.0, SPRITE_STANDING_Y)
	body_collision.shape = STANDING_SHAPE
	attack_shape.disabled = true
	attack_hitbox.monitoring = false
	_set_animation(&"run", true)

func _update_intro_run(delta: float) -> void:
	velocity.x = intro_run_speed
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y = minf(velocity.y + falling_gravity * delta, max_fall_speed)
	move_and_slide()
	intro_run_remaining -= absf(velocity.x) * delta
	animated_sprite.flip_h = false
	_set_animation(&"run")
	_sync_collision_shape()
	was_grounded = is_on_floor()
	if intro_run_remaining <= 0.0:
		intro_run_active = false
		velocity.x = 0.0
		_set_animation(&"idle")

func set_elevator_riding(active: bool) -> void:
	elevator_ride_active = active
	if not active:
		return
	crouched = false
	dead = false
	facing = 1
	turn_target_facing = 1
	velocity = Vector2.ZERO
	state = PlayerState.LOCOMOTION
	animated_sprite.flip_h = false
	animated_sprite.position = Vector2(0.0, SPRITE_STANDING_Y)
	body_collision.shape = STANDING_SHAPE
	attack_shape.disabled = true
	attack_hitbox.monitoring = false
	_set_animation(&"idle", true)

func play_cinematic_animation(animation_name: StringName) -> bool:
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return false
	velocity = Vector2.ZERO
	animated_sprite.position = Vector2(0.0, SPRITE_STANDING_Y)
	animated_sprite.play(animation_name)
	return true

func finish_cinematic_animation() -> void:
	animated_sprite.position = Vector2(0.0, SPRITE_STANDING_Y)
	_set_animation(&"idle", true)

func get_attack_level() -> int:
	return 2 if state == PlayerState.ATTACK2 else 1

func get_attack_damage() -> int:
	return (20 if state == PlayerState.ATTACK2 else 10) + attack_damage_bonus

func add_attack_damage(amount: int) -> void:
	attack_damage_bonus += amount

func add_move_speed_percent(percent: float) -> void:
	move_speed_multiplier *= 1.0 + percent

func add_max_health_percent(percent: float) -> void:
	var gain: int = maxi(1, roundi(max_health * percent))
	max_health = mini(max_health + gain, 12)
	health = mini(health + gain, max_health)
	health_changed.emit(health, max_health)

func apply_knockback(force: float, direction: float) -> void:
	velocity.x = direction * force

func apply_hitstop(duration: float) -> void:
	hit_stop_time = maxf(hit_stop_time, duration)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if dead or invulnerable_time > 0.0:
		return
	if area.is_in_group("environment_spike"):
		receive_hit(false)
		var spike_direction: float = signf(global_position.x - area.global_position.x)
		if is_zero_approx(spike_direction):
			spike_direction = -1.0 if area.global_position.x < global_position.x else 1.0
		apply_spike_bounce(260.0, spike_direction)
		return
	if area.is_in_group("enemy_weapon_hitbox"):
		receive_hit(false)
		var direction: float = signf(global_position.x - area.global_position.x)
		apply_knockback(180.0, direction)

func apply_spike_bounce(horizontal_force: float, direction: float) -> void:
	velocity.x = direction * horizontal_force
	velocity.y = -240.0

func _start_hit_freeze() -> void:
	if hit_freeze_active:
		return
	hit_freeze_active = true
	var previous_time_scale: float = Engine.time_scale
	Engine.time_scale = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	Engine.time_scale = previous_time_scale if previous_time_scale > 0.0 else 1.0
	hit_freeze_active = false

func _start_hit_slowdown() -> void:
	if hit_slowdown_active:
		return
	hit_slowdown_active = true
	Engine.time_scale = 0.65
	var timer: SceneTreeTimer = get_tree().create_timer(0.10, true, false, true)
	timer.timeout.connect(_end_hit_slowdown, CONNECT_ONE_SHOT)

func _end_hit_slowdown() -> void:
	Engine.time_scale = 1.0
	hit_slowdown_active = false

func receive_hit(lethal: bool = false) -> void:
	if dead or invulnerable_time > 0.0:
		return
	if dead:
		return
	invulnerable_time = HIT_INVULNERABILITY_DURATION
	_start_hit_freeze()
	if hurt_audio != null:
		hurt_audio.play()
	if lethal:
		health = 0
	else:
		health = maxi(0, health - 1)
	health_changed.emit(health, max_health)
	if health <= 0:
		_change_state(PlayerState.DEATH)
	else:
		_change_state(PlayerState.HIT)

func align_for_charging(socket_position: Vector2) -> void:
	facing = 1 if global_position.x <= socket_position.x else -1
	turn_target_facing = facing
	global_position = socket_position + Vector2(-14.0 * facing, 9.0)
	velocity = Vector2.ZERO
	animated_sprite.flip_h = facing < 0

func start_charging(duration: float, finished_callback: Callable = Callable()) -> void:
	if menu_animation_lock or dead:
		return
	charging_sequence_active = true
	menu_animation_lock = true
	animated_sprite.position.y = -16.0
	animated_sprite.play(&"chargemp3")
	_sync_special_animation_grounding()
	await animated_sprite.animation_finished
	if not charging_sequence_active:
		return
	animated_sprite.play(&"chargingmp3")
	await get_tree().create_timer(duration).timeout
	if not charging_sequence_active:
		return
	animated_sprite.play(&"stopchargingmp3")
	await animated_sprite.animation_finished
	charging_sequence_active = false
	menu_animation_lock = false
	_change_state(_locomotion_state())
	if finished_callback.is_valid():
		finished_callback.call()

func play_menu_animation(animation_name: StringName, callback: Callable = Callable(), frame_one_callback: Callable = Callable(), frame_two_callback: Callable = Callable()) -> bool:
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return false
	menu_animation_lock = true
	menu_animation_callback = callback
	menu_frame_one_callback = frame_one_callback
	menu_frame_two_callback = frame_two_callback
	if animation_name in [&"pause", &"paused", &"resume"]:
		animated_sprite.position.x = MENU_SPRITE_OFFSET_X
		animated_sprite.position.y = SPRITE_STANDING_Y + MENU_SPRITE_OFFSET_Y
	animated_sprite.play(animation_name)
	return true

func finish_menu_resume() -> void:
	animated_sprite.position.x = 0.0
	animated_sprite.position.y = SPRITE_STANDING_Y
	_set_animation(&"idle", true)

func _set_animation(animation_name: StringName, restart: bool = false) -> void:
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return
	if restart or animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)

func _movement_safe(preferred: StringName, fallback: StringName) -> StringName:
	if animated_sprite.sprite_frames.has_animation(preferred):
		return preferred
	return fallback

func _locomotion_state() -> PlayerState:
	return PlayerState.CROUCH if crouched else PlayerState.LOCOMOTION

func _can_start_attack() -> bool:
	return not dead and state not in [PlayerState.HIT, PlayerState.DEATH, PlayerState.ATTACK1, PlayerState.ATTACK2, PlayerState.ATTACK3, PlayerState.ROLL, PlayerState.DASH, PlayerState.TURN]

func _can_start_dodge() -> bool:
	return not dead and state not in [PlayerState.HIT, PlayerState.DEATH, PlayerState.ATTACK1, PlayerState.ATTACK2, PlayerState.ATTACK3, PlayerState.ROLL, PlayerState.DASH]

func _can_jump() -> bool:
	return not dead and (is_on_floor() or coyote_time > 0.0 or _is_wall_attached()) and state not in [PlayerState.ATTACK1, PlayerState.ATTACK2, PlayerState.HIT, PlayerState.DEATH, PlayerState.ROLL, PlayerState.DASH]

func _is_wall_attached() -> bool:
	return is_on_wall() and not is_on_floor()

func _sync_collision_shape() -> void:
	body_collision.shape = CROUCH_SHAPE if crouched else STANDING_SHAPE
	var attack_active: bool = state in [PlayerState.ATTACK1, PlayerState.ATTACK2, PlayerState.ATTACK3, PlayerState.CROUCH_ATTACK]
	attack_shape.disabled = not attack_active
	attack_hitbox.monitoring = attack_active
	attack_hitbox.position.x = 22.0 * facing
	var ground_pound_active: bool = state == PlayerState.GROUND_POUND_SLAM and animated_sprite.frame == 1
	ground_pound_shape.set_deferred("disabled", not ground_pound_active)
	ground_pound_hitbox.set_deferred("monitoring", ground_pound_active)

func _retrigger_attack_overlaps() -> void:
	# A new attack must always register against enemies already inside the hitbox.
	# Combos keep the hitbox enabled between swings, so the engine never re-emits
	# area_entered; re-emit it ourselves for every currently overlapping hurtbox.
	if not attack_hitbox.monitoring:
		return
	for area: Area2D in attack_hitbox.get_overlapping_areas():
		area.area_entered.emit(attack_hitbox)

func _has_headroom() -> bool:
	if not crouched:
		return true
	return not test_move(global_transform, Vector2(0.0, -24.0))

func _validate_animations() -> void:
	var missing: Array[StringName] = []
	for animation_name: StringName in REQUIRED_ANIMATIONS:
		if not animated_sprite.sprite_frames.has_animation(animation_name):
			missing.append(animation_name)
	if not missing.is_empty():
		push_warning("PlayerController missing animations: %s" % missing)
	for animation_name: StringName in EXPECTED_FRAME_COUNTS:
		if animated_sprite.sprite_frames.has_animation(animation_name):
			var expected_count: int = EXPECTED_FRAME_COUNTS[animation_name] as int
			var actual_count: int = animated_sprite.sprite_frames.get_frame_count(animation_name)
			if actual_count != expected_count:
				push_warning("Animation %s has %d frames; imported resource expectation is %d" % [animation_name, actual_count, expected_count])
