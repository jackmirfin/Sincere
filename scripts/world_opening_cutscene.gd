extends Node2D
class_name WorldOpeningCutscene

const DIALOGUE_UI_SCENE: PackedScene = preload("res://scenes/npcdialogueui.tscn")
const PORTAL_SCENE: PackedScene = preload("res://scenes/portal.tscn")
const FAN_SOUND_PATH: String = "res://assets/sounds/ceilingfan.mp3"
const DOOR_SOUND_PATH: String = "res://assets/sounds/dooropen.mp3"
const FOOTSTEPS_SOUND_PATH: String = "res://assets/sounds/running.mp3"
const STRETCHER_SOUND_PATH: String = "res://assets/sounds/stretcherwheels.mp3"
const SCUFFLE_SOUND_PATH: String = "res://assets/sounds/scuffle.mp3"
const PORTAL_ENTER_SOUND_PATH: String = "res://assets/sounds/portalenter.mp3"
const PORTAL_EXIT_SOUND_PATH: String = "res://assets/sounds/portalexit.mp3"
const OPENING_ZOOM: Vector2 = Vector2(6.6, 6.6)
const GAME_ZOOM: Vector2 = Vector2(3.3, 3.3)
const CASTLE_FOCUS: Vector2 = Vector2(352.0, 112.0)
const ARRIVAL_LIFT: float = 28.0
const PORTAL_SPAWN_OFFSET: Vector2 = Vector2(0.0, -48.0)
const SFX_SILENCE_GAP: float = 0.45

var player: PlayerController = null
var player_camera: Camera2D = null
var opening_camera: Camera2D = null
var dialogue_ui: NpcDialogueUI = null
var black_canvas: CanvasLayer = null
var black_screen: ColorRect = null
var main_music: AudioStreamPlayer = null
var portal: Node2D = null
var active_audio: Array[AudioStreamPlayer] = []
var enemies_paused: Array[Node] = []
var dialogue_advance_requested: bool = false
var waiting_for_dialogue: bool = false
var opening_sequence_active: bool = false
var opening_sequence_finished: bool = false
var arrival_started: bool = false
var original_player_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	player = get_node_or_null("knight") as PlayerController
	if player == null:
		return
	player_camera = player.get_node_or_null("Camera2D") as Camera2D
	original_player_position = player.global_position
	player.set_teleport_locked(true)
	player.animated_sprite.play(&"idle")
	player.visible = false
	if player_camera != null:
		player_camera.position_smoothing_enabled = false
		opening_camera = Camera2D.new()
		opening_camera.name = "WorldOpeningCamera"
		opening_camera.process_mode = Node.PROCESS_MODE_ALWAYS
		opening_camera.position_smoothing_enabled = false
		opening_camera.zoom = OPENING_ZOOM
		add_child(opening_camera)
		opening_camera.global_position = CASTLE_FOCUS
		opening_camera.make_current()
	var pause_menu: Node = get_node_or_null("PauseLayer/PauseMenu")
	if pause_menu != null and pause_menu.has_method("set_startup_sequence_enabled"):
		pause_menu.call("set_startup_sequence_enabled", false)
	main_music = get_node_or_null("BackgroundMusic") as AudioStreamPlayer
	if main_music != null:
		main_music.stop()
		main_music.stream_paused = true
	_pause_enemies()
	black_canvas = CanvasLayer.new()
	black_canvas.name = "OpeningBlackCanvas"
	black_canvas.layer = 70
	black_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(black_canvas)
	black_screen = ColorRect.new()
	black_screen.name = "BlackScreen"
	black_screen.color = Color.BLACK
	black_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black_canvas.add_child(black_screen)
	dialogue_ui = DIALOGUE_UI_SCENE.instantiate() as NpcDialogueUI
	dialogue_ui.characters_per_second = 54.0
	add_child(dialogue_ui)
	opening_sequence_active = true
	call_deferred("_run_opening_sequence")

func _input(event: InputEvent) -> void:
	if not opening_sequence_active or not waiting_for_dialogue or not event.is_pressed() or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	if dialogue_ui != null and dialogue_ui.typing:
		dialogue_ui.complete_typewriter()
	else:
		dialogue_advance_requested = true

func _pause_enemies() -> void:
	for enemy: Node in get_tree().get_nodes_in_group("enemy"):
		if enemy == player or enemies_paused.has(enemy):
			continue
		enemies_paused.append(enemy)
		enemy.process_mode = Node.PROCESS_MODE_DISABLED

func _resume_enemies() -> void:
	for enemy: Node in enemies_paused:
		if is_instance_valid(enemy):
			enemy.process_mode = Node.PROCESS_MODE_INHERIT
	enemies_paused.clear()

func _run_opening_sequence() -> void:
	await _play_optional_sound_with_gap(FAN_SOUND_PATH, -23.0, 2.2)
	await _show_line("Princess: “You’ll be here?”")
	await _show_line("You: “When you wake.”")
	await get_tree().create_timer(0.75).timeout
	await _play_optional_sound_with_gap(DOOR_SOUND_PATH, -4.0, 1.2)
	await _play_optional_sound_with_gap(FOOTSTEPS_SOUND_PATH, -7.0, 2.3)
	await _show_line("Wizard: “We must move her. Now.”")
	await _show_line("You: “You said we had until morning.”")
	await _show_line("Wizard: “Her condition has changed.”")
	await _play_optional_sound_with_gap(STRETCHER_SOUND_PATH, -13.0, 2.0)
	await _show_line("You: “Where are you taking her?”")
	await _show_line("King: “You cannot follow.”")
	await _show_line("You: “Then tell me what you’re going to do.”")
	await _show_line("Wizard: “What is necessary.”")
	await _show_line("You: “I’m not leaving her.”")
	await _show_line("King: “Then send him beyond the gates.”")
	await _play_optional_sound_with_gap(SCUFFLE_SOUND_PATH, -2.0, 1.6)
	await _play_optional_sound_with_gap(PORTAL_ENTER_SOUND_PATH, -4.0, 1.7)
	await _show_line("You: “Wait—!”")
	dialogue_ui.hide_all()
	_stop_all_room_audio()
	await get_tree().create_timer(0.7).timeout
	await _show_portal_arrival()
	await _show_line("Knight: “…I promised.”")
	dialogue_ui.hide_all()
	if player == null or not is_instance_valid(player):
		_finish_opening()
		return
	if not player.play_menu_animation(&"pause", Callable(self, "_begin_resume")):
		_begin_resume()

func _show_line(words: String) -> void:
	if dialogue_ui == null:
		return
	dialogue_advance_requested = false
	waiting_for_dialogue = true
	dialogue_ui.show_dialogue(words)
	while not dialogue_advance_requested and is_inside_tree():
		await get_tree().process_frame
	waiting_for_dialogue = false

func _get_portal_spawn_position() -> Vector2:
	return original_player_position + PORTAL_SPAWN_OFFSET

func _show_portal_arrival() -> void:
	if player == null or player_camera == null or opening_camera == null:
		return
	arrival_started = true
	player.global_position = original_player_position + Vector2(0.0, -ARRIVAL_LIFT)
	player.visible = false
	opening_camera.zoom = OPENING_ZOOM
	opening_camera.make_current()
	portal = PORTAL_SCENE.instantiate() as Node2D
	portal.name = "OpeningPortal"
	portal.scale = Vector2(0.9, 0.9)
	add_child(portal)
	move_child(portal, player.get_index())
	portal.global_position = _get_portal_spawn_position()
	var portal_sprite: AnimatedSprite2D = portal.get_node("AnimatedSprite2D") as AnimatedSprite2D
	portal_sprite.play(&"default")
	var portal_exit_audio: AudioStreamPlayer = _play_optional_sound(PORTAL_EXIT_SOUND_PATH, -2.0)
	var reveal_tween: Tween = create_tween()
	reveal_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	reveal_tween.set_parallel(true)
	reveal_tween.tween_property(black_screen, "color", Color(0.0, 0.0, 0.0, 0.0), 0.9)
	reveal_tween.tween_property(opening_camera, "global_position", original_player_position + player_camera.position, 1.4)
	reveal_tween.tween_property(opening_camera, "zoom", GAME_ZOOM, 1.4)
	await get_tree().create_timer(0.22).timeout
	player.visible = true
	player.animated_sprite.play(&"fall")
	var emerge_tween: Tween = create_tween()
	emerge_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	emerge_tween.tween_property(player, "global_position", original_player_position, 0.48)
	await emerge_tween.finished
	player.animated_sprite.play(&"idle")
	await reveal_tween.finished
	var close_tween: Tween = create_tween()
	close_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	close_tween.set_parallel(true)
	close_tween.tween_property(portal, "scale", Vector2(0.05, 0.05), 0.55)
	close_tween.tween_property(portal, "modulate:a", 0.0, 0.55)
	await close_tween.finished
	await _finish_audio_cue(portal_exit_audio, 1.5)
	if is_instance_valid(portal):
		portal.queue_free()
	portal = null
	if black_screen != null:
		black_screen.queue_free()
		black_screen = null
	if black_canvas != null:
		black_canvas.queue_free()
		black_canvas = null

func _begin_resume() -> void:
	if player == null or not is_instance_valid(player):
		_finish_opening()
		return
	if not player.play_menu_animation(&"resume", Callable(self, "_finish_opening"), Callable(self, "_start_music"), Callable()):
		_finish_opening()

func _start_music() -> void:
	if main_music != null and not main_music.playing:
		main_music.stream_paused = false
		main_music.play()

func _finish_opening() -> void:
	if player != null and is_instance_valid(player):
		player.finish_menu_resume()
		player.set_teleport_locked(false)
		player.visible = true
		if player_camera != null:
			player_camera.global_position = player.global_position + player_camera.position
			player_camera.zoom = GAME_ZOOM
			player_camera.position_smoothing_enabled = true
			player_camera.make_current()
	if is_instance_valid(opening_camera):
		opening_camera.queue_free()
		opening_camera = null
	_resume_enemies()
	_start_music()
	opening_sequence_active = false
	opening_sequence_finished = true

func _play_optional_sound_with_gap(sound_path: String, volume_db: float, playback_duration: float) -> void:
	var audio: AudioStreamPlayer = _play_optional_sound(sound_path, volume_db)
	await _finish_audio_cue(audio, playback_duration)

func _finish_audio_cue(audio: AudioStreamPlayer, playback_duration: float) -> void:
	if is_instance_valid(audio) and audio.playing and playback_duration > 0.0:
		await get_tree().create_timer(playback_duration).timeout
	if is_instance_valid(audio):
		if audio.playing:
			audio.stop()
		audio.queue_free()
	await get_tree().create_timer(SFX_SILENCE_GAP).timeout

func _play_optional_sound(sound_path: String, volume_db: float) -> AudioStreamPlayer:
	if not ResourceLoader.exists(sound_path):
		return null
	var stream: AudioStream = ResourceLoader.load(sound_path) as AudioStream
	if stream == null:
		return null
	var audio: AudioStreamPlayer = AudioStreamPlayer.new()
	audio.name = "OpeningSfx_%d" % active_audio.size()
	audio.stream = stream
	audio.volume_db = volume_db
	add_child(audio)
	active_audio.append(audio)
	audio.play()
	return audio

func _stop_all_room_audio() -> void:
	for audio: AudioStreamPlayer in active_audio:
		if is_instance_valid(audio):
			audio.stop()
	active_audio.clear()

func get_cutscene_dialogue() -> Array[String]:
	return [
		"Princess: “You’ll be here?”",
		"You: “When you wake.”",
		"Wizard: “We must move her. Now.”",
		"You: “You said we had until morning.”",
		"Wizard: “Her condition has changed.”",
		"You: “Where are you taking her?”",
		"King: “You cannot follow.”",
		"You: “Then tell me what you’re going to do.”",
		"Wizard: “What is necessary.”",
		"You: “I’m not leaving her.”",
		"King: “Then send him beyond the gates.”",
		"You: “Wait—!”",
		"Knight: “…I promised.”",
	]
