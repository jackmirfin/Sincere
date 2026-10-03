extends Node
class_name TestSmallSpiderEnemy

const SPIDER_SCENE: PackedScene = preload("res://scenes/smallspider.tscn")

func test_spider_has_two_health_and_dies_after_two_player_hits() -> void:
	var spider: SmallSpiderEnemy = SPIDER_SCENE.instantiate() as SmallSpiderEnemy
	add_child(spider)
	await get_tree().process_frame
	assert(spider.health == 2)
	spider.take_damage(100)
	assert(spider.health == 1)
	assert(not spider.dead)
	spider.take_damage(100)
	assert(spider.health == 0)
	assert(spider.dead)
	spider.queue_free()
	await get_tree().process_frame

func test_spider_attack_uses_frame_five_and_has_attack_animation() -> void:
	var spider: SmallSpiderEnemy = SPIDER_SCENE.instantiate() as SmallSpiderEnemy
	assert(spider.animated_sprite == null)
	add_child(spider)
	await get_tree().process_frame
	assert(spider.animated_sprite.sprite_frames.has_animation(&"attack"))
	var scene_tint: ShaderMaterial = spider.animated_sprite.material as ShaderMaterial
	assert(scene_tint != null)
	assert(is_equal_approx(spider.animated_sprite.modulate.a, 1.0), "Small spider opacity should be restored to 100%")
	assert(is_equal_approx(float(scene_tint.get_shader_parameter("desaturation")), SmallSpiderEnemy.SPIDER_DESATURATION))
	assert(is_equal_approx(float(scene_tint.get_shader_parameter("desaturation")), 0.15), "Small spiders should retain about 85% of their original saturation")
	assert(is_equal_approx(float(scene_tint.get_shader_parameter("overlay_strength")), SmallSpiderEnemy.SPIDER_OVERLAY_STRENGTH))
	assert(is_equal_approx(float(scene_tint.get_shader_parameter("overlay_strength")), 0.15))
	assert(is_equal_approx(float(scene_tint.get_shader_parameter("brightness")), 1.0))
	assert(spider.animated_sprite.sprite_frames.get_frame_count(&"attack") >= 5)
	assert(SmallSpiderEnemy.ATTACK_IMPACT_FRAME == 4)
	spider.set_physics_process(false)
	spider._change_state(SmallSpiderEnemy.EnemyState.ATTACK)
	assert(spider.get_node_or_null("attackindicator") != null, "Small spider attack has no warning indicator")
	spider.queue_free()
	await get_tree().process_frame
