extends Node
class_name TestWorld2Progression

class QuietLever extends CaveLever:
	func _ready() -> void:
		pass

class InstantRevealGate extends CaveGate:
	var camera: Camera2D = null
	var camera_offset_when_opened: Vector2 = Vector2.ZERO

	func _ready() -> void:
		pass

	func open_gate() -> void:
		camera_offset_when_opened = camera.offset if camera != null else Vector2.ZERO
		opening = false
		opened = true
		opened_signal.emit()

func test_each_world2_lever_is_connected_to_its_matching_gate() -> void:
	var progression: World2Progression = World2Progression.new()
	var lever1: CaveLever = CaveLever.new()
	var lever2: CaveLever = CaveLever.new()
	var gate1: CaveGate = CaveGate.new()
	var gate2: CaveGate = CaveGate.new()
	progression.connect_levers_to_gates(lever1, lever2, gate1, gate2)
	var gate1_handler: Callable = Callable(progression, "_reveal_first_gate").bind(gate1)
	var gate2_handler: Callable = Callable(progression, "_reveal_second_gate").bind(gate2)
	assert(lever1.flipped.is_connected(gate1_handler), "lever1 should reveal and open gate1")
	assert(not lever1.flipped.is_connected(gate2_handler), "lever1 must not open gate2")
	assert(lever2.flipped.is_connected(gate2_handler), "lever2 should reveal and open gate2")
	assert(not lever2.flipped.is_connected(gate1_handler), "lever2 must not open gate1")
	progression.free()
	lever1.free()
	lever2.free()
	gate1.free()
	gate2.free()

func test_camera_shows_gate_opening_then_returns_to_player() -> void:
	var world_root: Node2D = Node2D.new()
	var player: Node2D = Node2D.new()
	player.name = "knight"
	player.position = Vector2(20.0, 20.0)
	var camera: Camera2D = Camera2D.new()
	camera.name = "Camera2D"
	camera.position_smoothing_enabled = false
	camera.offset = Vector2(8.0, 4.0)
	player.add_child(camera)
	world_root.add_child(player)
	var interactables: Node2D = Node2D.new()
	world_root.add_child(interactables)
	var progression: World2Progression = World2Progression.new()
	progression.name = "levers_gates"
	var lever1: QuietLever = QuietLever.new()
	lever1.name = "lever1"
	var lever2: QuietLever = QuietLever.new()
	lever2.name = "lever2"
	var gate1: InstantRevealGate = InstantRevealGate.new()
	gate1.name = "gate1"
	gate1.position = Vector2(400.0, 200.0)
	gate1.camera = camera
	var gate1_sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	gate1_sprite.name = "AnimatedSprite2D"
	gate1.add_child(gate1_sprite)
	var gate1_collision: CollisionShape2D = CollisionShape2D.new()
	gate1_collision.name = "CollisionShape2D"
	gate1.add_child(gate1_collision)
	var gate2: InstantRevealGate = InstantRevealGate.new()
	gate2.name = "gate2"
	var gate2_sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	gate2_sprite.name = "AnimatedSprite2D"
	gate2.add_child(gate2_sprite)
	var gate2_collision: CollisionShape2D = CollisionShape2D.new()
	gate2_collision.name = "CollisionShape2D"
	gate2.add_child(gate2_collision)
	progression.add_child(lever1)
	progression.add_child(lever2)
	progression.add_child(gate1)
	progression.add_child(gate2)
	interactables.add_child(progression)
	add_child(world_root)
	await get_tree().process_frame
	camera.make_current()
	await get_tree().process_frame
	assert(camera.is_current(), "test camera should be active")
	assert(progression.get_node_or_null("../../knight") == player, "progression should find the player")
	assert(player.get_node_or_null("Camera2D") == camera, "progression should find the player's camera")
	assert(not progression.camera_reveal_active, "camera reveal should start idle")
	var original_offset: Vector2 = camera.offset
	progression._open_gate_and_reveal(gate1)
	await get_tree().create_timer(0.55).timeout
	assert(gate1.opened, "gate should open after the camera arrives")
	assert(not gate1.camera_offset_when_opened.is_equal_approx(original_offset), "gate should open after the camera pans to it: %s vs %s" % [gate1.camera_offset_when_opened, original_offset])
	await get_tree().create_timer(1.0).timeout
	assert(camera.offset.is_equal_approx(original_offset), "camera should return to the player after revealing the gate")
	assert(not progression.camera_reveal_active, "camera reveal should finish cleanly")
	world_root.queue_free()
	await get_tree().process_frame

func test_world2_entry_unzooms_and_releases_player_controls() -> void:
	var entry_file: FileAccess = FileAccess.open("res://scripts/world_2_entry.gd", FileAccess.READ)
	assert(entry_file != null, "world2 entry controller should be readable")
	var entry_text: String = entry_file.get_as_text()
	entry_file.close()
	assert(entry_text.contains("ENTRY_START_ZOOM"), "entry camera should start zoomed in")
	assert(entry_text.contains("const GAMEPLAY_ZOOM: Vector2 = Vector2(3.3, 3.3)"), "gameplay should return to the normal 3.3x camera zoom")
	assert(entry_text.contains("tween_property(entry_camera, \"zoom\", GAMEPLAY_ZOOM"), "entry camera should unzoom to gameplay zoom")
	assert(entry_text.contains("player_camera.zoom = GAMEPLAY_ZOOM"), "player camera should be reset to gameplay zoom before it takes over")
	assert(entry_text.contains("player.intro_run_active = false"), "intro run should end before controls return")
	assert(entry_text.contains("player.teleport_locked = false"), "player should be unlocked at the end of entry")
	assert(entry_text.contains("player.menu_animation_lock = false"), "no startup animation should leave the player input-locked")

func test_world2_teleporter_and_level_exit_are_wired() -> void:
	var scene_file: FileAccess = FileAccess.open("res://scenes/world_2.tscn", FileAccess.READ)
	assert(scene_file != null, "world_2 scene should be readable")
	var scene_text: String = scene_file.get_as_text()
	scene_file.close()
	assert(scene_text.contains("receiver_path = NodePath(\"teleporterreceiver\")"), "teleporter must point to its receiver")
	assert(scene_text.contains("parent=\"interactables/teleporter\" unique_id=211726880 groups=[\"teleport_receiver\"]"), "teleporter receiver should be registered")
	assert(scene_text.contains("collision_layer = 0\ncollision_mask = 2\nscript = ExtResource(\"28_level_end\")"), "endlevel must detect the player and use LevelEnd")
	assert(scene_text.contains("position = Vector2(875, -275.82)\nscale = Vector2(1, 1.610476)"), "gate1 should fill its 67.64 px opening")
	assert(scene_text.contains("position = Vector2(-56.99997, 3.5)\nscale = Vector2(1, 1.261905)"), "gate2 should fit its 53 px opening")
	var exit_area: LevelEnd = LevelEnd.new()
	assert(exit_area.next_scene == "res://scenes/midworld.tscn", "world_2 exit should lead to midworld 1")
	exit_area.free()
