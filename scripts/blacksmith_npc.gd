extends Area2D
class_name BlacksmithNPC

const DIALOGUE_SCENE: PackedScene = preload("res://scenes/npcdialogueui.tscn")
const BLACKSMITH_UI_SCENE: PackedScene = preload("res://scenes/blacksmith_ui.tscn")
const INTERACT_PROMPT_SCENE: PackedScene = preload("res://scenes/interactprompt.tscn")
const INTRO_LINE: String = "I wonder if I can help?"
const DIALOGUE_HOLD_SECONDS: float = 1.25

var player_in_range: PlayerController = null
var interacting_player: PlayerController = null
var prompt: Label
var dialogue_ui: NpcDialogueUI
var blacksmith_ui: BlacksmithUI
var conversation_active: bool = false
var blocked_by_shop: Shop = null


func set_blocking_shop(shop: Shop) -> void:
	blocked_by_shop = shop


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt = INTERACT_PROMPT_SCENE.instantiate() as Label
	prompt.name = "InteractPrompt"
	prompt.position = Vector2(-12.0, -82.0)
	prompt.visible = false
	add_child(prompt)


func _process(_delta: float) -> void:
	if conversation_active or player_in_range == null:
		return
	if blocked_by_shop != null and blocked_by_shop.shop_ui != null and blocked_by_shop.shop_ui.shop_open:
		return
	if Input.is_action_just_pressed("interact"):
		_start_conversation()


func _on_body_entered(body: Node2D) -> void:
	if body is PlayerController:
		player_in_range = body as PlayerController
		prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body == player_in_range:
		player_in_range = null
		prompt.visible = false


func _start_conversation() -> void:
	if player_in_range == null or conversation_active:
		return
	conversation_active = true
	interacting_player = player_in_range
	interacting_player.set_teleport_locked(true)
	dialogue_ui = DIALOGUE_SCENE.instantiate() as NpcDialogueUI
	dialogue_ui.layer = 60
	add_child(dialogue_ui)
	dialogue_ui.show_dialogue(INTRO_LINE)
	await get_tree().create_timer(DIALOGUE_HOLD_SECONDS).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return
	if dialogue_ui != null and is_instance_valid(dialogue_ui):
		dialogue_ui.hide_dialogue()
		dialogue_ui.queue_free()
		dialogue_ui = null
	if interacting_player == null or not is_instance_valid(interacting_player):
		conversation_active = false
		return
	blacksmith_ui = BLACKSMITH_UI_SCENE.instantiate() as BlacksmithUI
	blacksmith_ui.blacksmith_closed.connect(_on_blacksmith_closed)
	add_child(blacksmith_ui)
	blacksmith_ui.open(interacting_player)


func _on_blacksmith_closed() -> void:
	conversation_active = false
	if blacksmith_ui != null and is_instance_valid(blacksmith_ui):
		blacksmith_ui.queue_free()
	blacksmith_ui = null
	interacting_player = null
	if player_in_range != null:
		prompt.visible = true


func _exit_tree() -> void:
	if interacting_player != null and is_instance_valid(interacting_player):
		interacting_player.set_teleport_locked(false)
