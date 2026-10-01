extends Node
class_name TestBossDeathSequence

const CAVE_SCENE: PackedScene = preload("res://scenes/cave.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/knight.tscn")
const GOBLIN_SCENE: PackedScene = preload("res://scenes/goblin.tscn")


func test_boss_death_runs_slowmo_despawns_summons_then_opens_gate() -> void:
	var cave: Node2D = CAVE_SCENE.instantiate() as Node2D
	add_child(cave)
	await get_tree().process_frame
	var wizard: CaveEvilWizard = cave.get_node("bossfight/evilwizard") as CaveEvilWizard
	var gate: CaveGate = cave.get_node("rooms_gates/endgate") as CaveGate
	var goblin: Node2D = GOBLIN_SCENE.instantiate() as Node2D
	cave.add_child(goblin)
	goblin.add_to_group("wizard_summon")
	wizard.encounter_active = true
	wizard.summoned_enemies = [goblin]
	wizard.health = 10
	wizard.take_damage(999)
	assert(Engine.time_scale < 1.0)
	assert(not is_instance_valid(goblin) or goblin.is_queued_for_deletion())
	assert(wizard.summoned_enemies.is_empty())
	assert(not (gate.opening or gate.opened))
	Engine.time_scale = 4.0
	var frames: int = 0
	while not (gate.opening or gate.opened) and frames < 900:
		await get_tree().process_frame
		frames += 1
	assert(gate.opening or gate.opened)
	assert(is_equal_approx(Engine.time_scale, 1.0))
	Engine.time_scale = 1.0
	cave.queue_free()
	await get_tree().process_frame


func test_cave_endlevel_runs_to_midworld_two() -> void:
	var cave: Node2D = CAVE_SCENE.instantiate() as Node2D
	var endlevel: LevelExit = cave.get_node("bossfight/endlevel") as LevelExit
	assert(endlevel != null)
	assert(endlevel.collision_mask == 2)
	assert(endlevel.next_scene == "res://scenes/midworld_2.tscn")
	cave.free()


func test_player_exit_run_moves_right_running() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.auto_start = false
	add_child(player)
	await get_tree().process_frame
	player.begin_exit_run(240.0)
	assert(player.exit_run_active)
	assert(player.facing == 1)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(player.velocity.x > 0.0)
	assert(player.animated_sprite.animation == &"run")
	assert(not player.animated_sprite.flip_h)
	player.queue_free()
	await get_tree().process_frame