extends Node2D
class_name World2Entry

const ENTRY_RUN_SPEED: float = 202.0
const ENTRY_OFFSCREEN_MARGIN: float = 48.0
const ENTRY_START_ZOOM: Vector2 = Vector2(6.6, 6.6)
const GAMEPLAY_ZOOM: Vector2 = Vector2(3.3, 3.3)
const ENTRY_ZOOM_OUT_DURATION: float = 1.0

var entry_camera: Camera2D = null
var entry_started: bool = false

func _ready() -> void:
	call_deferred("_run_entry")

func _run_entry() -> void:
	if entry_started:
		return
	var player: PlayerController = get_node_or_null("knight") as PlayerController
	if player == null:
		return
	var player_camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if player_camera == null:
		return
	var pause_menu: Node = get_node_or_null("PauseLayer/PauseMenu")
	if pause_menu != null and pause_menu.has_method("set_startup_sequence_enabled"):
		pause_menu.call("set_startup_sequence_enabled", false)
	entry_started = true
	var spawn_position: Vector2 = player.global_position
	var frozen_center: Vector2 = player_camera.get_screen_center_position()
	var half_view_width: float = get_viewport_rect().size.x * 0.5 / ENTRY_START_ZOOM.x
	player_camera.zoom = GAMEPLAY_ZOOM
	entry_camera = Camera2D.new()
	entry_camera.name = "World2EntryCamera"
	entry_camera.zoom = ENTRY_START_ZOOM
	entry_camera.position_smoothing_enabled = false
	add_child(entry_camera)
	entry_camera.global_position = frozen_center
	entry_camera.make_current()
	var zoom_out_tween: Tween = create_tween()
	zoom_out_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	zoom_out_tween.tween_property(entry_camera, "zoom", GAMEPLAY_ZOOM, ENTRY_ZOOM_OUT_DURATION)
	var run_distance: float = spawn_position.x - (frozen_center.x - half_view_width - ENTRY_OFFSCREEN_MARGIN)
	player.global_position = Vector2(spawn_position.x - run_distance, spawn_position.y)
	player.begin_intro_run(run_distance, ENTRY_RUN_SPEED)
	while is_inside_tree() and is_instance_valid(player) and player.intro_run_active:
		await get_tree().process_frame
	if not is_inside_tree() or not is_instance_valid(player):
		return
	if zoom_out_tween.is_running():
		await zoom_out_tween.finished
	player.global_position.x = spawn_position.x
	player.velocity = Vector2.ZERO
	player.intro_run_active = false
	player.teleport_locked = false
	player.menu_animation_lock = false
	player_camera.zoom = GAMEPLAY_ZOOM
	player_camera.position_smoothing_enabled = true
	player_camera.make_current()
	if is_instance_valid(entry_camera):
		entry_camera.queue_free()
	entry_camera = null
