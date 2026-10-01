extends Node2D
class_name WorldParallax

@export var background_layer_5_factor: float = 0.05
@export var sun_factor: float = 0.07
@export var castle_factor: float = 0.08
@export var background_layer_4_factor: float = 0.18
@export var background_layer_3_factor: float = 0.32
@export var background_layer_2_factor: float = 0.48
@export var background_layer_1_factor: float = 0.64
@export var trees_factor: float = 0.78
@export var decor_factor: float = 0.90

var player: Node2D
var origin_player_x: float = 0.0
var tracked_layers: Array[Node2D] = []
var base_x_positions: Array[float] = []
var movement_factors: Array[float] = []

func _ready() -> void:
	_configure_environment_hitboxes()
	player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	_setup_tracking()

func _setup_tracking() -> void:
	if player == null or not tracked_layers.is_empty():
		return
	origin_player_x = player.global_position.x
	_register_layer("background layer 5", background_layer_5_factor)
	_register_layer("sun", sun_factor)
	_register_layer("castle", castle_factor)
	_register_layer("background layer 4", background_layer_4_factor)
	_register_layer("background layer 3", background_layer_3_factor)
	_register_layer("background layer 2", background_layer_2_factor)
	_register_layer("background layer 1", background_layer_1_factor)
	_register_layer("trees", trees_factor)
	_register_layer("decor", decor_factor)

func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
		if player == null:
			return
		_setup_tracking()
	var player_delta_x: float = player.global_position.x - origin_player_x
	for index: int in range(tracked_layers.size()):
		var layer: Node2D = tracked_layers[index]
		layer.global_position.x = base_x_positions[index] + player_delta_x * (1.0 - movement_factors[index])

func _configure_environment_hitboxes() -> void:
	var hitbox_names: Array[StringName] = [&"environmenthitboxsmall", &"environmenthitboxlarge", &"environmenthitboxverylarge", &"environmenthitboxwall"]
	for hitbox_name: StringName in hitbox_names:
		var hitbox: Area2D = get_node_or_null(NodePath(hitbox_name)) as Area2D
		if hitbox == null:
			continue
		hitbox.collision_layer = 16
		hitbox.collision_mask = 2
		if not hitbox.is_in_group("environment_spike"):
			hitbox.add_to_group("environment_spike")

func _register_layer(layer_name: String, movement_factor: float) -> void:
	var layer: Node2D = get_node_or_null("world/" + layer_name) as Node2D
	if layer == null:
		return
	tracked_layers.append(layer)
	base_x_positions.append(layer.global_position.x)
	movement_factors.append(clampf(movement_factor, 0.0, 1.0))
