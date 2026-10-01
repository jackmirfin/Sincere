extends Node2D
class_name CaveIntroSequence

const OPENING_ZOOM: Vector2 = Vector2(6.6, 6.6)
const GAME_ZOOM: Vector2 = Vector2(3.3, 3.3)
const DASH_DURATION: float = 0.24
const STOP_DURATION: float = 0.08
const MAX_DROP_WAIT: float = 4.0
const ROUTE: Array[NodePath] = [
	NodePath("bossfight/evilwizard"),
	NodePath("rooms_gates/endgate"),
	NodePath("interactables/lever"),
	NodePath("interactables/lever2"),
	NodePath("interactables/lever3"),
]

var sequence_running: bool = false
var sequence_finished: bool = false
var player_dropped: bool = false
var pause_started: bool = false
var resume_started: bool = false
var following_player: bool = false
var completed_stops: Array[NodePath] = []
var cinematic_camera: Camera2D = null
var player: PlayerController = null
var player_camera: Camera2D = null
var original_limit_top: int = 0
var original_limit_bottom: int = 0

func _enter_tree() -> void:
	var pause_menu: PauseMenu = get_node_or_null("PauseLayer/PauseMenu") as PauseMenu
	if pause_menu != null:
		pause_menu.skip_startup_sequence = true

func _ready() -> void:
	player = get_node_or_null("knight") as PlayerController
	if player != null:
		player_camera = player.get_node_or_null("Camera2D") as Camera2D
		if player_camera != null:
			player_camera.zoom = OPENING_ZOOM
			original_limit_top = player_camera.limit_top
			original_limit_bottom = player_camera.limit_bottom
	call_deferred("play_opening_camera_sequence")

func _process(_delta: float) -> void:
	if following_player and is_instance_valid(cinematic_camera) and is_instance_valid(player):
		cinematic_camera.global_position = player.global_position + player_camera.position

func play_opening_camera_sequence() -> void:
	if sequence_running or sequence_finished:
		return
	sequence_running = true
	if player == null or player_camera == null:
		sequence_running = false
		sequence_finished = true
		return
	player.set_teleport_locked(true)
	player_camera.limit_top = -500
	player_camera.limit_bottom = 5000
	player_camera.position_smoothing_enabled = false
	player_camera.make_current()
	if cinematic_camera == null:
		cinematic_camera = Camera2D.new()
		cinematic_camera.name = "CaveOpeningCamera"
		cinematic_camera.zoom = OPENING_ZOOM
		cinematic_camera.position_smoothing_enabled = false
		cinematic_camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
		cinematic_camera.limit_left = -500
		cinematic_camera.limit_top = -500
		cinematic_camera.limit_right = 6000
		cinematic_camera.limit_bottom = 5000
		add_child(cinematic_camera)
	cinematic_camera.global_position = player_camera.get_screen_center_position()
	cinematic_camera.make_current()
	following_player = true
	var music: AudioStreamPlayer = get_node_or_null("BackgroundMusic") as AudioStreamPlayer
	if music != null:
		music.stream_paused = true
		music.stop()
	var drop_timer: SceneTreeTimer = get_tree().create_timer(MAX_DROP_WAIT)
	while is_instance_valid(player) and not player.is_on_floor() and drop_timer.time_left > 0.0:
		await get_tree().physics_frame
	player_dropped = is_instance_valid(player) and player.is_on_floor()
	following_player = false
	if not is_instance_valid(player):
		sequence_running = false
		sequence_finished = true
		return
	for target_path: NodePath in ROUTE:
		var target: Node2D = get_node_or_null(target_path) as Node2D
		if target == null:
			continue
		var dash: Tween = create_tween()
		dash.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		dash.tween_property(cinematic_camera, "global_position", _camera_target_position(target), DASH_DURATION)
		await dash.finished
		completed_stops.append(target_path)
		await get_tree().create_timer(STOP_DURATION).timeout
	var return_dash: Tween = create_tween()
	return_dash.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	return_dash.tween_property(cinematic_camera, "global_position", player.global_position + player_camera.position, DASH_DURATION)
	await return_dash.finished
	player_camera.limit_top = original_limit_top
	player_camera.limit_bottom = original_limit_bottom
	player_camera.position_smoothing_enabled = true
	player_camera.zoom = OPENING_ZOOM
	player_camera.make_current()
	player.set_teleport_locked(false)
	cinematic_camera.queue_free()
	cinematic_camera = null
	pause_started = true
	var played_pause: bool = player.play_menu_animation(&"pause", Callable(self, "_start_resume"))
	if not played_pause:
		_start_resume()
	sequence_running = false
	sequence_finished = true

func _camera_target_position(target: Node2D) -> Vector2:
	if target is CaveGate:
		var gate: CaveGate = target as CaveGate
		var collision: CollisionShape2D = gate.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision != null:
			return collision.global_position
	return target.global_position

func _start_resume() -> void:
	resume_started = true
	if not is_instance_valid(player):
		return
	var played_resume: bool = player.play_menu_animation(&"resume", Callable(self, "_finish_resume"), Callable(self, "_start_music"), Callable(self, "_zoom_out"))
	if not played_resume:
		_start_music()
		_finish_resume()

func _start_music() -> void:
	var music: AudioStreamPlayer = get_node_or_null("BackgroundMusic") as AudioStreamPlayer
	if music != null:
		music.stream_paused = false
		music.play()

func _zoom_out() -> void:
	if not is_instance_valid(player_camera):
		return
	var zoom_tween: Tween = create_tween()
	zoom_tween.tween_property(player_camera, "zoom", GAME_ZOOM, 0.6)

func _finish_resume() -> void:
	if not is_instance_valid(player):
		return
	player.finish_menu_resume()
	player.set_teleport_locked(false)
