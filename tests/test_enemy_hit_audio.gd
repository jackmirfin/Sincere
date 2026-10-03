extends Node
class_name TestEnemyHitAudio

const HIT_SOUND: AudioStream = preload("res://assets/sounds/enemyhurt.mp3")
const ENEMY_SCENES: Array[PackedScene] = [
	preload("res://scenes/orge.tscn"),
	preload("res://scenes/smallspider.tscn"),
	preload("res://scenes/bigspider.tscn"),
	preload("res://scenes/goblin.tscn"),
	preload("res://scenes/skeleton.tscn"),
	preload("res://scenes/flyingeye.tscn"),
	preload("res://scenes/mushroom.tscn"),
	preload("res://scenes/samurai.tscn"),
	preload("res://scenes/evilwizard.tscn"),
]
const CAVE_SCENE: PackedScene = preload("res://scenes/cave.tscn")

func test_every_enemy_plays_the_pitched_up_hit_sound() -> void:
	for enemy_scene: PackedScene in ENEMY_SCENES:
		var enemy: Node = enemy_scene.instantiate()
		add_child(enemy)
		enemy.set_physics_process(false)
		await get_tree().process_frame
		_assert_enemy_hit_sound(enemy)
		enemy.queue_free()
		await get_tree().process_frame

	var cave: Node2D = CAVE_SCENE.instantiate() as Node2D
	add_child(cave)
	var cave_wizard: CaveEvilWizard = cave.get_node("bossfight/evilwizard") as CaveEvilWizard
	cave_wizard.set_physics_process(false)
	cave_wizard.encounter_active = true
	cave_wizard.shield_active = false
	_assert_enemy_hit_sound(cave_wizard)
	cave.queue_free()
	await get_tree().process_frame

func _assert_enemy_hit_sound(enemy: Node) -> void:
	var audio: AudioStreamPlayer2D = enemy.get("hurt_audio") as AudioStreamPlayer2D
	assert(audio != null, "%s has no hit audio player" % enemy.name)
	assert(audio.stream == HIT_SOUND, "%s is not using the enemy hit sound" % enemy.name)
	assert(audio.pitch_scale > 1.0 and audio.pitch_scale <= 1.2,
		"%s hit sound pitch was not raised subtly: %f" % [enemy.name, audio.pitch_scale])
	if enemy is SamuraiEnemy:
		enemy.call("take_damage", 1, 1, 0.0)
	else:
		enemy.call("take_damage", 1)
	assert(audio.playing, "%s did not play its hit sound after taking damage" % enemy.name)
