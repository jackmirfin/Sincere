extends Node
class_name TestOgrePlayerDamage

const OGRE_SCENE: PackedScene = preload("res://scenes/orge.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/knight.tscn")

func test_ogre_attack_hitbox_damages_player_from_both_sides() -> void:
	await _assert_attack_hits_from_side(1)
	await _assert_attack_hits_from_side(-1)

func _assert_attack_hits_from_side(facing_direction: int) -> void:
	var world: Node2D = Node2D.new()
	add_child(world)
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.auto_start = false
	player.position = Vector2(float(facing_direction) * 60.0, 0.0)
	world.add_child(player)
	var ogre: OgreEnemy = OGRE_SCENE.instantiate() as OgreEnemy
	world.add_child(ogre)
	await get_tree().process_frame
	player.set_physics_process(false)
	ogre.set_physics_process(false)
	ogre.facing = facing_direction
	ogre._change_state(OgreEnemy.OgreState.ATTACK)
	ogre.animated_sprite.frame = 4
	for _frame: int in range(3):
		await get_tree().physics_frame
	assert(not ogre.weapon_shape.disabled and ogre.weapon_hitbox.monitoring)
	assert(player.health == player.max_health - 1,
		"Ogre attack did not damage player when facing %d; weapon bounds=%s player=%s" % [facing_direction, str(ogre.weapon_shape.global_position), str(player.global_position)])
	Engine.time_scale = 1.0
	player.hit_slowdown_active = false
	var feedback_timer: SceneTreeTimer = get_tree().create_timer(PlayerController.HIT_SLOWMO_DURATION + 0.05, true, false, true)
	await feedback_timer.timeout
	world.queue_free()
	await get_tree().process_frame

func test_three_ogre_strikes_hit_a_player_who_does_not_evade() -> void:
	var world: Node2D = Node2D.new()
	add_child(world)
	var floor: StaticBody2D = StaticBody2D.new()
	floor.collision_layer = 1
	floor.position = Vector2(0.0, 20.0)
	var floor_shape: CollisionShape2D = CollisionShape2D.new()
	var floor_rectangle: RectangleShape2D = RectangleShape2D.new()
	floor_rectangle.size = Vector2(2600.0, 10.0)
	floor_shape.shape = floor_rectangle
	floor.add_child(floor_shape)
	world.add_child(floor)
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.auto_start = false
	player.position = Vector2(60.0, 0.0)
	world.add_child(player)
	var ogre: OgreEnemy = OGRE_SCENE.instantiate() as OgreEnemy
	world.add_child(ogre)
	await get_tree().process_frame
	ogre.set_physics_process(false)
	ogre.facing = 1
	ogre._change_state(OgreEnemy.OgreState.ATTACK)
	ogre.animated_sprite.pause()
	var starting_health: int = player.health
	for strike_index: int in range(OgreEnemy.ATTACK_HIT_FRAMES.size()):
		if strike_index > 0:
			ogre._set_weapon_active(false)
			await get_tree().physics_frame
		ogre.animated_sprite.frame = OgreEnemy.ATTACK_HIT_FRAMES[strike_index]
		for _collision_frame: int in range(3):
			await get_tree().physics_frame
		assert(player.health == starting_health - strike_index - 1,
			"Ogre strike %d missed the player in its facing direction; health=%d" % [strike_index + 1, player.health])
		assert(signi(int(signf(ogre.weapon_hitbox.position.x))) == 1,
			"Ogre hitbox did not match its facing during the first three strikes")
	Engine.time_scale = 1.0
	player.hit_slowdown_active = false
	var feedback_timer: SceneTreeTimer = get_tree().create_timer(PlayerController.HIT_SLOWMO_DURATION + 0.05, true, false, true)
	await feedback_timer.timeout
	world.queue_free()
	await get_tree().process_frame
