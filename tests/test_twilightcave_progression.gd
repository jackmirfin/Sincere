extends Node
class_name TestTwilightCaveProgression

const CAVE_SCENE: PackedScene = preload("res://scenes/twilightcave.tscn")
const TILE: float = 16.0
## The knight's collision shape hangs 4 px below his origin.
const KNIGHT_FEET_OFFSET: float = 4.0
## A small tolerance for resting positions, which land a fraction of a pixel off.
const SETTLE_EPSILON: float = 0.2
## The roof ride covers 176 px at 7 tiles a second.
const WAIT_FRAMES: int = 600

## A stand-in enemy for the end-gate room. Anything in the "enemy" group with a
## "dead" flag counts, so a bare node with that property is enough.
class DummyEnemy extends Node2D:
	var dead: bool = false

func _spawn_cave() -> Node2D:
	var world: Node2D = CAVE_SCENE.instantiate() as Node2D
	add_child(world)
	# These are isolated progression checks; the dedicated opening test exercises
	# the King cutscene, which would otherwise share the same roof elevator.
	world.opening_sequence_running = true
	return world

func _wait_process_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame

func _wait_physics_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame

## Waits for a condition while advancing both clocks, so the wait works whether
## the test loop is ticking faster than the game's process frames or slower.
func _wait_until(predicate: Callable, frames: int = WAIT_FRAMES) -> bool:
	for _i: int in range(frames):
		if bool(predicate.call()):
			return true
		await get_tree().physics_frame
		await get_tree().process_frame
	return bool(predicate.call())

func _flip_lever(lever: CaveLever) -> void:
	if not lever.flipped_state:
		lever.flip()
	assert(await _wait_until(func() -> bool: return lever.flipped_state), "lever never finished flipping")

func _wait_until_opened(gate: CaveGate) -> void:
	assert(await _wait_until(func() -> bool: return gate.opened), "gate never opened")

func test_every_teleporter_links_to_its_own_receiver() -> void:
	var world: Node2D = _spawn_cave()
	await get_tree().process_frame
	var interactables: Node2D = world.get_node("interactables") as Node2D
	var platforms: TileMapLayer = world.get_node("platforms") as TileMapLayer
	var teleporters: Array[Teleporter] = []
	var destinations: Array[Vector2] = []
	for child: Node in interactables.get_children():
		var teleporter: Teleporter = child as Teleporter
		if teleporter == null:
			continue
		teleporters.append(teleporter)
		assert(not teleporter.receiver_path.is_empty(), "%s has no receiver" % teleporter.name)
		var receiver: Node2D = teleporter.get_node_or_null(teleporter.receiver_path) as Node2D
		assert(receiver != null, "%s points at a missing receiver" % teleporter.name)
		# Each teleporter owns the receiver it sends to: they were copied from one
		# another, and every ride used to end on the same receiver.
		assert(receiver.get_parent() == teleporter, "%s borrows another teleporter's receiver" % teleporter.name)
		var destination: Vector2 = receiver.global_position
		assert(not destinations.has(destination), "%s shares a destination" % teleporter.name)
		destinations.append(destination)
		# The arrival spot is standable: open air with a floor a short drop below.
		var cell: Vector2i = Vector2i(int(floor(destination.x / TILE)), int(floor(destination.y / TILE)))
		assert(platforms.get_cell_source_id(cell) == -1, "%s lands inside a wall" % teleporter.name)
		var ground: bool = false
		for drop: int in range(1, 5):
			if platforms.get_cell_source_id(cell + Vector2i(0, drop)) != -1:
				ground = true
				break
		assert(ground, "%s drops the player into a pit" % teleporter.name)
	assert(teleporters.size() == 5, "expected the level's five teleporters")
	world.queue_free()
	await get_tree().process_frame

func test_gates_start_shut() -> void:
	var world: Node2D = _spawn_cave()
	await get_tree().process_frame
	for gate_name: String in ["gate1", "gate2", "gate3"]:
		var gate: CaveGate = world.get_node("interactables/" + gate_name) as CaveGate
		assert(not gate.opened)
		assert(gate.collision_layer != 0)
	world.queue_free()
	await get_tree().process_frame

func test_lever1_opens_gates_one_and_two() -> void:
	var world: Node2D = _spawn_cave()
	await get_tree().process_frame
	var lever1: CaveLever = world.get_node("interactables/lever1") as CaveLever
	var gate1: CaveGate = world.get_node("interactables/gate1") as CaveGate
	var gate2: CaveGate = world.get_node("interactables/gate2") as CaveGate
	var gate3: CaveGate = world.get_node("interactables/gate3") as CaveGate
	await _flip_lever(lever1)
	await _wait_until_opened(gate1)
	await _wait_until_opened(gate2)
	# Lever 1 leaves the third gate alone.
	assert(not gate3.opened)
	assert(not gate3.opening)
	world.queue_free()
	await get_tree().process_frame

func test_lever2_opens_gate_three() -> void:
	var world: Node2D = _spawn_cave()
	await get_tree().process_frame
	var lever2: CaveLever = world.get_node("interactables/lever2") as CaveLever
	var gate1: CaveGate = world.get_node("interactables/gate1") as CaveGate
	var gate3: CaveGate = world.get_node("interactables/gate3") as CaveGate
	await _flip_lever(lever2)
	await _wait_until_opened(gate3)
	# Lever 2 is the third gate's own lever.
	assert(not gate1.opened)
	assert(not gate1.opening)
	world.queue_free()
	await get_tree().process_frame

func test_endgate_opens_only_when_its_room_is_clear() -> void:
	var world: Node2D = CAVE_SCENE.instantiate() as Node2D
	# The enemy has to be in place before the level's first evaluation pass.
	var enemy: DummyEnemy = DummyEnemy.new()
	enemy.add_to_group("enemy")
	enemy.position = Vector2(700.0, 120.0)
	world.add_child(enemy)
	add_child(world)
	await get_tree().process_frame
	var endgate: CaveGate = world.get_node("interactables/endgate") as CaveGate
	# The room is occupied, so the gate stays shut: give the level several
	# evaluation passes to prove it never opens while the enemy lives.
	await _wait_physics_frames(180)
	assert(not endgate.opened, "the end gate opened with an enemy still in its room")
	assert(not endgate.opening)
	assert(endgate.collision_layer != 0)
	# Kill it and the gate swings open.
	var in_room: bool = TwilightCave.ENDGATE_ROOM.has_point(enemy.global_position)
	assert(in_room, "the test enemy is outside the end-gate room")
	enemy.dead = true
	await _wait_until_opened(endgate)
	world.queue_free()
	await get_tree().process_frame

func test_endgate_ignores_enemies_outside_its_room() -> void:
	var world: Node2D = CAVE_SCENE.instantiate() as Node2D
	var far_enemy: DummyEnemy = DummyEnemy.new()
	far_enemy.add_to_group("enemy")
	far_enemy.position = Vector2(2000.0, 600.0)
	world.add_child(far_enemy)
	add_child(world)
	await get_tree().process_frame
	var endgate: CaveGate = world.get_node("interactables/endgate") as CaveGate
	await _wait_until_opened(endgate)
	world.queue_free()
	await get_tree().process_frame

func test_roof_elevator_waits_for_lever3_and_parks_in_the_hatch() -> void:
	var world: Node2D = _spawn_cave()
	await get_tree().process_frame
	var elevator: Elevator = world.get_node("elevators/elevator2") as Elevator
	var lever3: CaveLever = world.get_node("interactables/lever3") as CaveLever
	var knight: PlayerController = world.get_node("knight") as PlayerController
	var platform: TileMapLayer = elevator.get_node("elevatorplatform") as TileMapLayer
	var start_y: float = elevator.global_position.y
	# This ride is the lever's, not the platform's, and it parks in the ceiling.
	assert(elevator.lever == lever3, "the roof elevator is not wired to lever 3")
	assert(elevator.auto_start == false, "the roof elevator starts without its lever")
	assert(elevator.stop_at_global_y == true, "the roof elevator never parks")
	assert(is_equal_approx(elevator.stop_global_y, TwilightCave.ROOF_ELEVATOR_STOP_Y), "the roof ride stops in the wrong place")
	assert(elevator.cable_top_global_y == TwilightCave.ROOF_ELEVATOR_STOP_Y, "the roof cables hang from the wrong point")
	# The hatch the platform climbs through is clear in the level's own tiles,
	# and the roof it parks against is solid beside it.
	var level_platforms: TileMapLayer = world.get_node("platforms") as TileMapLayer
	var roof_row: int = int(TwilightCave.ROOF_ELEVATOR_STOP_Y / TILE)
	var platform_cell: Vector2i = Vector2i(int(elevator.global_position.x / TILE), roof_row)
	assert(platform.get_cell_source_id(platform.local_to_map(Vector2.ZERO)) != -1, "the platform has no tiles")
	for tx: int in range(platform_cell.x - 2, platform_cell.x + 3):
		assert(level_platforms.get_cell_source_id(Vector2i(tx, roof_row)) == -1, "the hatch is walled in")
	assert(level_platforms.get_cell_source_id(Vector2i(platform_cell.x + 4, roof_row)) != -1, "no roof to step onto")

	# Stand the knight on the platform, where the room floor puts him: the
	# elevator platform sits level with the room's floor tiles.
	var room_floor: float = 176.0
	assert(absf(start_y - room_floor) < SETTLE_EPSILON, "the platform does not sit level with the room floor")
	# Let the intro ride finish first, so only this elevator is carrying him.
	var intro: Elevator = world.get_node("elevators/elevator") as Elevator
	assert(await _wait_until(func() -> bool: return not intro.is_active() and intro.rider == null), "the intro ride never finished")
	knight.global_position = Vector2(elevator.global_position.x, start_y - KNIGHT_FEET_OFFSET)
	await _wait_physics_frames(20)
	# Nothing moves on its own.
	await _wait_physics_frames(40)
	assert(is_equal_approx(elevator.global_position.y, start_y), "the platform moved before the lever was pulled")
	assert(not elevator.is_active())
	assert(elevator.rider == knight, "the knight never registered as the rider")
	# How he sits on the platform is the yardstick for the whole ride.
	var ride_offset: float = knight.global_position.y - elevator.global_position.y
	assert(ride_offset < 0.0)

	# The lever starts the ride, and the platform carries him up to the hatch.
	lever3.flip()
	var started: bool = false
	var stayed_on_platform: bool = true
	for _i: int in range(WAIT_FRAMES):
		await get_tree().physics_frame
		if elevator.is_active():
			started = true
			stayed_on_platform = stayed_on_platform and absf(
				knight.global_position.y - elevator.global_position.y - ride_offset) < 1.0
		elif started:
			break
	assert(started, "lever 3 did not start the elevator")
	assert(stayed_on_platform, "the knight drifted off the rising platform")
	await _wait_physics_frames(40)
	assert(is_equal_approx(elevator.global_position.y, TwilightCave.ROOF_ELEVATOR_STOP_Y), "the ride missed its stop")
	assert(not knight.elevator_ride_active)
	# He is left standing on the parked platform, level with the roof: the parked
	# platform fills the hatch, so its surface is the roof's surface.
	assert(absf(fmod(TwilightCave.ROOF_ELEVATOR_STOP_Y, TILE)) < SETTLE_EPSILON, "the ride does not park on the tile grid")
	assert(absf(knight.global_position.y + KNIGHT_FEET_OFFSET - TwilightCave.ROOF_ELEVATOR_STOP_Y) < SETTLE_EPSILON,
		"knight_y=%.3f platform_y=%.3f ride_offset=%.3f" % [knight.global_position.y, elevator.global_position.y, ride_offset])
	assert(knight.is_on_floor(), "the knight is not standing on the parked platform")
	assert(not elevator.audio.playing, "the pulley is still running after the ride")
	for cable: AnimatedSprite2D in elevator.cables:
		assert(cable.animation == &"idle", "the cables are still lively after the ride")
	# The hatch is level with the roof, so he can walk straight off onto it.
	Input.action_press("right")
	await _wait_physics_frames(90)
	Input.action_release("right")
	assert(knight.global_position.x > elevator.global_position.x + 40.0, "the knight could not walk off the platform onto the roof")
	assert(knight.is_on_floor(), "the knight fell through the roof")
	world.queue_free()
	await get_tree().process_frame

func test_roof_elevator_stays_put_without_a_rider() -> void:
	var world: Node2D = _spawn_cave()
	await get_tree().process_frame
	var elevator: Elevator = world.get_node("elevators/elevator2") as Elevator
	var knight: PlayerController = world.get_node("knight") as PlayerController
	var start_y: float = elevator.global_position.y
	# The knight is far away in the intro shaft, so flipping the lever on its own
	# never starts a ride without someone standing on the platform.
	var lever3: CaveLever = world.get_node("interactables/lever3") as CaveLever
	assert(knight.global_position.distance_to(elevator.global_position) > 300.0)
	await _flip_lever(lever3)
	await _wait_physics_frames(60)
	assert(not elevator.is_active())
	assert(is_equal_approx(elevator.global_position.y, start_y))
	assert(not elevator.audio.playing)
	world.queue_free()
	await get_tree().process_frame