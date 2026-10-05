extends Node
class_name TestDaggerBackstab

const PLAYER_SCENE: PackedScene = preload("res://scenes/knight.tscn")
const GOBLIN_SCENE: PackedScene = preload("res://scenes/goblin.tscn")


func test_dagger_critically_hits_enemy_back_but_not_front() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	var enemy_back: GoblinEnemy = GOBLIN_SCENE.instantiate() as GoblinEnemy
	var enemy_front: GoblinEnemy = GOBLIN_SCENE.instantiate() as GoblinEnemy
	player.auto_start = false
	add_child(player)
	add_child(enemy_back)
	add_child(enemy_front)
	await get_tree().process_frame
	player.set_physics_process(false)
	enemy_back.set_physics_process(false)
	enemy_front.set_physics_process(false)
	player.global_position = Vector2.ZERO
	player.state = PlayerController.PlayerState.DAGGER_ATTACK
	player.dagger_hitbox_active = true
	enemy_back.global_position = Vector2(40.0, 0.0)
	enemy_back.facing = 1
	enemy_front.global_position = Vector2(-40.0, 0.0)
	enemy_front.facing = 1
	assert(player.is_attack_critical_for(enemy_back), "a player behind a right-facing enemy should backstab")
	assert(not player.is_attack_critical_for(enemy_front), "a player in front of a right-facing enemy should not backstab")
	enemy_front.facing = -1
	assert(player.is_attack_critical_for(enemy_front), "a player behind a left-facing enemy should backstab")
	enemy_front.facing = 1
	var back_health: int = enemy_back.health
	var front_health: int = enemy_front.health
	var back_critical: bool = HitEffect.apply_attack_damage(enemy_back, player, [player.get_attack_damage(), 1, -1.0])
	var front_critical: bool = HitEffect.apply_attack_damage(enemy_front, player, [player.get_attack_damage(), 1, 1.0])
	assert(back_critical, "backstab should use critical-hit feedback")
	assert(not front_critical, "front dagger hit should not use critical feedback")
	assert(back_health - enemy_back.health == 15, "backstab should deal 150% damage")
	assert(front_health - enemy_front.health == 7, "front dagger hit should deal standard reduced damage")
	for effect: Node in get_tree().get_nodes_in_group("critical_blood_effect"):
		effect.queue_free()
	enemy_back.queue_free()
	enemy_front.queue_free()
	player.queue_free()
	await get_tree().process_frame
