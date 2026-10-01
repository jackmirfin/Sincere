extends Node2D
class_name TwilightCave

## The opening ride starts below the level art, so the camera has to follow the
## knight down the shaft; 800 keeps the whole ride in view while the level art
## still covers everything the camera can reach.
const CAMERA_LIMIT_BOTTOM: float = 800.0
## The roof elevator parks flush with the end-gate room's roof, so the camera
## needs headroom above the level's ceiling to keep the knight on screen.
const CAMERA_LIMIT_TOP: float = -48.0
## The intro elevator rises from the knight's feet to the level's lower walkway.
const ELEVATOR_STOP_Y: float = 592.0
## Underside of the scaffold cap the pulley hangs from.
const CABLE_ANCHOR_Y: float = 528.0
## The second elevator lifts the knight out of the end-gate room: it climbs from
## the room floor and parks flush with the ceiling hatch it rises through.
const ROOF_ELEVATOR_STOP_Y: float = 0.0
## The room the end gate seals off. It stays shut while any living enemy is in it.
const ENDGATE_ROOM: Rect2 = Rect2(64.0, 16.0, 1072.0, 160.0)
## Teleporter receivers are named after the teleporter that owns them.
const RECEIVER_PREFIX: String = "teleporterreceiver"
const ENEMY_GROUP: String = "enemy"
const PROGRESSION_INTERVAL: float = 0.15

@onready var lever1: CaveLever = get_node_or_null("interactables/lever1") as CaveLever
@onready var lever2: CaveLever = get_node_or_null("interactables/lever2") as CaveLever
@onready var lever3: CaveLever = get_node_or_null("interactables/lever3") as CaveLever
@onready var gate1: CaveGate = get_node_or_null("interactables/gate1") as CaveGate
@onready var gate2: CaveGate = get_node_or_null("interactables/gate2") as CaveGate
@onready var gate3: CaveGate = get_node_or_null("interactables/gate3") as CaveGate
@onready var endgate: CaveGate = get_node_or_null("interactables/endgate") as CaveGate
@onready var roof_elevator: Elevator = get_node_or_null("elevator2") as Elevator

var evaluation_time: float = 0.0

func _enter_tree() -> void:
	# Elevator settings are applied from code because authoring exported values
	# as .tscn property overrides is dropped by the scene serializer. This runs
	# before each elevator's _ready(), which is where the cables are built.
	_configure_intro_elevator()
	_configure_roof_elevator()

func _ready() -> void:
	# Configure this level's own knight: a player left over from the previous
	# scene must never be the one the camera limits are applied to.
	var player: PlayerController = get_node_or_null("knight") as PlayerController
	if player != null:
		_configure_camera(player)
	_link_teleporters()
	# The lever that starts the roof ride stands beside the platform instead of
	# inside the elevator, so the elevator is handed it here.
	if roof_elevator != null and lever3 != null:
		roof_elevator.set_lever(lever3)
	if lever1 != null:
		lever1.flipped.connect(evaluate_progression)
	if lever2 != null:
		lever2.flipped.connect(evaluate_progression)
	evaluate_progression()

func _process(delta: float) -> void:
	evaluation_time -= delta
	if evaluation_time > 0.0:
		return
	evaluation_time = PROGRESSION_INTERVAL
	evaluate_progression()

## Lever 1 opens gates 1 and 2, lever 2 opens gate 3, and the end gate opens once
## the room around it holds no living enemy. Polled as well as driven by the
## levers' signals, so a gate still opens when an enemy dies out of view.
func evaluate_progression() -> void:
	if lever1 != null and lever1.flipped_state:
		_open_gate(gate1)
		_open_gate(gate2)
	if lever2 != null and lever2.flipped_state:
		_open_gate(gate3)
	if _endgate_room_cleared():
		_open_gate(endgate)

func _open_gate(gate: CaveGate) -> void:
	if gate != null:
		gate.open_gate()

func _endgate_room_cleared() -> bool:
	for node: Node in get_tree().get_nodes_in_group(ENEMY_GROUP):
		var enemy: Node2D = node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.get("dead") == true:
			continue
		if ENDGATE_ROOM.has_point(enemy.global_position):
			return false
	return true

## Every teleporter sends the player to the receiver node it owns. Several were
## copied from one another and all pointed at the same receiver, which sent every
## ride to a single spot.
func _link_teleporters() -> void:
	var interactables: Node = get_node_or_null("interactables")
	if interactables == null:
		return
	for child: Node in interactables.get_children():
		var teleporter: Teleporter = child as Teleporter
		if teleporter == null:
			continue
		var receiver: Node2D = _own_receiver(teleporter)
		if receiver != null:
			teleporter.receiver_path = teleporter.get_path_to(receiver)

func _own_receiver(teleporter: Teleporter) -> Node2D:
	for child: Node in teleporter.get_children():
		var receiver: Node2D = child as Node2D
		if receiver != null and String(child.name).begins_with(RECEIVER_PREFIX):
			return receiver
	return null

func _configure_intro_elevator() -> void:
	var elevator: Elevator = get_node_or_null("elevator") as Elevator
	if elevator == null:
		return
	elevator.auto_start = true
	elevator.stop_at_global_y = true
	elevator.stop_global_y = ELEVATOR_STOP_Y
	elevator.cable_top_global_y = CABLE_ANCHOR_Y

func _configure_roof_elevator() -> void:
	var elevator: Elevator = get_node_or_null("elevator2") as Elevator
	if elevator == null:
		return
	elevator.stop_at_global_y = true
	elevator.stop_global_y = ROOF_ELEVATOR_STOP_Y
	elevator.cable_top_global_y = ROOF_ELEVATOR_STOP_Y

func _configure_camera(player: Node) -> void:
	# The knight is raised into the level on the intro elevator, so the camera
	# follows him below the knight scene's default bottom limit; the roof ride
	# needs the same headroom above the level's ceiling.
	var cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	cam.limit_bottom = int(CAMERA_LIMIT_BOTTOM)
	cam.limit_top = int(CAMERA_LIMIT_TOP)