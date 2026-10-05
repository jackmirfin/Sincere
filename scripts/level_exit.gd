extends Area2D
class_name LevelExit

@export_file("*.tscn") var next_scene: String = "res://scenes/midworld_2.tscn"
@export var exit_run_speed: float = 240.0
@export var offscreen_margin: float = 96.0
@export var max_exit_time: float = 6.0
@export var exit_camera_zoom: Vector2 = Vector2(4.0, 4.0)
@export var exit_zoom_duration: float = 0.65

var triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if triggered or not body.is_in_group("player"):
		return
	triggered = true
	_play_exit(body)

func _play_exit(body: Node2D) -> void:
	var player: PlayerController = body as PlayerController
	if player == null:
		get_tree().call_deferred("change_scene_to_file", next_scene)
		return
	var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	var freeze_center: Vector2 = player.global_position
	var final_zoom: Vector2 = camera.zoom if camera != null else Vector2.ONE
	var world_half_width: float = get_viewport_rect().size.x * 0.5
	if camera != null:
		freeze_center = camera.get_screen_center_position()
		# Freeze the camera so the player runs out of view.
		camera.reparent(get_tree().current_scene, true)
		camera.global_position = freeze_center
		camera.position_smoothing_enabled = false
		camera.make_current()
		if next_scene == "res://scenes/world_2.tscn":
			final_zoom = exit_camera_zoom
			var zoom_tween: Tween = create_tween()
			zoom_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			zoom_tween.tween_property(camera, "zoom", final_zoom, exit_zoom_duration)
	world_half_width /= maxf(0.01, final_zoom.x)
	player.begin_exit_run(exit_run_speed)
	var target_x: float = freeze_center.x + world_half_width + offscreen_margin
	var elapsed: float = 0.0
	while is_instance_valid(player) and player.global_position.x < target_x and elapsed < max_exit_time:
		elapsed += get_process_delta_time()
		await get_tree().process_frame
	if not is_inside_tree():
		return
	if next_scene == "res://scenes/world_2.tscn":
		_handoff_background_music()
	get_tree().call_deferred("change_scene_to_file", next_scene)

func _handoff_background_music() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	var music: AudioStreamPlayer = current_scene.get_node_or_null("BackgroundMusic") as AudioStreamPlayer
	if music == null or not music.playing:
		return
	music.reparent(get_tree().root, true)
