extends Node
class_name TestTwilightCaveIntro

const CAVE_SCENE: PackedScene = preload("res://scenes/twilightcave.tscn")

const PLATFORM_LEFT_X: float = 160.0
const PLATFORM_RIGHT_X: float = 240.0
const TILE: float = 16.0
## The knight's collision shape hangs 4 px below his origin.
const KNIGHT_FEET_OFFSET: float = 4.0

func _spawn_cave() -> Node2D:
	var world: Node2D = CAVE_SCENE.instantiate() as Node2D
	add_child(world)
	return world

func _horizontal_extent(layer: TileMapLayer) -> Vector2:
	var min_x: float = INF
	var max_x: float = -INF
	for cell: Vector2i in layer.get_used_cells():
		min_x = minf(min_x, float(cell.x) * TILE)
		max_x = maxf(max_x, float(cell.x + 1) * TILE)
	return Vector2(min_x, max_x)

func _visible_cable_tops(elevator: Elevator) -> Array[float]:
	var tops: Array[float] = []
	for cable: AnimatedSprite2D in elevator.cables:
		if is_instance_valid(cable) and cable.visible:
			tops.append(cable.global_position.y - TILE * 0.5)
	return tops

func test_twilightcave_wires_an_intro_elevator() -> void:
	var world: Node2D = _spawn_cave()
	await get_tree().process_frame
	var elevator: Elevator = world.get_node_or_null("elevators/elevator") as Elevator
	assert(elevator != null)
	# The ride starts itself: no lever, and it parks on the level's walkway.
	assert(elevator.auto_start == true)
	assert(elevator.stop_at_global_y == true)
	assert(elevator.stop_global_y == TwilightCave.ELEVATOR_STOP_Y)
	assert(elevator.cable_top_global_y == TwilightCave.CABLE_ANCHOR_Y)
	assert(elevator.cables.size() > 1)
	world.queue_free()
	await get_tree().process_frame

func test_platform_starts_under_the_knight_and_meets_the_walkway() -> void:
	var world: Node2D = _spawn_cave()
	await get_tree().process_frame
	var elevator: Elevator = world.get_node("elevators/elevator") as Elevator
	var platform: TileMapLayer = elevator.get_node("elevatorplatform") as TileMapLayer
	var knight: PlayerController = world.get_node("knight") as PlayerController
	# The knight starts standing on the platform, well below the level art.
	var platform_top: float = elevator.global_position.y
	assert(is_equal_approx(platform_top, knight.global_position.y + KNIGHT_FEET_OFFSET))
	assert(platform_top > TwilightCave.ELEVATOR_STOP_Y)
	# The platform fills the shaft between the scaffold towers so the knight can
	# walk straight onto the walkway at the same height.
	var extent: Vector2 = _horizontal_extent(platform)
	assert(is_equal_approx(elevator.global_position.x + extent.x, PLATFORM_LEFT_X))
	assert(is_equal_approx(elevator.global_position.x + extent.y, PLATFORM_RIGHT_X))
	# It is a solid platform, like the midworld elevator.
	assert(platform.tile_set.get_physics_layers_count() == 1)
	assert(platform.tile_set.get_physics_layer_collision_layer(0) == 1)
	# The rider area spans the whole platform and covers the knight's chest.
	var rider: CollisionShape2D = elevator.get_node("elevatorrider") as CollisionShape2D
	var rect: Rect2 = (rider.shape as RectangleShape2D).get_rect()
	var rider_area: Rect2 = Rect2(elevator.global_position + rider.position + rect.position, rect.size)
	print("[cave] platform=", extent, " rider_area=", rider_area, " knight=", knight.global_position)
	assert(is_equal_approx(rider_area.position.x, PLATFORM_LEFT_X))
	assert(is_equal_approx(rider_area.end.x, PLATFORM_RIGHT_X))
	assert(rider_area.has_point(knight.global_position + Vector2(0.0, -14.0)))
	world.queue_free()
	await get_tree().process_frame

func test_camera_shows_the_ride_without_leaving_the_level_art() -> void:
	# Read the authored spawn straight off the packed scene, before the ride moves
	# the knight or the camera limits are configured.
	var packed: Node2D = CAVE_SCENE.instantiate() as Node2D
	var packed_knight: Node2D = packed.get_node("knight") as Node2D
	var spawn_feet: float = packed_knight.global_position.y + KNIGHT_FEET_OFFSET
	var knight_default_limit: float = (packed_knight.get_node("Camera2D") as Camera2D).limit_bottom
	packed.free()

	var world: Node2D = _spawn_cave()
	await get_tree().process_frame
	var knight: PlayerController = world.get_node("knight") as PlayerController
	var cam: Camera2D = knight.get_node("Camera2D") as Camera2D
	assert(cam.limit_bottom == int(TwilightCave.CAMERA_LIMIT_BOTTOM))
	assert(cam.limit_top == int(TwilightCave.CAMERA_LIMIT_TOP))
	# The knight scene's own bottom limit is tighter than this level needs; the
	# level widens it so the camera follows the shaft he climbs.
	assert(cam.limit_bottom > knight_default_limit)
	# The ride starts below the lowest row the camera may show, so the knight is
	# raised into frame rather than standing in it from the first frame.
	assert(spawn_feet > float(cam.limit_bottom))
	# The level art still covers every row the camera can reach.
	var background: TileMapLayer = world.get_node("background") as TileMapLayer
	assert(float(background.get_used_rect().end.y) * TILE >= float(cam.limit_bottom))
	assert(float(background.get_used_rect().position.y) * TILE <= float(cam.limit_top))
	world.queue_free()
	await get_tree().process_frame

func test_intro_ride_raises_the_knight_and_parks_on_the_walkway() -> void:
	var world: Node2D = _spawn_cave()
	var knight: PlayerController = world.get_node("knight") as PlayerController
	var elevator: Elevator = world.get_node("elevators/elevator") as Elevator
	var start_x: float = knight.global_position.x
	var start_y: float = knight.global_position.y
	assert(start_y > TwilightCave.ELEVATOR_STOP_Y)

	var rode: bool = false
	var stayed_on_platform: bool = true
	for _i: int in range(260):
		await get_tree().physics_frame
		if knight.elevator_ride_active:
			rode = true
			stayed_on_platform = stayed_on_platform and absf(
				knight.global_position.y + KNIGHT_FEET_OFFSET - elevator.global_position.y) < 1.0
	assert(rode, "the intro elevator never picked the knight up")
	assert(stayed_on_platform, "the knight drifted off the rising platform")
	assert(is_equal_approx(elevator.global_position.y, TwilightCave.ELEVATOR_STOP_Y))
	assert(knight.elevator_ride_active == false)
	assert(is_equal_approx(knight.global_position.y + KNIGHT_FEET_OFFSET, TwilightCave.ELEVATOR_STOP_Y))
	assert(knight.is_on_floor())
	# The knight is left standing where he started, at walkway height.
	assert(is_equal_approx(knight.global_position.x, start_x))
	# One shot: the parked platform never rides again.
	for _i: int in range(30):
		await get_tree().physics_frame
	assert(is_equal_approx(elevator.global_position.y, TwilightCave.ELEVATOR_STOP_Y))
	assert(elevator.auto_start == false)
	assert(not elevator.audio.playing)
	world.queue_free()
	await get_tree().process_frame

func test_intro_cables_stay_anchored_to_the_shaft_ceiling() -> void:
	var world: Node2D = _spawn_cave()
	var elevator: Elevator = world.get_node("elevators/elevator") as Elevator
	await get_tree().process_frame
	var anchor: float = TwilightCave.CABLE_ANCHOR_Y
	var start_visible: int = _visible_cable_tops(elevator).size()
	assert(start_visible > 1)
	assert(start_visible < elevator.cables.size() or elevator.cables.size() == start_visible)

	for _i: int in range(260):
		await get_tree().physics_frame
		var tops: Array[float] = _visible_cable_tops(elevator)
		assert(not tops.is_empty())
		tops.sort()
		# Never pokes above the ceiling, and always reaches it within one tile.
		assert(tops[0] >= anchor - 0.01)
		assert(tops[0] - anchor < TILE)
	# The stack shortens as the platform climbs towards the pulley.
	var end_visible: int = _visible_cable_tops(elevator).size()
	assert(end_visible < start_visible)
	assert(is_equal_approx(elevator.global_position.y, TwilightCave.ELEVATOR_STOP_Y))
	# Idle cables are back to their resting animation once parked.
	for cable: AnimatedSprite2D in elevator.cables:
		assert(cable.animation == &"idle")
	world.queue_free()
	await get_tree().process_frame