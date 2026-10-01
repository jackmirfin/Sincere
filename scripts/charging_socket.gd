extends Area2D
class_name ChargingSocket

const INTERACT_PROMPT_SCENE: PackedScene = preload("res://scenes/interactprompt.tscn")

@export var charging_duration: float = 3.0
var player: PlayerController = null
var active: bool = false
var prompt_used: bool = false
var interact_prompt: Label = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	collision_layer = 0
	collision_mask = 2
	interact_prompt = INTERACT_PROMPT_SCENE.instantiate() as Label
	interact_prompt.position = Vector2(-12.0, -32.0)
	add_child(interact_prompt)

func _physics_process(_delta: float) -> void:
	if player != null and not active and Input.is_action_just_pressed("interact"):
		active = true
		dismiss_interact_prompt()
		player.align_for_charging(global_position)
		player.start_charging(charging_duration, Callable(self, "_charging_finished"))

func dismiss_interact_prompt() -> void:
	if prompt_used:
		return
	prompt_used = true
	if is_instance_valid(interact_prompt):
		interact_prompt.hide()

func _on_body_entered(body: Node2D) -> void:
	var entered_player: PlayerController = body as PlayerController
	if entered_player != null:
		player = entered_player

func _on_body_exited(body: Node2D) -> void:
	if body == player and not active:
		player = null

func _charging_finished() -> void:
	active = false
