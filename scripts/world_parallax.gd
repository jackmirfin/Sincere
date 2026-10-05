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

const WORLD_2_SCENE_PATH: String = "res://scenes/world_2.tscn"
const WORLD_2_DARK_THRESHOLD_TILE_Y: float = 24.0
const WORLD_2_TILE_SIZE_PIXELS: float = 16.0
const WORLD_2_DARK_THRESHOLD_Y: float = WORLD_2_DARK_THRESHOLD_TILE_Y * WORLD_2_TILE_SIZE_PIXELS
const WORLD_2_DARK_AMBIENT: Color = Color(0.40, 0.39, 0.44, 1.0)
const WORLD_2_TORCH_GLOW_MULTIPLIER: float = 2.0
const WORLD_2_TORCH_RADIUS_MULTIPLIER: float = 4.0
const AMBIENT_TRANSITION_SPEED: float = 4.0

var player: Node2D = null
var ambient_canvas: CanvasModulate = null
var ambient_default_color: Color = Color.WHITE
var ambient_darkening_enabled: bool = false
var origin_player_x: float = 0.0
var tracked_layers: Array[Node2D] = []
var base_x_positions: Array[float] = []
var movement_factors: Array[float] = []

func _ready() -> void:
	_configure_environment_hitboxes()
	var scene_root: Node = get_parent()
	if scene_root != null:
		ambient_canvas = scene_root.get_node_or_null("AmbientLight") as CanvasModulate
		if ambient_canvas != null:
			ambient_default_color = ambient_canvas.color
			ambient_darkening_enabled = scene_root.scene_file_path == WORLD_2_SCENE_PATH
			if ambient_darkening_enabled:
				_double_world_2_torch_glow(scene_root)
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

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
		if player == null:
			return
		_setup_tracking()
	var player_delta_x: float = player.global_position.x - origin_player_x
	for index: int in range(tracked_layers.size()):
		var layer: Node2D = tracked_layers[index]
		layer.global_position.x = base_x_positions[index] + player_delta_x * (1.0 - movement_factors[index])
	_update_ambient_light(delta)

func _double_world_2_torch_glow(scene_root: Node) -> void:
	var torch_container: Node = scene_root.get_node_or_null("worldparallax/torches")
	if torch_container == null:
		return
	for torch_node: Node in torch_container.get_children():
		var warm_glow: PointLight2D = torch_node.get_node_or_null("WarmGlow") as PointLight2D
		if warm_glow != null:
			warm_glow.energy *= WORLD_2_TORCH_GLOW_MULTIPLIER
			warm_glow.texture_scale *= WORLD_2_TORCH_RADIUS_MULTIPLIER

func _update_ambient_light(delta: float) -> void:
	if not ambient_darkening_enabled or ambient_canvas == null or player == null:
		return
	var player_local_position: Vector2 = to_local(player.global_position)
	var target_color: Color = get_ambient_target_color(player_local_position.y)
	var blend_amount: float = clampf(delta * AMBIENT_TRANSITION_SPEED, 0.0, 1.0)
	ambient_canvas.color = ambient_canvas.color.lerp(target_color, blend_amount)

func get_ambient_target_color(player_y: float) -> Color:
	if ambient_darkening_enabled and player_y > WORLD_2_DARK_THRESHOLD_Y:
		return WORLD_2_DARK_AMBIENT
	return ambient_default_color

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
