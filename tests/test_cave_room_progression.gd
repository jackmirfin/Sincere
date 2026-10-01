extends Node
class_name TestCaveRoomProgression

const GATE_SCENE: PackedScene = preload("res://scenes/gate.tscn")
const LEVER_SCENE: PackedScene = preload("res://scenes/levers.tscn")
const CAVE_SCENE: PackedScene = preload("res://scenes/cave.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/knight.tscn")


func test_gate_blocks_player_and_enemies_then_fully_opens() -> void:
	var gate: Node = GATE_SCENE.instantiate()
	assert(gate is StaticBody2D)
	add_child(gate)
	await get_tree().process_frame
	var gate_body: StaticBody2D = gate as StaticBody2D
	var gate_shape: CollisionShape2D = gate.get_node("CollisionShape2D") as CollisionShape2D
	assert(gate_body.collision_layer == 1)
	assert((gate_body.collision_mask & 2) != 0)
	assert((gate_body.collision_mask & 8) != 0)
	assert(not gate_shape.disabled)
	gate.call("open_gate")
	await get_tree().create_timer(0.4).timeout
	assert(gate_body.get("opened") == true)
	assert(gate_body.collision_layer == 0 and gate_body.collision_mask == 0)
	assert(gate_shape.disabled)
	assert(not gate_body.visible)
	gate.queue_free()
	await get_tree().process_frame


func test_lever_flips_once_and_becomes_uninteractable() -> void:
	var lever: AnimatedSprite2D = LEVER_SCENE.instantiate() as AnimatedSprite2D
	add_child(lever)
	await get_tree().process_frame
	assert(lever.get("can_interact") == true)
	lever.call("flip")
	await get_tree().create_timer(1.0).timeout
	assert(lever.get("flipped_state") == true)
	assert(lever.get("can_interact") == false)
	assert(lever.animation == &"flipped")
	lever.call("flip")
	assert(lever.animation == &"flipped")
	lever.queue_free()
	await get_tree().process_frame


func test_lever_accepts_player_proximity_and_player_attacks() -> void:
	var lever: CaveLever = LEVER_SCENE.instantiate() as CaveLever
	add_child(lever)
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	add_child(player)
	await get_tree().process_frame
	var activation_area: Area2D = lever.get_node("ActivationArea") as Area2D
	assert((activation_area.collision_mask & 2) != 0)
	assert((activation_area.collision_mask & 4) != 0)
	lever.call("_on_activation_body_entered", player)
	assert(lever.player == player)
	var attack_hitbox: Area2D = player.get_node("AttackHitbox") as Area2D
	lever.call("_on_activation_area_entered", attack_hitbox)
	assert(lever.flipping and not lever.can_interact)
	lever.queue_free()
	player.queue_free()
	await get_tree().process_frame


func test_room_two_gate_two_has_polling_fallback() -> void:
	var cave: Node2D = CAVE_SCENE.instantiate() as Node2D
	add_child(cave)
	await get_tree().process_frame
	var progression: CaveRoomProgression = cave.get_node("rooms_gates") as CaveRoomProgression
	var lever2: CaveLever = cave.get_node("interactables/lever2") as CaveLever
	var lever3: CaveLever = cave.get_node("interactables/lever3") as CaveLever
	var gate2: CaveGate = cave.get_node("rooms_gates/room2/room2gate2") as CaveGate
	lever2.flipped_state = true
	progression.evaluate_progression()
	assert(not gate2.opening and not gate2.opened)
	lever3.flipped_state = true
	progression.evaluate_progression()
	assert(gate2.opening or gate2.opened)
	cave.queue_free()
	await get_tree().process_frame


func test_cave_has_room_progression_controller() -> void:
	var cave: Node2D = CAVE_SCENE.instantiate() as Node2D
	var progression: Node = cave.get_node("rooms_gates")
	assert(progression.has_method("evaluate_progression"))
	assert(cave.get_node("rooms_gates/room1/room1gate1").has_method("open_gate"))
	assert(cave.get_node("interactables/lever").has_method("flip"))
	add_child(cave)
	await get_tree().process_frame
	var room1_enemies: Array = progression.get("room1_enemies") as Array
	var room2_enemies: Array = progression.get("room2_enemies") as Array
	assert(room1_enemies.size() == 5)
	assert(room2_enemies.size() == 5)
	for enemy: Node2D in room1_enemies:
		enemy.set("dead", true)
	progression.call("evaluate_progression")
	await get_tree().create_timer(0.4).timeout
	assert(cave.get_node("rooms_gates/room1/room1gate1").get("opened") == true)
	(cave.get_node("interactables/lever") as AnimatedSprite2D).call("flip")
	await get_tree().create_timer(1.3).timeout
	assert(cave.get_node("rooms_gates/room1/room1gate2").get("opened") == true)
	for enemy: Node2D in room2_enemies:
		enemy.set("dead", true)
	progression.call("evaluate_progression")
	(cave.get_node("interactables/lever2") as AnimatedSprite2D).call("flip")
	(cave.get_node("interactables/lever3") as AnimatedSprite2D).call("flip")
	await get_tree().create_timer(1.3).timeout
	assert(cave.get_node("rooms_gates/room2/room2gate1").get("opened") == true)
	assert(cave.get_node("rooms_gates/room2/room2gate2").get("opened") == true)
	assert(cave.get_node("rooms_gates/hallway/hallwaygate").get("opened") == true)
	cave.queue_free()
	await get_tree().process_frame
