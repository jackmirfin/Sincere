extends Area2D
class_name Shop

const PROMPT_SCENE: PackedScene = preload("res://scenes/interactprompt.tscn")
const SHOP_UI_SCENE: PackedScene = preload("res://scenes/shopui.tscn")

@export var interaction_offset: Vector2 = Vector2(600.0, 130.0)
@export var interaction_radius: float = 130.0
@export var prompt_offset: Vector2 = Vector2(600.0, 60.0)
@export var interaction_action: StringName = &"interact"

var player: PlayerController = null
var prompt: Label = null
var shop_ui: ShopUI = null
var in_range: bool = false

func _ready() -> void:
	prompt = PROMPT_SCENE.instantiate() as Label
	prompt.position = prompt_offset - Vector2(12.0, 0.0)
	prompt.hide()
	add_child(prompt)
	shop_ui = SHOP_UI_SCENE.instantiate() as ShopUI
	add_child(shop_ui)
	shop_ui.shop_closed.connect(_on_shop_closed)

func _physics_process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as PlayerController
	var shop_open: bool = shop_ui != null and shop_ui.shop_open
	var near: bool = false
	if player != null and not shop_open:
		near = player.global_position.distance_to(global_position + interaction_offset) <= interaction_radius
	if near != in_range:
		in_range = near
		if prompt != null:
			prompt.visible = near
	if near and Input.is_action_just_pressed(interaction_action):
		_open_shop()

func _open_shop() -> void:
	if shop_ui == null or player == null:
		return
	if prompt != null:
		prompt.hide()
	in_range = false
	shop_ui.open(player)

func _on_shop_closed() -> void:
	in_range = false