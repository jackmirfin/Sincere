extends Area2D
class_name ChargingSocket

const INTERACT_PROMPT_SCENE: PackedScene = preload("res://scenes/interactprompt.tscn")
const PIXEL_FONT: Font = preload("res://assets/fonts/pixelfont.ttf")

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
	if not is_instance_valid(player):
		return
	player.restore_health_to_max()
	_show_charge_restored()

func _show_charge_restored() -> void:
	var message: Label = Label.new()
	message.name = "ChargeRestoredMessage"
	message.text = "Charge restored"
	message.position = Vector2(-52.0, -43.0)
	message.size = Vector2(104.0, 16.0)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_override("font", PIXEL_FONT)
	message.add_theme_font_size_override("font_size", 8)
	message.add_theme_color_override("font_color", Color(0.77, 1.0, 0.79, 1.0))
	message.add_theme_color_override("font_outline_color", Color(0.04, 0.12, 0.09, 1.0))
	message.add_theme_constant_override("outline_size", 2)
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(message)
	var fade_tween: Tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(message, "position", message.position + Vector2(0.0, -22.0), 1.25)
	fade_tween.tween_property(message, "modulate:a", 0.0, 1.25).set_delay(0.25)
	fade_tween.chain().tween_callback(message.queue_free)
