extends Node2D
class_name CaveRoomProgression

@export var evaluation_interval: float = 0.15

@onready var room1: Area2D = $room1
@onready var room2: Area2D = $room2
@onready var room1_gate1: CaveGate = $room1/room1gate1
@onready var room1_gate2: CaveGate = $room1/room1gate2
@onready var room2_gate1: CaveGate = $room2/room2gate1
@onready var room2_gate2: CaveGate = $room2/room2gate2
@onready var hallway_gate: CaveGate = $hallway/hallwaygate
@onready var lever1: CaveLever = get_node("../interactables/lever") as CaveLever
@onready var lever2: CaveLever = get_node("../interactables/lever2") as CaveLever
@onready var lever3: CaveLever = get_node("../interactables/lever3") as CaveLever
@onready var enemies_root: Node2D = get_node("../enemies") as Node2D

var room1_enemies: Array[Node2D] = []
var room2_enemies: Array[Node2D] = []
var evaluation_time: float = 0.0


func _ready() -> void:
	room1_enemies = _collect_room_enemies(room1)
	room2_enemies = _collect_room_enemies(room2)
	lever1.flipped.connect(_on_lever1_flipped)
	lever2.flipped.connect(_on_lever2_flipped)
	lever3.flipped.connect(_on_lever3_flipped)
	evaluate_progression()


func _process(delta: float) -> void:
	evaluation_time -= delta
	if evaluation_time > 0.0:
		return
	evaluation_time = evaluation_interval
	evaluate_progression()


func evaluate_progression() -> void:
	if _all_enemies_defeated(room1_enemies):
		room1_gate1.open_gate()
	if _all_enemies_defeated(room2_enemies):
		room2_gate1.open_gate()
	if lever1.flipped_state:
		room1_gate2.open_gate()
	if lever3.flipped_state:
		room2_gate2.open_gate()
	_evaluate_hallway_gate()


func _collect_room_enemies(room: Area2D) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var room_shape_node: CollisionShape2D = room.get_node("CollisionShape2D") as CollisionShape2D
	var rectangle: RectangleShape2D = room_shape_node.shape as RectangleShape2D
	if rectangle == null:
		return result
	var room_rect: Rect2 = Rect2(-rectangle.size * 0.5, rectangle.size)
	for child: Node in enemies_root.get_children():
		var enemy: Node2D = child as Node2D
		if enemy == null:
			continue
		var position_in_shape: Vector2 = room_shape_node.to_local(enemy.global_position)
		if room_rect.has_point(position_in_shape):
			result.append(enemy)
	return result


func _all_enemies_defeated(enemies: Array[Node2D]) -> bool:
	for enemy: Node2D in enemies:
		if is_instance_valid(enemy) and enemy.get("dead") != true:
			return false
	return true


func _on_lever1_flipped() -> void:
	room1_gate2.open_gate()
	_evaluate_hallway_gate()


func _on_lever2_flipped() -> void:
	_evaluate_hallway_gate()


func _on_lever3_flipped() -> void:
	room2_gate2.open_gate()
	_evaluate_hallway_gate()


func _evaluate_hallway_gate() -> void:
	if lever1.flipped_state and lever2.flipped_state and lever3.flipped_state:
		hallway_gate.open_gate()
