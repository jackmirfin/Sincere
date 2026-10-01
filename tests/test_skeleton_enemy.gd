extends Node
class_name TestSkeletonEnemy

const SKELETON_SCENE: PackedScene = preload("res://scenes/skeleton.tscn")


func test_skeleton_body_never_blocks_player() -> void:
	var skeleton: CharacterBody2D = SKELETON_SCENE.instantiate() as CharacterBody2D
	var player: CharacterBody2D = CharacterBody2D.new()
	player.name = "TestPlayer"
	player.add_to_group("player")
	player.collision_layer = 2
	player.collision_mask = 5
	add_child(player)
	add_child(skeleton)
	await get_tree().physics_frame
	assert(skeleton.collision_layer == 0)
	assert(player in skeleton.get_collision_exceptions())
	assert(skeleton in player.get_collision_exceptions())
	player.global_position = Vector2(120.0, -180.0)
	assert(bool(skeleton.call("_can_see_player")))
	skeleton.queue_free()
	player.queue_free()


func test_dead_skeleton_clears_all_collision_and_player_exceptions() -> void:
	var skeleton: SkeletonEnemy = SKELETON_SCENE.instantiate() as SkeletonEnemy
	var player: CharacterBody2D = CharacterBody2D.new()
	var enemy_parent: Node2D = Node2D.new()
	player.add_to_group("player")
	add_child(player)
	add_child(enemy_parent)
	enemy_parent.add_child(skeleton)
	await get_tree().physics_frame
	skeleton.take_damage(999)
	await get_tree().physics_frame
	await get_tree().process_frame
	assert((skeleton.get_node("CollisionShape2D") as CollisionShape2D).disabled)
	assert(skeleton.collision_layer == 0 and skeleton.collision_mask == 0)
	var hurtbox: Area2D = skeleton.get_node("Hurtbox") as Area2D
	var weapon: Area2D = skeleton.get_node("WeaponHitbox") as Area2D
	assert(hurtbox.collision_layer == 0 and hurtbox.collision_mask == 0)
	assert(weapon.collision_layer == 0 and weapon.collision_mask == 0)
	assert(player not in skeleton.get_collision_exceptions())
	assert(skeleton not in player.get_collision_exceptions())
	enemy_parent.queue_free()
	player.queue_free()
	await get_tree().process_frame


func test_skeleton_is_tuned_for_aggressive_engagement() -> void:
	var skeleton: Node = SKELETON_SCENE.instantiate()
	assert(float(skeleton.get("move_speed")) >= 135.0)
	assert(float(skeleton.get("detection_range")) >= 800.0)
	assert(float(skeleton.get("attack_windup")) <= 0.22)
	assert(float(skeleton.get("attack_cooldown")) <= 0.40)
	skeleton.free()
