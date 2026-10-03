extends Area2D
class_name Elevator

const CABLE_SCENE: PackedScene = preload("res://scenes/elevatorcable.tscn")
const VACUUM_SOUND: AudioStream = preload("res://assets/sounds/vaccum.mp3")

@export var tiles_per_second: float = 14.0
@export var tile_size: float = 16.0
@export var cable_top_global_y: float = 0.0
@export var base_volume_db: float = -4.0
@export var pulley_pitch_scale: float = 2.0
@export var pulley_volume_db: float = -11.0
## Startup rides need no lever: the platform starts rising as soon as the player
## is standing on it (used by the intro elevator that lifts the knight in).
@export var auto_start: bool = false
## Park the platform at stop_global_y instead of rising forever.
@export var stop_at_global_y: bool = false
@export var stop_global_y: float = 0.0
## Keep the last rider reference after stopping so a nearby lever can start another leg.
@export var retain_rider_at_stop: bool = false

var lever: CaveLever = null
var platform: TileMapLayer = null
var rider: PlayerController = null
var activated: bool = false
var pending_activation: bool = false
var cables: Array[AnimatedSprite2D] = []
var audio: AudioStreamPlayer = null
var pulley_fade_tween: Tween = null
var startup_audio_delay_pending: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_rider_entered)
	body_exited.connect(_on_rider_exited)
	lever = get_node_or_null("elevatorlever") as CaveLever
	platform = get_node_or_null("elevatorplatform") as TileMapLayer
	if lever != null:
		lever.flipped.connect(_on_lever_flipped)
	_build_cables()
	_setup_audio()
	if auto_start:
		call_deferred("_grab_initial_rider")

func _build_cables() -> void:
	var cable_parent: Node2D = Node2D.new()
	cable_parent.name = "Cables"
	add_child(cable_parent)
	var platform_top_y: float = global_position.y
	var span: float = platform_top_y - cable_top_global_y
	var count: int = maxi(1, int(ceil(span / tile_size)) + 1)
	for i: int in range(count):
		var cable: AnimatedSprite2D = CABLE_SCENE.instantiate() as AnimatedSprite2D
		cable.position = Vector2(0.0, -8.0 - float(i) * tile_size)
		cable.play(&"idle")
		cable_parent.add_child(cable)
		cables.append(cable)
	_update_cables()

func _setup_audio() -> void:
	audio = AudioStreamPlayer.new()
	audio.name = "PulleySound"
	audio.stream = VACUUM_SOUND
	if audio.stream is AudioStreamMP3:
		(audio.stream as AudioStreamMP3).loop = true
	audio.volume_db = base_volume_db
	audio.pitch_scale = 1.0
	add_child(audio)

## The pulley only turns once the lever has been switched and the player is
## actually riding, so the sound never loops while the elevator sits idle.
func _update_pulley_sound() -> void:
	if audio == null:
		return
	var riding: bool = activated and rider != null and is_instance_valid(rider)
	if riding:
		_start_pulley_sound()
		if not audio.playing:
			if auto_start:
				if not startup_audio_delay_pending:
					startup_audio_delay_pending = true
					_startup_audio_after_delay()
			else:
				audio.play()
	elif audio.playing:
		audio.stop()

func _startup_audio_after_delay() -> void:
	await get_tree().create_timer(1.0).timeout
	startup_audio_delay_pending = false
	if audio != null and activated and rider != null and is_instance_valid(rider) and not audio.playing:
		audio.play()

func _on_rider_entered(body: Node2D) -> void:
	var entered: PlayerController = body as PlayerController
	if entered != null:
		rider = entered
		_update_pulley_sound()

func _on_rider_exited(body: Node2D) -> void:
	if body == rider:
		rider = null
		_update_pulley_sound()

## The cable stack hangs from the shaft ceiling: cables that would poke above the
## anchor as the platform climbs are hidden, so the stack always appears to be
## anchored to the same point instead of sliding up with the platform.
func _update_cables() -> void:
	for cable: AnimatedSprite2D in cables:
		if not is_instance_valid(cable):
			continue
		cable.visible = cable.global_position.y - tile_size * 0.5 >= cable_top_global_y

## Startup rides find the player already standing on the platform, so
## body_entered may never fire for them.
func _grab_initial_rider() -> void:
	if rider != null:
		return
	for body: Node2D in get_overlapping_bodies():
		var player: PlayerController = body as PlayerController
		if player != null:
			_on_rider_entered(player)
			return

## Levels whose lever stands next to the platform instead of inside the elevator
## hand it over here; otherwise the elevator only looks for an "elevatorlever"
## child of its own.
func set_lever(new_lever: CaveLever) -> void:
	if new_lever == null or new_lever == lever:
		return
	if lever != null and lever.flipped.is_connected(_on_lever_flipped):
		lever.flipped.disconnect(_on_lever_flipped)
	lever = new_lever
	if not lever.flipped.is_connected(_on_lever_flipped):
		lever.flipped.connect(_on_lever_flipped)

func _on_lever_flipped() -> void:
	pending_activation = true
	_try_activate()

func _try_activate() -> void:
	if activated or rider == null:
		return
	if not pending_activation and not auto_start:
		return
	activated = true
	rider.set_elevator_riding(true)
	_set_cables_active(true)
	_update_cables()
	_update_pulley_sound()

func _set_cables_active(active: bool) -> void:
	for cable: AnimatedSprite2D in cables:
		if is_instance_valid(cable):
			cable.play(&"active" if active else &"idle")

func fade_out_pulley_sound(duration: float) -> void:
	if audio == null or not audio.playing:
		return
	if is_instance_valid(pulley_fade_tween) and pulley_fade_tween.is_running():
		pulley_fade_tween.kill()
	pulley_fade_tween = create_tween()
	pulley_fade_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulley_fade_tween.tween_property(audio, "volume_db", -60.0, maxf(0.01, duration))
	pulley_fade_tween.tween_callback(audio.stop)

func _start_pulley_sound() -> void:
	if audio == null:
		return
	if is_instance_valid(pulley_fade_tween) and pulley_fade_tween.is_running():
		pulley_fade_tween.kill()
	pulley_fade_tween = null
	audio.pitch_scale = pulley_pitch_scale
	audio.volume_db = pulley_volume_db

## Drives the pulley and cable visuals for scripted rides without registering a
## gameplay rider or activating the elevator's lever-controlled movement.
func set_cinematic_motion(active: bool) -> void:
	if active:
		_set_cables_active(true)
		_start_pulley_sound()
		if audio != null and not audio.playing:
			audio.play()
	else:
		_set_cables_active(false)
		if not activated and audio != null and audio.playing:
			audio.stop()

func is_active() -> bool:
	return activated

## A finished ride parks the platform and hands control back to the player.
func _finish_ride() -> void:
	activated = false
	auto_start = false
	_set_cables_active(false)
	var leaving: PlayerController = rider
	if not retain_rider_at_stop:
		rider = null
	if leaving != null and is_instance_valid(leaving):
		leaving.set_elevator_riding(false)
	_update_pulley_sound()

func _physics_process(delta: float) -> void:
	if not activated:
		if (pending_activation or auto_start) and rider != null:
			_try_activate()
		return
	var target_y: float = global_position.y - tiles_per_second * tile_size * delta
	var reached_stop: bool = stop_at_global_y and target_y <= stop_global_y
	if reached_stop:
		target_y = stop_global_y
	var step: float = global_position.y - target_y
	global_position.y = target_y
	if rider != null and is_instance_valid(rider):
		rider.global_position.y -= step
	_update_cables()
	if reached_stop:
		_finish_ride()