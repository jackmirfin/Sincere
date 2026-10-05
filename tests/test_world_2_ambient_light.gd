extends Node
class_name TestWorld2AmbientLight

func test_world2_ambient_drops_below_tile_row_24_and_recovers_above() -> void:
	var rig: WorldParallax = WorldParallax.new()
	add_child(rig)
	rig.ambient_default_color = Color(0.82, 0.82, 0.76, 1.0)
	rig.ambient_darkening_enabled = true
	assert(rig.get_ambient_target_color(276.0).is_equal_approx(rig.ambient_default_color), "world_2 spawn should not start dark")
	assert(rig.get_ambient_target_color(383.0).is_equal_approx(rig.ambient_default_color), "ambient should stay bright before tile row 24")
	assert(rig.get_ambient_target_color(384.0).is_equal_approx(rig.ambient_default_color), "ambient should remain bright at the row 24 boundary")
	assert(rig.get_ambient_target_color(385.0).is_equal_approx(WorldParallax.WORLD_2_DARK_AMBIENT), "ambient should darken below tile row 24")
	rig.ambient_darkening_enabled = false
	assert(rig.get_ambient_target_color(500.0).is_equal_approx(rig.ambient_default_color), "other scenes must retain their original ambient")
	rig.queue_free()
	await get_tree().process_frame

func test_world2_torch_glow_is_doubled_and_radius_is_quadrupled() -> void:
	var rig: WorldParallax = WorldParallax.new()
	add_child(rig)
	var scene_root: Node2D = Node2D.new()
	add_child(scene_root)
	var parallax: Node2D = Node2D.new()
	parallax.name = "worldparallax"
	scene_root.add_child(parallax)
	var torch_container: Node2D = Node2D.new()
	torch_container.name = "torches"
	parallax.add_child(torch_container)
	var torch: Node2D = Node2D.new()
	torch_container.add_child(torch)
	var glow: PointLight2D = PointLight2D.new()
	glow.name = "WarmGlow"
	glow.energy = 1.05
	glow.texture_scale = 0.55
	torch.add_child(glow)
	rig._double_world_2_torch_glow(scene_root)
	assert(is_equal_approx(glow.energy, 2.1), "world_2 torch energy should remain doubled")
	assert(is_equal_approx(glow.texture_scale, 2.2), "world_2 torch light radius should be quadrupled")
	rig.queue_free()
	scene_root.queue_free()
	await get_tree().process_frame
