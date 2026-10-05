extends Node2D
class_name Midworld3

const PLAYER_START_POSITION: Vector2 = Vector2(54.0, 624.0)
# Stop eleven 16 px tiles below the original y=16 endpoint.
const ELEVATOR_STOP_GLOBAL_Y: float = 192.0

func _enter_tree() -> void:
	var elevator: Elevator = get_node_or_null("elevator") as Elevator
	if elevator != null:
		elevator.auto_start = true
		elevator.stop_at_global_y = true
		elevator.stop_global_y = ELEVATOR_STOP_GLOBAL_Y
		elevator.retain_rider_at_stop = false

	var shop: Shop = get_node_or_null("twilightshop") as Shop
	if shop != null:
		shop.stock_remaining_upgrades = true
		shop.interaction_offset = Vector2(-14.0, 4.0)
		shop.interaction_radius = 130.0
		shop.prompt_offset = Vector2(-14.0, -36.0)
	var blacksmith: BlacksmithNPC = get_node_or_null("NPC_2") as BlacksmithNPC
	if shop != null and blacksmith != null:
		shop.set_interaction_blocker(blacksmith)
		blacksmith.set_blocking_shop(shop)

func _ready() -> void:
	var player: PlayerController = get_node_or_null("knight") as PlayerController
	if player != null:
		player.position = PLAYER_START_POSITION
		player.elevator_sprite_y_offset = 8.0
		var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			camera.limit_left = 0
			camera.limit_top = -32
			camera.limit_right = 1152
			camera.limit_bottom = 944
