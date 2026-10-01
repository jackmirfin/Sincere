extends Node2D
class_name MidworldNpcIntro

const DIALOGUE_UI_SCENE: PackedScene = preload("res://scenes/npcdialogueui.tscn")
const INTRO_SEEN_META: StringName = &"midworld_npc_intro_seen"
const CLOSE_ZOOM: Vector2 = Vector2(5.2, 5.2)
const CINEMATIC_FOCUS_Y: float = 14.0
const PAN_DURATION: float = 0.65

enum IntroPhase { INACTIVE, NPC_HELLO, NPC_GIFT, REWARD, PLAYER_FEELING, FINISHING }

@onready var npc: Area2D = $NPC1
@onready var player: PlayerController = $knight
@onready var player_camera: Camera2D = $knight/Camera2D

var dialogue_ui: NpcDialogueUI
var cinematic_camera: Camera2D
var phase: IntroPhase = IntroPhase.INACTIVE
var input_enabled: bool = false
var original_zoom: Vector2 = Vector2.ONE


func _ready() -> void:
	npc.collision_layer = 0
	npc.collision_mask = 2
	npc.monitoring = true
	if not npc.body_entered.is_connected(_on_npc_body_entered):
		npc.body_entered.connect(_on_npc_body_entered)
	dialogue_ui = DIALOGUE_UI_SCENE.instantiate() as NpcDialogueUI
	add_child(dialogue_ui)


func _unhandled_input(event: InputEvent) -> void:
	if phase == IntroPhase.INACTIVE or not input_enabled or not event.is_pressed():
		return
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	get_viewport().set_input_as_handled()
	if dialogue_ui.typing:
		dialogue_ui.complete_typewriter()
		return
	match phase:
		IntroPhase.NPC_HELLO:
			phase = IntroPhase.NPC_GIFT
			dialogue_ui.show_dialogue("Someone left this for you.")
		IntroPhase.NPC_GIFT:
			phase = IntroPhase.REWARD
			dialogue_ui.show_reward()
		IntroPhase.REWARD:
			_pan_to_player_stage()
		IntroPhase.PLAYER_FEELING:
			_finish_intro()


func _on_npc_body_entered(body: Node2D) -> void:
	if body == player:
		start_npc_intro()


func start_npc_intro() -> void:
	if phase != IntroPhase.INACTIVE or get_tree().root.has_meta(INTRO_SEEN_META):
		return
	get_tree().root.set_meta(INTRO_SEEN_META, true)
	phase = IntroPhase.NPC_HELLO
	input_enabled = false
	player.set_teleport_locked(true)
	player.finish_cinematic_animation()
	original_zoom = player_camera.zoom
	cinematic_camera = Camera2D.new()
	cinematic_camera.name = "NpcCinematicCamera"
	cinematic_camera.zoom = original_zoom
	cinematic_camera.global_position = player_camera.get_screen_center_position()
	add_child(cinematic_camera)
	cinematic_camera.make_current()
	var camera_tween: Tween = create_tween()
	camera_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	camera_tween.set_parallel(true)
	camera_tween.tween_property(cinematic_camera, "global_position", npc.global_position + Vector2(0.0, CINEMATIC_FOCUS_Y), PAN_DURATION)
	camera_tween.tween_property(cinematic_camera, "zoom", CLOSE_ZOOM, PAN_DURATION)
	await camera_tween.finished
	if phase != IntroPhase.NPC_HELLO:
		return
	dialogue_ui.show_dialogue("Hey kid!")
	input_enabled = true


func _pan_to_player_stage() -> void:
	phase = IntroPhase.PLAYER_FEELING
	input_enabled = false
	dialogue_ui.hide_reward()
	player.play_cinematic_animation(&"shrug")
	var camera_tween: Tween = create_tween()
	camera_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	var player_camera_target: Vector2 = Vector2(player.global_position.x, cinematic_camera.global_position.y)
	camera_tween.tween_property(cinematic_camera, "global_position", player_camera_target, PAN_DURATION)
	await camera_tween.finished
	if phase != IntroPhase.PLAYER_FEELING:
		return
	dialogue_ui.show_dialogue("you feel warm inside.")
	input_enabled = true


func _finish_intro() -> void:
	phase = IntroPhase.FINISHING
	input_enabled = false
	dialogue_ui.hide_all()
	player.finish_cinematic_animation()
	var return_tween: Tween = create_tween()
	return_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return_tween.set_parallel(true)
	return_tween.tween_property(cinematic_camera, "global_position", player.global_position + player_camera.position, PAN_DURATION)
	return_tween.tween_property(cinematic_camera, "zoom", original_zoom, PAN_DURATION)
	await return_tween.finished
	player_camera.make_current()
	cinematic_camera.queue_free()
	player.set_teleport_locked(false)
	phase = IntroPhase.INACTIVE
