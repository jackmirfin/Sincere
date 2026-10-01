extends Node
class_name TestBossSummonAndThunder

const CAVE_SCENE: PackedScene = preload("res://scenes/cave.tscn")


func test_boss_summons_enemies_one_by_one_from_distinct_markers() -> void:
	var cave: Node2D = CAVE_SCENE.instantiate() as Node2D
	add_child(cave)
	await get_tree().process_frame
	var wizard: CaveEvilWizard = cave.get_node("bossfight/evilwizard") as CaveEvilWizard
	wizard.spawn_markers = [
		cave.get_node("bossfight/spawns_wizardteleports/spawn1") as Node2D,
		cave.get_node("bossfight/spawns_wizardteleports/spawn2") as Node2D,
		cave.get_node("bossfight/spawns_wizardteleports/spawn3") as Node2D,
	]
	wizard.encounter_active = true
	wizard.phase = CaveEvilWizard.FightPhase.WAVE_ONE
	wizard.summon_spawn_interval = 0.05
	wizard.pending_summon_count = 3
	wizard.pending_minimum_skeletons = 0
	wizard.pending_summon_pool = wizard.call("_basic_enemy_pool")
	wizard.call("_spawn_pending_wave")
	# The first enemy spawns immediately; the rest arrive one at a time.
	assert(wizard.summoned_enemies.size() == 1)
	assert(wizard.pending_summon_count == 2)
	await get_tree().create_timer(0.08).timeout
	assert(wizard.summoned_enemies.size() == 2)
	await get_tree().create_timer(0.08).timeout
	assert(wizard.summoned_enemies.size() == 3)
	assert(wizard.pending_summon_count == 0)
	var used_positions: Dictionary = {}
	for enemy: Node2D in wizard.summoned_enemies:
		used_positions[enemy.global_position] = true
	assert(used_positions.size() == 3)
	cave.queue_free()
	await get_tree().process_frame


func test_thunder_strike_warning_is_prominent() -> void:
	var dummy: Node2D = Node2D.new()
	add_child(dummy)
	var warning: EvilWizardStrikeWarning = EvilWizardStrikeWarning.new()
	add_child(warning)
	warning.setup(dummy)
	var indicators: int = 0
	var biggest_scale: float = 0.0
	var has_beam: bool = false
	for child: Node in warning.get_children():
		if child is AnimatedSprite2D:
			indicators += 1
			biggest_scale = maxf(biggest_scale, (child as AnimatedSprite2D).scale.x)
		elif child is Sprite2D:
			has_beam = (child as Sprite2D).scale.y > 4.0
	assert(indicators >= 2)
	assert(biggest_scale >= 2.5)
	assert(has_beam)
	assert(warning.pulse_tween != null)
	warning.queue_free()
	dummy.queue_free()
	await get_tree().process_frame


func test_initial_wave_is_four_and_plays_summon_effect_at_spawns() -> void:
	var cave: Node2D = CAVE_SCENE.instantiate() as Node2D
	add_child(cave)
	await get_tree().process_frame
	var wizard: CaveEvilWizard = cave.get_node("bossfight/evilwizard") as CaveEvilWizard
	var markers: Array[Node2D] = [
		cave.get_node("bossfight/spawns_wizardteleports/spawn1") as Node2D,
		cave.get_node("bossfight/spawns_wizardteleports/spawn2") as Node2D,
		cave.get_node("bossfight/spawns_wizardteleports/spawn3") as Node2D,
	]
	var top_marker: Node2D = cave.get_node("bossfight/spawns_wizardteleports/wizardteleport") as Node2D
	wizard.begin_fight(markers, top_marker)
	assert(wizard.pending_summon_count == 4)
	wizard.summon_spawn_interval = 0.05
	wizard.call("_spawn_pending_wave")
	var summon_effects: int = 0
	for child: Node in cave.get_node("bossfight").get_children():
		if child is EvilWizardSpellEffect:
			summon_effects += 1
	assert(wizard.summoned_enemies.size() == 1)
	assert(summon_effects >= 1)
	cave.queue_free()
	await get_tree().process_frame