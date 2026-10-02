extends Node2D
class_name Midworld2

@export var intro_run_distance: float = 40.0
@export var intro_run_speed: float = 100.0

func _enter_tree() -> void:
	var pause_menu: PauseMenu = get_node_or_null("PauseLayer/PauseMenu") as PauseMenu
	if pause_menu != null:
		pause_menu.skip_startup_sequence = true

func _ready() -> void:
	var player: PlayerController = get_tree().get_first_node_in_group("player") as PlayerController
	if player != null:
		_configure_camera(player)
		player.call_deferred("begin_intro_run", intro_run_distance, intro_run_speed)

func _configure_camera(player: Node) -> void:
	# This scene is authored far outside the knight's default camera limits, so
	# widen them for the elevator shaft and pin the left edge to x = 0 so the
	# camera never shows the empty tiles to the left of the level art.
	var cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	cam.limit_left = 0
	cam.limit_bottom = 1600