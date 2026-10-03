extends Node2D
class_name TwilightRewardWorld

const ROOM_ENTRY_STOP_Y: float = 272.0
const EXIT_STOP_Y: float = -56.0
const CAMERA_LIMIT_TOP: int = -160

@onready var elevator: Elevator = get_node_or_null("elevator2") as Elevator
@onready var lever: CaveLever = get_node_or_null("lever2") as CaveLever

var entry_ride_complete: bool = false

func _enter_tree() -> void:
	var configured_elevator: Elevator = get_node_or_null("elevator2") as Elevator
	if configured_elevator != null:
		configured_elevator.auto_start = true
		configured_elevator.stop_at_global_y = true
		configured_elevator.stop_global_y = ROOM_ENTRY_STOP_Y
		configured_elevator.retain_rider_at_stop = true
	var player: PlayerController = get_node_or_null("knight") as PlayerController
	if player != null:
		var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			camera.limit_left = 0
			camera.limit_top = CAMERA_LIMIT_TOP

func _ready() -> void:
	if elevator != null and lever != null:
		elevator.set_lever(lever)

func _process(_delta: float) -> void:
	if entry_ride_complete or elevator == null:
		return
	if elevator.activated or elevator.auto_start or elevator.global_position.y > ROOM_ENTRY_STOP_Y + 0.1:
		return
	entry_ride_complete = true
	elevator.stop_global_y = EXIT_STOP_Y
