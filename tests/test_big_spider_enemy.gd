extends Node
class_name TestBigSpiderEnemy

const BIG_SPIDER_SCENE: PackedScene = preload("res://scenes/bigspider.tscn")

func test_big_spider_death_spawns_two_or_three_small_spiders_once() -> void:
	var enemy_group: Node2D = Node2D.new()
	add_child(enemy_group)
	var spider: BigSpiderEnemy = BIG_SPIDER_SCENE.instantiate() as BigSpiderEnemy
	spider.max_health = 1
	enemy_group.add_child(spider)
	await get_tree().process_frame
	spider.take_damage(1)
	assert(spider.dead)
	await get_tree().process_frame
	var small_spider_count: int = _count_small_spiders(enemy_group)
	assert(small_spider_count >= 2 and small_spider_count <= 3)
	var burst_directions: Array[Vector2] = []
	for child: Node in enemy_group.get_children():
		var small_spider: SmallSpiderEnemy = child as SmallSpiderEnemy
		if small_spider == null:
			continue
		var offset: Vector2 = small_spider.global_position - spider.global_position
		assert(offset.length() >= 50.0, "Spiderlings spawned too close to the big spider")
		assert(small_spider.velocity.length() >= 150.0, "Spiderling launch velocity was too small: %s" % str(small_spider.velocity))
		var launch_direction: Vector2 = offset.normalized()
		assert(small_spider.velocity.normalized().dot(launch_direction) > 0.65,
			"Spiderling velocity did not point outward from its death burst")
		for previous_direction: Vector2 in burst_directions:
			assert(launch_direction.distance_to(previous_direction) > 0.1, "Spiderlings did not launch in distinct directions")
		burst_directions.append(launch_direction)
	spider.take_damage(100)
	await get_tree().process_frame
	assert(_count_small_spiders(enemy_group) == small_spider_count)
	enemy_group.queue_free()
	await get_tree().process_frame

func test_big_spider_has_melee_attack_and_combat_shapes() -> void:
	var spider: BigSpiderEnemy = BIG_SPIDER_SCENE.instantiate() as BigSpiderEnemy
	add_child(spider)
	await get_tree().process_frame
	assert(spider.animated_sprite.sprite_frames.has_animation(&"attack"))
	var scene_tint: ShaderMaterial = spider.animated_sprite.material as ShaderMaterial
	assert(scene_tint != null)
	assert(is_equal_approx(spider.animated_sprite.modulate.a, 1.0), "Big spider opacity should be restored to 100%")
	assert(is_equal_approx(float(scene_tint.get_shader_parameter("desaturation")), BigSpiderEnemy.SPIDER_DESATURATION))
	assert(is_equal_approx(float(scene_tint.get_shader_parameter("desaturation")), 0.15), "Big spiders should retain about 85% of their original saturation")
	assert(is_equal_approx(float(scene_tint.get_shader_parameter("overlay_strength")), BigSpiderEnemy.SPIDER_OVERLAY_STRENGTH))
	assert(is_equal_approx(float(scene_tint.get_shader_parameter("overlay_strength")), 0.15))
	assert(is_equal_approx(float(scene_tint.get_shader_parameter("brightness")), 1.0))
	assert(spider.animated_sprite.sprite_frames.get_frame_count(&"attack") > BigSpiderEnemy.ATTACK_IMPACT_FRAME)
	assert(spider.weapon_shape.disabled)
	spider.set_physics_process(false)
	spider._change_state(BigSpiderEnemy.EnemyState.ATTACK)
	assert(spider.get_node_or_null("attackindicator") != null, "Big spider attack has no warning indicator")
	spider.queue_free()
	await get_tree().process_frame

func _count_small_spiders(parent: Node2D) -> int:
	var count: int = 0
	for child: Node in parent.get_children():
		if child is SmallSpiderEnemy:
			count += 1
	return count
