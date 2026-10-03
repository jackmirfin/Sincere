extends Node2D
class_name CaveIntroSequence

const KING_SCENE: PackedScene = preload("res://scenes/king.tscn")
const DIALOGUE_UI_SCENE: PackedScene = preload("res://scenes/npcdialogueui.tscn")
const OPENING_ZOOM: Vector2 = Vector2(6.6, 6.6)
const GAME_ZOOM: Vector2 = Vector2(3.3, 3.3)
const OPENING_TRAVEL_ZOOM: Vector2 = Vector2(3.8, 3.8)
const DASH_DURATION: float = 0.92
const STOP_DURATION: float = 0.3
const KING_EXIT_DURATION: float = 3.8
const KING_STAGE_X_OFFSET: float = 45.0
const KING_STAGE_Y_OFFSET: float = 29.0
const BOSS_CAMERA_OFFSET: Vector2 = Vector2(10.0, 0.0)
const DIALOGUE_BOX_WIDTH: float = 540.0
const DIALOGUE_BOX_HEIGHT: float = 220.0
const MAX_DROP_WAIT: float = 4.0
const PAUSE_FOCUS_FRAME: int = 3
const BOSS_PATH: NodePath = NodePath("bossfight/evilwizard")
const ROUTE: Array[NodePath] = [
	NodePath("interactables/lever"),
	NodePath("interactables/lever2"),
	NodePath("interactables/lever3"),
	BOSS_PATH,
]
const BOSS_DIALOGUE: Array[Dictionary] = [
	{"speaker": "KING", "text": "How fares she?"},
	{"speaker": "WIZARD", "text": "Stable, for now. But the affliction resists us."},
	{"speaker": "KING", "text": "And now?"},
	{"speaker": "WIZARD", "text": "We begin again. Stronger this time."},
	{"speaker": "KING", "text": "...And the knight?"},
	{"speaker": "WIZARD", "text": "He will not turn back."},
	{"speaker": "KING", "text": "No. I do not suppose he will."},
	{"speaker": "WIZARD", "text": "He is already here."},
	{"speaker": "KING", "text": "Then do what you must."},
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
var pause_focus_tween: Tween = null
var camera_route_complete: bool = false
var boss_cutscene_started: bool = false
var boss_cutscene_finished: bool = false
var dialogue_active: bool = false
var dialogue_advance_requested: bool = false
var dialogue_ui: NpcDialogueUI = null
var king: CharacterBody2D = null
var boss_original_position: Vector2 = Vector2.ZERO
var end_gate: CaveGate = null

func _ready() -> void:
	var pause_menu: PauseMenu = get_node_or_null("PauseLayer/PauseMenu") as PauseMenu
	if pause_menu != null:
		pause_menu.skip_startup_sequence = true
	player = get_node_or_null("knight") as PlayerController
	if player != null:
		player_camera = player.get_node_or_null("Camera2D") as Camera2D
		if not player.animated_sprite.frame_changed.is_connected(_on_player_frame_changed):
			player.animated_sprite.frame_changed.connect(_on_player_frame_changed)
	if player_camera != null:
		original_limit_top = player_camera.limit_top
		original_limit_bottom = player_camera.limit_bottom
	end_gate = get_node_or_null("rooms_gates/endgate") as CaveGate
	dialogue_ui = DIALOGUE_UI_SCENE.instantiate() as NpcDialogueUI
	dialogue_ui.characters_per_second = 90.0
	add_child(dialogue_ui)
	call_deferred("play_opening_camera_sequence")

func _unhandled_input(event: InputEvent) -> void:
	if not dialogue_active or not event.is_pressed() or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	if dialogue_ui.typing:
		dialogue_ui.complete_typewriter()
	else:
		dialogue_advance_requested = true


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

	player.set_teleport_locked(false)
	player_camera.zoom = OPENING_ZOOM
	player_camera.position_smoothing_enabled = false
	player_camera.make_current()
	cinematic_camera = Camera2D.new()
	cinematic_camera.name = "CaveOpeningCamera"
	cinematic_camera.process_mode = Node.PROCESS_MODE_ALWAYS
	cinematic_camera.zoom = OPENING_ZOOM
	cinematic_camera.position_smoothing_enabled = false
	cinematic_camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	cinematic_camera.limit_left = player_camera.limit_left
	cinematic_camera.limit_top = player_camera.limit_top
	cinematic_camera.limit_right = player_camera.limit_right
	cinematic_camera.limit_bottom = player_camera.limit_bottom
	add_child(cinematic_camera)
	cinematic_camera.global_position = player.global_position + player_camera.position
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
	player.set_teleport_locked(true)
	await _tween_camera_to(player.global_position + player_camera.position, OPENING_TRAVEL_ZOOM, 0.35)

	for target_path: NodePath in ROUTE:
		var target: Node2D = get_node_or_null(target_path) as Node2D
		if target == null:
			continue
		if target_path == BOSS_PATH and target is CaveEvilWizard:
			await _prepare_boss_entrance(target as CaveEvilWizard)
		await _tween_camera_to(_camera_target_position(target), OPENING_TRAVEL_ZOOM, DASH_DURATION)
		completed_stops.append(target_path)
		if target_path == BOSS_PATH and target is CaveEvilWizard:
			await _play_boss_dialogue_cutscene(target as CaveEvilWizard)
		else:
			await get_tree().create_timer(STOP_DURATION).timeout

	camera_route_complete = completed_stops.size() == ROUTE.size()
	await _pan_back_and_hide_boss()
	pause_started = true
	var played_pause: bool = player.play_menu_animation(&"pause", Callable(self, "_start_resume"))
	if not played_pause:
		_focus_player()
		_start_resume()
	sequence_running = false
	sequence_finished = true

func _prepare_boss_entrance(wizard: CaveEvilWizard) -> void:
	boss_cutscene_started = true
	boss_original_position = wizard.global_position
	if end_gate != null and not end_gate.opened:
		end_gate.open_gate()
		if not end_gate.opened:
			await end_gate.opened_signal
	wizard.set_encounter_dormant()
	wizard.global_position = boss_original_position
	wizard.activate_for_intro()
	wizard.animated_sprite.flip_h = false
	wizard.animated_sprite.play(&"idle")
	king = KING_SCENE.instantiate() as CharacterBody2D
	king.name = "OpeningCutsceneKing"
	add_child(king)
	king.global_position = boss_original_position + Vector2(KING_STAGE_X_OFFSET, KING_STAGE_Y_OFFSET)
	var king_sprite: AnimatedSprite2D = king.get_node("AnimatedSprite2D") as AnimatedSprite2D
	king_sprite.flip_h = true
	king_sprite.play(&"idle")


func _play_boss_dialogue_cutscene(wizard: CaveEvilWizard) -> void:
	if end_gate == null or dialogue_ui == null or not is_instance_valid(king):
		boss_cutscene_finished = true
		return
	wizard.animated_sprite.play(&"idle")
	wizard.animated_sprite.flip_h = false
	var king_sprite: AnimatedSprite2D = king.get_node("AnimatedSprite2D") as AnimatedSprite2D
	king_sprite.play(&"idle")
	king_sprite.flip_h = true
	dialogue_active = true
	for line: Dictionary in BOSS_DIALOGUE:
		var speaker: String = str(line["speaker"])
		var words: String = str(line["text"])
		if speaker == "WIZARD" and words == "He is already here.":
			wizard.animated_sprite.flip_h = true
			await get_tree().create_timer(0.2).timeout
		_set_dialogue_side(speaker)
		dialogue_advance_requested = false
		dialogue_ui.show_dialogue(words)
		while not dialogue_advance_requested:
			await get_tree().process_frame
	dialogue_active = false
	dialogue_ui.hide_all()
	wizard.animated_sprite.flip_h = true
	king_sprite.flip_h = false
	king_sprite.play(&"walk")
	var exit_tween: Tween = create_tween()
	exit_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	exit_tween.tween_property(king, "global_position", boss_original_position + Vector2(380.0, KING_STAGE_Y_OFFSET), KING_EXIT_DURATION)
	await exit_tween.finished
	king_sprite.play(&"idle")
	if end_gate.opened:
		end_gate.close_gate()
		if end_gate.closing:
			await end_gate.closed_signal
	king.queue_free()
	king = null
	boss_cutscene_finished = true


func _set_dialogue_side(speaker: String) -> void:
	if dialogue_ui == null:
		return
	var box: TextureRect = dialogue_ui.dialogue_box
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	if speaker == "KING":
		box.anchor_left = 1.0
		box.anchor_right = 1.0
		box.offset_left = -20.0 - DIALOGUE_BOX_WIDTH
		box.offset_right = -20.0
	else:
		box.anchor_left = 0.0
		box.anchor_right = 0.0
		box.offset_left = 20.0
		box.offset_right = 20.0 + DIALOGUE_BOX_WIDTH
	box.offset_top = -30.0 - DIALOGUE_BOX_HEIGHT
	box.offset_bottom = -30.0


func _pan_back_and_hide_boss() -> void:
	var wizard: CaveEvilWizard = get_node_or_null(BOSS_PATH) as CaveEvilWizard
	if wizard == null:
		await _tween_camera_to(player.global_position + player_camera.position, OPENING_TRAVEL_ZOOM, DASH_DURATION)
		return
	var return_tween: Tween = create_tween()
	return_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return_tween.set_parallel(true)
	return_tween.tween_property(cinematic_camera, "global_position", player.global_position + player_camera.position, DASH_DURATION)
	return_tween.tween_property(cinematic_camera, "zoom", OPENING_TRAVEL_ZOOM, DASH_DURATION)
	while return_tween.is_running():
		if wizard.visible and not _wizard_is_visible_in_camera(wizard):
			wizard.set_encounter_dormant()
			wizard.global_position = boss_original_position
		await get_tree().process_frame
	while wizard.visible and _wizard_is_visible_in_camera(wizard):
		await get_tree().process_frame
	if wizard.visible:
		wizard.set_encounter_dormant()
		wizard.global_position = boss_original_position


func _wizard_is_visible_in_camera(wizard: CaveEvilWizard) -> bool:
	if not is_instance_valid(cinematic_camera):
		return false
	var viewport_size: Vector2 = get_viewport_rect().size / cinematic_camera.zoom
	var camera_center: Vector2 = cinematic_camera.get_screen_center_position()
	var camera_rect: Rect2 = Rect2(camera_center - viewport_size * 0.5, viewport_size)
	var wizard_visual_rect: Rect2 = Rect2(wizard.global_position - Vector2(125.0, 140.0), Vector2(250.0, 280.0))
	return camera_rect.intersects(wizard_visual_rect)


func _tween_camera_to(target_position: Vector2, target_zoom: Vector2, minimum_duration: float) -> void:
	if not is_instance_valid(cinematic_camera):
		return
	var travel_time: float = maxf(minimum_duration, cinematic_camera.global_position.distance_to(target_position) / 1100.0)
	travel_time = minf(travel_time, 1.65)
	var camera_tween: Tween = create_tween()
	camera_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	camera_tween.set_parallel(true)
	camera_tween.tween_property(cinematic_camera, "global_position", target_position, travel_time)
	camera_tween.tween_property(cinematic_camera, "zoom", target_zoom, travel_time)
	await camera_tween.finished

func _on_player_frame_changed() -> void:
	if not pause_started or player == null:
		return
	if player.animated_sprite.animation == &"pause" and player.animated_sprite.frame == PAUSE_FOCUS_FRAME:
		_focus_player()

func _focus_player() -> void:
	if not is_instance_valid(cinematic_camera) or not is_instance_valid(player):
		return
	if pause_focus_tween != null and pause_focus_tween.is_running():
		pause_focus_tween.kill()
	pause_focus_tween = create_tween()
	pause_focus_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pause_focus_tween.set_parallel(true)
	pause_focus_tween.tween_property(cinematic_camera, "global_position", player.global_position + player_camera.position, 0.38)
	pause_focus_tween.tween_property(cinematic_camera, "zoom", OPENING_ZOOM, 0.38)

func _camera_target_position(target: Node2D) -> Vector2:
	if target is CaveEvilWizard and boss_cutscene_started:
		return boss_original_position + BOSS_CAMERA_OFFSET
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
	if not is_instance_valid(cinematic_camera):
		return
	var zoom_tween: Tween = create_tween()
	zoom_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	zoom_tween.tween_property(cinematic_camera, "zoom", GAME_ZOOM, 0.7)

func _finish_resume() -> void:
	if not is_instance_valid(player):
		return
	player.finish_menu_resume()
	player.set_teleport_locked(false)
	if is_instance_valid(player_camera):
		player_camera.limit_top = original_limit_top
		player_camera.limit_bottom = original_limit_bottom
		player_camera.position_smoothing_enabled = true
		player_camera.zoom = GAME_ZOOM
		player_camera.make_current()
	if is_instance_valid(cinematic_camera):
		cinematic_camera.queue_free()
		cinematic_camera = null
	if player.animated_sprite.frame_changed.is_connected(_on_player_frame_changed):
		player.animated_sprite.frame_changed.disconnect(_on_player_frame_changed)
