extends RigidBody2D
class_name LabNotesBook

const DIALOGUE_UI_SCENE: PackedScene = preload("res://scenes/npcdialogueui.tscn")
const READ_ZOOM: Vector2 = Vector2(4.0, 4.0)
const NOTES_TITLE: String = "Lab notes"
const NOTES_TEXT: String = "hard to read combinations of unknown chemical compounds and formulas"

@onready var interaction_area: Area2D = $InteractionArea
@onready var prompt: Label = $InteractPrompt

var player: PlayerController = null
var dialogue_ui: NpcDialogueUI = null
var player_camera: Camera2D = null
var original_zoom: Vector2 = Vector2.ONE
var reading: bool = false
var document_stage: int = 0
var has_read: bool = false

func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	prompt.hide()
	dialogue_ui = DIALOGUE_UI_SCENE.instantiate() as NpcDialogueUI
	add_child(dialogue_ui)

func _on_body_entered(body: Node2D) -> void:
	var entered_player: PlayerController = body as PlayerController
	if entered_player == null or has_read:
		return
	player = entered_player
	prompt.show()

func _on_body_exited(body: Node2D) -> void:
	if body != player or reading:
		return
	player = null
	prompt.hide()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or event.is_echo():
		return
	if reading:
		get_viewport().set_input_as_handled()
		_advance_notes()
		return
	if player == null or has_read:
		return
	get_viewport().set_input_as_handled()
	_open_notes()

func _open_notes() -> void:
	if player == null:
		return
	reading = true
	prompt.hide()
	player.set_teleport_locked(true)
	player_camera = player.get_node_or_null("Camera2D") as Camera2D
	if player_camera != null:
		original_zoom = player_camera.zoom
		var zoom_tween: Tween = create_tween()
		zoom_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		zoom_tween.tween_property(player_camera, "zoom", READ_ZOOM, 0.3)
	document_stage = 0
	dialogue_ui.show_document_title(NOTES_TITLE)
	if player.animated_sprite.sprite_frames.has_animation(&"shrug"):
		player.animated_sprite.play(&"shrug")

func _advance_notes() -> void:
	if not reading:
		return
	if document_stage == 0:
		document_stage = 1
		dialogue_ui.show_document_description(NOTES_TEXT)
		return
	if dialogue_ui.typing:
		dialogue_ui.complete_typewriter()
		return
	_close_notes()

func _close_notes() -> void:
	reading = false
	document_stage = 0
	has_read = true
	dialogue_ui.hide_all()
	if is_instance_valid(player_camera):
		var zoom_tween: Tween = create_tween()
		zoom_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		zoom_tween.tween_property(player_camera, "zoom", original_zoom, 0.3)
	if is_instance_valid(player):
		player.set_teleport_locked(false)
		player.animated_sprite.play(&"idle")
	player = null
	prompt.hide()
