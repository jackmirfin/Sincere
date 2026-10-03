extends Node2D
class_name TwilightCave

signal opening_camera_returned_to_player


## The opening ride starts below the level art, so the camera has to follow the
## knight down the shaft; 800 keeps the whole ride in view while the level art
## still covers everything the camera can reach.
const CAMERA_LIMIT_BOTTOM: float = 800.0
## The roof elevator parks flush with the end-gate room's roof, so the camera
## needs headroom above the level's ceiling to keep the knight on screen.
const CAMERA_LIMIT_TOP: float = -48.0
## The intro elevator rises from the knight's feet to the level's lower walkway.
const ELEVATOR_STOP_Y: float = 592.0
## Underside of the scaffold cap the pulley hangs from.
const CABLE_ANCHOR_Y: float = 528.0
## The second elevator lifts the knight out of the end-gate room: it climbs from
## the room floor and parks flush with the ceiling hatch it rises through.
const ROOF_ELEVATOR_STOP_Y: float = -160.0
const COIN_MAGNET_RADIUS: float = 88.0
const KING_SCENE: PackedScene = preload("res://scenes/king.tscn")
const KING_ROOT_ABOVE_PLATFORM: float = 12.0
const CUTSCENE_DASH_DURATION: float = 0.92
const CUTSCENE_STOP_DURATION: float = 0.3
const KING_TELEPORT_REVEAL_LEAD: float = 0.2
const KING_EXIT_DURATION: float = 3.8
const KING_BOARD_DURATION: float = 0.92
const PULLEY_FADE_OUT_DURATION: float = 1.5
const TWILIGHT_MUSIC_A: AudioStream = preload("res://assets/sounds/twilighta.mp3")
const TWILIGHT_MUSIC_B: AudioStream = preload("res://assets/sounds/twilightb.mp3")
## The room the end gate seals off. It stays shut while any living enemy is in it.
const ENDGATE_ROOM: Rect2 = Rect2(64.0, 16.0, 1072.0, 160.0)
## Teleporter receivers are named after the teleporter that owns them.
const RECEIVER_PREFIX: String = "teleporterreceiver"
const ENEMY_GROUP: String = "enemy"
const PROGRESSION_INTERVAL: float = 0.15

@onready var lever1: CaveLever = get_node_or_null("interactables/lever1") as CaveLever
@onready var lever2: CaveLever = get_node_or_null("interactables/lever2") as CaveLever
@onready var lever3: CaveLever = get_node_or_null("interactables/lever3") as CaveLever
@onready var gate1: CaveGate = get_node_or_null("interactables/gate1") as CaveGate
@onready var gate2: CaveGate = get_node_or_null("interactables/gate2") as CaveGate
@onready var gate3: CaveGate = get_node_or_null("interactables/gate3") as CaveGate
@onready var endgate: CaveGate = get_node_or_null("interactables/endgate") as CaveGate
@onready var roof_elevator: Elevator = get_node_or_null("elevators/elevator2") as Elevator

var evaluation_time: float = 0.0
var background_music: AudioStreamPlayer = null
var twilight_a_music: AudioStreamPlayer = null
var twilight_music_started: bool = false
var twilight_a_started: bool = false
var opening_sequence_running: bool = false
var king_teleport_animation_finished: bool = false

func _enter_tree() -> void:
	var pause_menu: PauseMenu = get_node_or_null("PauseLayer/PauseMenu") as PauseMenu
	if pause_menu != null:
		pause_menu.skip_startup_sequence = true
	# Elevator settings are applied from code because authoring exported values
	# as .tscn property overrides is dropped by the scene serializer. This runs
	# before each elevator's _ready(), which is where the cables are built.
	_configure_intro_elevator()
	_configure_roof_elevator()

func _ready() -> void:
	# Configure this level's own knight: a player left over from the previous
	# scene must never be the one the camera limits are applied to.
	var player: PlayerController = get_node_or_null("knight") as PlayerController
	if player != null:
		_configure_camera(player)
	_link_teleporters()
	# The lever that starts the roof ride stands beside the platform instead of
	# inside the elevator, so the elevator is handed it here.
	if roof_elevator != null and lever3 != null:
		roof_elevator.set_lever(lever3)
	if lever1 != null:
		lever1.flipped.connect(evaluate_progression)
	if lever2 != null:
		lever2.flipped.connect(evaluate_progression)
	evaluate_progression()
	_setup_background_music()
	call_deferred("play_opening_sequence")

func _process(delta: float) -> void:
	evaluation_time -= delta
	if evaluation_time > 0.0:
		return
	evaluation_time = PROGRESSION_INTERVAL
	evaluate_progression()

## Lever 1 opens gates 1 and 2, lever 2 opens gate 3, and the end gate opens once
## the room around it holds no living enemy. Polled as well as driven by the
## levers' signals, so a gate still opens when an enemy dies out of view.
func evaluate_progression() -> void:
	if lever1 != null and lever1.flipped_state:
		_open_gate(gate1)
		_open_gate(gate2)
	if lever2 != null and lever2.flipped_state:
		_open_gate(gate3)
	if _endgate_room_cleared():
		_open_gate(endgate)

func _open_gate(gate: CaveGate) -> void:
	if gate != null:
		gate.open_gate()

func _endgate_room_cleared() -> bool:
	for node: Node in get_tree().get_nodes_in_group(ENEMY_GROUP):
		var enemy: Node2D = node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.get("dead") == true:
			continue
		if ENDGATE_ROOM.has_point(enemy.global_position):
			return false
	return true

## Every teleporter sends the player to the receiver node it owns. Several were
## copied from one another and all pointed at the same receiver, which sent every
## ride to a single spot.
func _link_teleporters() -> void:
	var interactables: Node = get_node_or_null("interactables")
	if interactables == null:
		return
	for child: Node in interactables.get_children():
		var teleporter: Teleporter = child as Teleporter
		if teleporter == null:
			continue
		var receiver: Node2D = _own_receiver(teleporter)
		if receiver != null:
			teleporter.receiver_path = teleporter.get_path_to(receiver)

func _own_receiver(teleporter: Teleporter) -> Node2D:
	for child: Node in teleporter.get_children():
		var receiver: Node2D = child as Node2D
		if receiver != null and String(child.name).begins_with(RECEIVER_PREFIX):
			return receiver
	return null

func _setup_background_music() -> void:
	background_music = AudioStreamPlayer.new()
	background_music.name = "BackgroundMusic"
	background_music.stream = TWILIGHT_MUSIC_B
	background_music.pitch_scale = 0.86
	background_music.volume_db = -6.0
	background_music.finished.connect(_on_background_music_finished)
	add_child(background_music)

	twilight_a_music = AudioStreamPlayer.new()
	twilight_a_music.name = "TwilightAMusic"
	twilight_a_music.stream = TWILIGHT_MUSIC_A
	twilight_a_music.pitch_scale = 0.86
	twilight_a_music.volume_db = -9.0
	twilight_a_music.finished.connect(_on_twilight_a_music_finished)
	add_child(twilight_a_music)

func play_opening_sequence() -> void:
	if opening_sequence_running:
		return
	opening_sequence_running = true
	var player: PlayerController = get_node_or_null("knight") as PlayerController
	var player_camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D if player != null else null
	if player == null or player_camera == null:
		opening_sequence_running = false
		return
	background_music.stop()
	var intro_elevator: Elevator = get_node("elevators/elevator") as Elevator
	while is_instance_valid(player) and intro_elevator.global_position.y > ELEVATOR_STOP_Y:
		await get_tree().process_frame
	if not is_instance_valid(player):
		opening_sequence_running = false
		return

	player.set_teleport_locked(true)
	var cinematic_camera: Camera2D = Camera2D.new()
	cinematic_camera.name = "TwilightOpeningCamera"
	cinematic_camera.position_smoothing_enabled = false
	cinematic_camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	cinematic_camera.limit_enabled = true
	cinematic_camera.limit_left = player_camera.limit_left
	cinematic_camera.limit_right = player_camera.limit_right
	cinematic_camera.zoom = player_camera.zoom
	add_child(cinematic_camera)
	cinematic_camera.global_position = player.global_position + player_camera.position
	cinematic_camera.make_current()

	var roof: Elevator = roof_elevator
	var king: CharacterBody2D = KING_SCENE.instantiate() as CharacterBody2D
	var start_y: float = roof.global_position.y if roof != null else 0.0
	var start_monitoring: bool = roof.monitoring if roof != null else false
	if roof != null and king != null:
		var gate_targets: Array[CaveGate] = [gate1, gate2, gate3]
		var king_sprite: AnimatedSprite2D = null
		for gate: CaveGate in gate_targets:
			if gate == null:
				continue
			if gate == gate3:
				var final_gate_pan: Tween = _create_cutscene_camera_pan(cinematic_camera, gate.global_position, CUTSCENE_DASH_DURATION)
				await final_gate_pan.finished
				king_sprite = _prepare_king_for_teleport(king, roof)
			else:
				await _pan_cutscene_camera(cinematic_camera, gate.global_position, CUTSCENE_DASH_DURATION)
			await get_tree().create_timer(CUTSCENE_STOP_DURATION).timeout

		if king_sprite == null:
			king_sprite = _prepare_king_for_teleport(king, roof)
		var lever_focus: Vector2 = lever3.global_position if lever3 != null else king.global_position
		var lever_pan_duration: float = _cutscene_camera_pan_duration(cinematic_camera, lever_focus, CUTSCENE_DASH_DURATION)
		var camera_reveal_time: float = _camera_pan_time_to_reveal_position(cinematic_camera, cinematic_camera.global_position, lever_focus, king.global_position, lever_pan_duration)
		var teleport_start_delay: float = clampf(camera_reveal_time - KING_TELEPORT_REVEAL_LEAD, 0.0, maxf(0.0, lever_pan_duration - 0.1))
		var lever_pan: Tween = _create_cutscene_camera_pan(cinematic_camera, lever_focus, CUTSCENE_DASH_DURATION)
		king_teleport_animation_finished = false
		king_sprite.animation_finished.connect(_on_king_teleport_animation_finished)
		await get_tree().create_timer(teleport_start_delay).timeout
		king_sprite.play(&"teleport")
		await lever_pan.finished
		if not king_teleport_animation_finished:
			await king_sprite.animation_finished
		king_sprite.animation_finished.disconnect(_on_king_teleport_animation_finished)
		king_sprite.play(&"idle")
		await get_tree().create_timer(CUTSCENE_STOP_DURATION).timeout
		king_sprite.play(&"walk")
		var boarding: Tween = create_tween()
		boarding.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		boarding.tween_property(king, "global_position:x", roof.global_position.x, KING_BOARD_DURATION)
		await boarding.finished
		king_sprite.play(&"idle")
		await get_tree().create_timer(CUTSCENE_STOP_DURATION).timeout
		if lever3 != null and not lever3.flipped_state:
			lever3.flip()
			while not lever3.flipped_state:
				await get_tree().process_frame

		# The elevator only departs after the lever's full flip animation.
		roof.monitoring = false
		roof.set_cinematic_motion(true)
		var departure: Tween = create_tween().set_parallel(true)
		departure.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		departure.tween_property(roof, "global_position:y", ROOF_ELEVATOR_STOP_Y, KING_EXIT_DURATION)
		departure.tween_property(king, "global_position:y", ROOF_ELEVATOR_STOP_Y - KING_ROOT_ABOVE_PLATFORM, KING_EXIT_DURATION)
		await departure.finished
		while is_instance_valid(king) and not _king_is_offscreen_above(king, cinematic_camera):
			await get_tree().process_frame
		king.queue_free()

	var return_position: Vector2 = player.global_position + player_camera.position
	if roof != null:
		roof.fade_out_pulley_sound(PULLEY_FADE_OUT_DURATION)
	await _pan_cutscene_camera(cinematic_camera, return_position, CUTSCENE_DASH_DURATION)
	# Do not park/reset the cinematic lift while the camera is still showing it.
	opening_camera_returned_to_player.emit()
	if roof != null:
		roof.set_cinematic_motion(false)
		roof.global_position.y = start_y
		roof.activated = false
		roof.pending_activation = false
		roof.auto_start = false
		roof._update_cables()
		roof.monitoring = start_monitoring
	if lever3 != null:
		lever3.reset_to_unflipped()

	cinematic_camera.queue_free()
	player_camera.make_current()
	player.set_teleport_locked(false)
	var pause_played: bool = player.play_menu_animation(&"pause", Callable(self, "_start_intro_resume"))
	if not pause_played:
		_start_intro_resume()
	opening_sequence_running = false

func _prepare_king_for_teleport(king: CharacterBody2D, roof: Elevator) -> AnimatedSprite2D:
	add_child(king)
	var light_parallax: Parallax2D = get_node_or_null("LightParallax") as Parallax2D
	if light_parallax != null:
		move_child(king, light_parallax.get_index())
	var king_sprite: AnimatedSprite2D = king.get_node("AnimatedSprite2D") as AnimatedSprite2D
	# Start just off the platform; the King walks left onto it instead of appearing already aboard.
	king.global_position = roof.global_position + Vector2(90.0, -KING_ROOT_ABOVE_PLATFORM)
	king_sprite.flip_h = true
	king_sprite.play(&"idle")
	return king_sprite

func _cutscene_camera_pan_duration(camera: Camera2D, target: Vector2, minimum_duration: float) -> float:
	var travel_time: float = maxf(minimum_duration, camera.global_position.distance_to(target) / 1100.0)
	return minf(travel_time, 1.65)

func _on_king_teleport_animation_finished() -> void:
	king_teleport_animation_finished = true

func _cutscene_viewport_size(camera: Camera2D) -> Vector2:
	var viewport_size: Vector2 = camera.get_viewport().get_visible_rect().size
	if viewport_size.x < 320.0 or viewport_size.y < 180.0:
		var configured_width: float = float(ProjectSettings.get_setting("display/window/size/viewport_width", 1152))
		var configured_height: float = float(ProjectSettings.get_setting("display/window/size/viewport_height", 648))
		viewport_size = Vector2(configured_width, configured_height)
	return viewport_size

func _camera_pan_time_to_reveal_position(camera: Camera2D, start: Vector2, target: Vector2, point: Vector2, duration: float) -> float:
	var viewport_size: Vector2 = _cutscene_viewport_size(camera)
	var half_view_size: Vector2 = viewport_size / (camera.zoom * 2.0)
	var x_reveal_center: float = point.x + half_view_size.x if start.x > point.x else point.x - half_view_size.x
	var y_reveal_center: float = point.y + half_view_size.y if start.y > point.y else point.y - half_view_size.y
	var x_time: float = _camera_pan_time_for_axis(start.x, target.x, x_reveal_center, duration)
	var y_time: float = _camera_pan_time_for_axis(start.y, target.y, y_reveal_center, duration)
	return maxf(x_time, y_time)

func _camera_pan_time_for_axis(start: float, target: float, reveal_center: float, duration: float) -> float:
	var travel: float = target - start
	if is_zero_approx(travel):
		return 0.0
	var progress: float = clampf((reveal_center - start) / travel, 0.0, 1.0)
	return duration * acos(1.0 - 2.0 * progress) / PI

func _pan_cutscene_camera(camera: Camera2D, target: Vector2, minimum_duration: float) -> void:
	var pan: Tween = _create_cutscene_camera_pan(camera, target, minimum_duration)
	await pan.finished

func _create_cutscene_camera_pan(camera: Camera2D, target: Vector2, minimum_duration: float) -> Tween:
	var travel_time: float = _cutscene_camera_pan_duration(camera, target, minimum_duration)
	var pan: Tween = create_tween()
	pan.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pan.tween_property(camera, "global_position", target, travel_time)
	return pan

func _king_is_offscreen_above(king: CharacterBody2D, camera: Camera2D) -> bool:
	var king_sprite: AnimatedSprite2D = king.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if king_sprite == null or king_sprite.sprite_frames == null:
		return king.global_position.y < camera.get_screen_center_position().y
	var frame_texture: Texture2D = king_sprite.sprite_frames.get_frame_texture(king_sprite.animation, king_sprite.frame)
	var king_bottom: float = king.global_position.y + frame_texture.get_height() * 0.5
	var viewport_height: float = get_viewport().get_visible_rect().size.y
	var view_top: float = camera.get_screen_center_position().y - viewport_height / (2.0 * camera.zoom.y)
	return king_bottom < view_top

func _start_intro_resume() -> void:
	var player: PlayerController = get_node_or_null("knight") as PlayerController
	if player == null:
		return
	var resumed: bool = player.play_menu_animation(&"resume", Callable(), Callable(self, "_start_twilight_music"))
	if not resumed:
		_start_twilight_music()

func _start_twilight_music() -> void:
	if background_music == null or background_music.playing:
		return
	if not twilight_music_started:
		background_music.stream = TWILIGHT_MUSIC_B
		twilight_music_started = true
	background_music.play()

func _on_background_music_finished() -> void:
	if background_music == null or not twilight_music_started:
		return
	if not twilight_a_started and twilight_a_music != null:
		twilight_a_started = true
		twilight_a_music.play()
	background_music.play()

func _on_twilight_a_music_finished() -> void:
	if twilight_a_music == null or not twilight_a_started:
		return
	twilight_a_music.play()

func _configure_intro_elevator() -> void:
	var elevator: Elevator = get_node_or_null("elevators/elevator") as Elevator
	if elevator == null:
		return
	elevator.auto_start = true
	elevator.stop_at_global_y = true
	elevator.stop_global_y = ELEVATOR_STOP_Y
	elevator.cable_top_global_y = CABLE_ANCHOR_Y

func _configure_roof_elevator() -> void:
	var elevator: Elevator = get_node_or_null("elevators/elevator2") as Elevator
	if elevator == null:
		return
	elevator.stop_at_global_y = true
	elevator.stop_global_y = ROOF_ELEVATOR_STOP_Y
	elevator.cable_top_global_y = ROOF_ELEVATOR_STOP_Y

func _configure_camera(player: Node) -> void:
	# The knight is raised into the level on the intro elevator, so the camera
	# follows him below the knight scene's default bottom limit; the roof ride
	# needs the same headroom above the level's ceiling.
	var cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	cam.limit_bottom = int(CAMERA_LIMIT_BOTTOM)
	cam.limit_top = int(CAMERA_LIMIT_TOP)