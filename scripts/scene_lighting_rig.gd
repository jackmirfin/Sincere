extends Node2D
class_name SceneLightingRig

const BACKGROUND_ATLAS_PATH := "_Complete_static_BG_"
const BLANK_ATLAS_COORDS := Vector2i(6, 3)
const FIXTURE_TOP_COORDS: Array[Vector2i] = [Vector2i(8, 6), Vector2i(11, 6), Vector2i(1, 4)]
const TORCH_SCENE: PackedScene = preload("res://scenes/torch.tscn")
const CAVE_EXTRA_TORCH_CELLS: Array[Vector2i] = [Vector2i(149, 24), Vector2i(129, 26), Vector2i(137, 17), Vector2i(117, 27)]
const CAVE_CLIPPING_FIXTURE_TOP := Vector2i(32, 23)
const TWILIGHT_ENEMY_TORCH_TARGETS: Array[StringName] = [&"goblin_spider2a", &"goblin_spider4a", &"ogre1", &"ogre7", &"goblin_spider1a"]
const TORCH_SIZE := Vector2(32.0, 32.0)
const TORCH_SEARCH_RADIUS_CELLS := 6
const BASE_TORCH_GLOW_ENERGY := 1.05
const TWILIGHT_TORCH_GLOW_ENERGY := 1.2

func _ready() -> void:
	call_deferred("_replace_background_fixtures")

func _replace_background_fixtures() -> void:
	var scene_root: Node = get_parent()
	if scene_root == null:
		return
	var background_layer: TileMapLayer = _find_background_layer(scene_root)
	if background_layer == null:
		push_warning("SceneLightingRig: no shared cave background TileMapLayer found.")
		return
	var fixture_positions: Array[Vector2i] = _find_fixture_pairs(background_layer)
	fixture_positions.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)
	var parallax_host: Node2D = _find_parallax_host(background_layer, scene_root)
	var platform_layers: Array[TileMapLayer] = _find_platform_layers(scene_root, background_layer)
	var search_offsets: Array[Vector2i] = _build_search_offsets(TORCH_SEARCH_RADIUS_CELLS)
	var glow_energy: float = BASE_TORCH_GLOW_ENERGY
	if scene_root.name == "twilightcave":
		glow_energy = TWILIGHT_TORCH_GLOW_ENERGY
	var placed_torch_rects: Array[Rect2] = []
	var torch_count: int = 0
	var shifted_torch_count: int = 0
	for fixture_index: int in range(fixture_positions.size()):
		var top_cell: Vector2i = fixture_positions[fixture_index]
		var source_id: int = background_layer.get_cell_source_id(top_cell)
		var bottom_cell: Vector2i = top_cell + Vector2i(0, 1)
		background_layer.set_cell(top_cell, source_id, BLANK_ATLAS_COORDS)
		background_layer.set_cell(bottom_cell, source_id, BLANK_ATLAS_COORDS)
		if fixture_index % 2 == 0:
			if scene_root.name == "cave" and top_cell == CAVE_CLIPPING_FIXTURE_TOP:
				print("[SceneLightingRig] Suppressed the Cave torch at fixture %s because it clips the floor." % top_cell)
				continue
			var anchor_world: Vector2 = background_layer.to_global(background_layer.map_to_local(top_cell) + Vector2(0.0, 8.0))
			var placement: Dictionary = _try_add_torch(anchor_world, background_layer, parallax_host, platform_layers, search_offsets, placed_torch_rects, glow_energy)
			if bool(placement.get("placed", false)):
				torch_count += 1
				if bool(placement.get("adjusted", false)):
					shifted_torch_count += 1
	if scene_root.name == "cave":
		for extra_cell: Vector2i in CAVE_EXTRA_TORCH_CELLS:
			var extra_anchor_world: Vector2 = background_layer.to_global(background_layer.map_to_local(extra_cell))
			var extra_placement: Dictionary = _try_add_torch(extra_anchor_world, background_layer, parallax_host, platform_layers, search_offsets, placed_torch_rects, glow_energy)
			if bool(extra_placement.get("placed", false)):
				torch_count += 1
				var extra_offset: Vector2i = extra_placement.get("offset", Vector2i.ZERO)
				if bool(extra_placement.get("adjusted", false)):
					shifted_torch_count += 1
				var actual_cell: Vector2i = extra_cell + extra_offset
				print("[SceneLightingRig] Cave torch requested at %s; placed at %s to clear platforms." % [extra_cell, actual_cell])
			else:
				push_warning("SceneLightingRig: could not safely place requested cave torch at %s." % extra_cell)
	if scene_root.name == "twilightcave":
		var enemy_torch_count: int = _add_twilight_enemy_torches(scene_root, background_layer, parallax_host, platform_layers, placed_torch_rects, glow_energy)
		torch_count += enemy_torch_count
	var player_light: PointLight2D = scene_root.get_node_or_null("knight/PlayerLight") as PointLight2D
	if player_light != null:
		player_light.enabled = true
	print("[SceneLightingRig] %s: replaced %d paired fixtures; placed %d torches (%d shifted away from platforms)." % [scene_root.name, fixture_positions.size(), torch_count, shifted_torch_count])

func _find_background_layer(scene_root: Node) -> TileMapLayer:
	var best_layer: TileMapLayer = null
	var best_fixture_count: int = 0
	var pending: Array[Node] = [scene_root]
	while not pending.is_empty():
		var candidate: Node = pending.pop_back()
		if candidate is TileMapLayer and _uses_shared_background_atlas(candidate as TileMapLayer):
			var layer: TileMapLayer = candidate as TileMapLayer
			var fixture_count: int = _find_fixture_pairs(layer).size()
			if fixture_count > best_fixture_count:
				best_layer = layer
				best_fixture_count = fixture_count
		for child: Node in candidate.get_children():
			pending.append(child)
	return best_layer

func _uses_shared_background_atlas(layer: TileMapLayer) -> bool:
	if layer.tile_set == null:
		return false
	for source_index: int in range(layer.tile_set.get_source_count()):
		var source_id: int = layer.tile_set.get_source_id(source_index)
		var source: TileSetSource = layer.tile_set.get_source(source_id)
		if source is TileSetAtlasSource:
			var atlas_source: TileSetAtlasSource = source as TileSetAtlasSource
			if atlas_source.texture != null and atlas_source.texture.resource_path.contains(BACKGROUND_ATLAS_PATH):
				return true
	return false

func _find_fixture_pairs(layer: TileMapLayer) -> Array[Vector2i]:
	var fixtures: Array[Vector2i] = []
	for top_cell: Vector2i in layer.get_used_cells():
		if not FIXTURE_TOP_COORDS.has(layer.get_cell_atlas_coords(top_cell)):
			continue
		var bottom_cell: Vector2i = top_cell + Vector2i(0, 1)
		if layer.get_cell_source_id(bottom_cell) != layer.get_cell_source_id(top_cell):
			continue
		var top_atlas: Vector2i = layer.get_cell_atlas_coords(top_cell)
		var expected_bottom: Vector2i = Vector2i(top_atlas.x, top_atlas.y + 1)
		if layer.get_cell_atlas_coords(bottom_cell) == expected_bottom:
			fixtures.append(top_cell)
	return fixtures

func _find_parallax_host(layer: TileMapLayer, scene_root: Node) -> Node2D:
	var ancestor: Node = layer.get_parent()
	while ancestor != null:
		if ancestor is Parallax2D:
			return ancestor as Node2D
		ancestor = ancestor.get_parent()
	return scene_root as Node2D

func _find_platform_layers(scene_root: Node, background_layer: TileMapLayer) -> Array[TileMapLayer]:
	var platform_layers: Array[TileMapLayer] = []
	var pending: Array[Node] = [scene_root]
	while not pending.is_empty():
		var candidate: Node = pending.pop_back()
		if candidate is TileMapLayer and candidate != background_layer:
			var layer: TileMapLayer = candidate as TileMapLayer
			if layer.tile_set != null and layer.tile_set.get_physics_layers_count() > 0:
				platform_layers.append(layer)
		for child: Node in candidate.get_children():
			pending.append(child)
	return platform_layers

func _build_search_offsets(radius: int) -> Array[Vector2i]:
	var offsets: Array[Vector2i] = []
	for y: int in range(-radius, radius + 1):
		for x: int in range(-radius, radius + 1):
			offsets.append(Vector2i(x, y))
	offsets.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var distance_a: int = a.x * a.x + a.y * a.y
		var distance_b: int = b.x * b.x + b.y * b.y
		if distance_a != distance_b:
			return distance_a < distance_b
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)
	return offsets

func _build_enemy_torch_offsets(radius: int) -> Array[Vector2i]:
	var offsets: Array[Vector2i] = []
	for y: int in range(-radius, 1):
		for x: int in range(-radius, radius + 1):
			offsets.append(Vector2i(x, y))
	offsets.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if absi(a.y) != absi(b.y):
			return absi(a.y) < absi(b.y)
		var distance_a: int = a.x * a.x + a.y * a.y
		var distance_b: int = b.x * b.x + b.y * b.y
		if distance_a != distance_b:
			return distance_a < distance_b
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)
	return offsets

func _try_add_torch(anchor_world: Vector2, background_layer: TileMapLayer, host: Node2D, platform_layers: Array[TileMapLayer], search_offsets: Array[Vector2i], placed_rects: Array[Rect2], glow_energy: float) -> Dictionary:
	var tile_size: Vector2 = Vector2(background_layer.tile_set.tile_size)
	for offset: Vector2i in search_offsets:
		var candidate_world: Vector2 = anchor_world + Vector2(float(offset.x) * tile_size.x, float(offset.y) * tile_size.y)
		var candidate_rect: Rect2 = Rect2(candidate_world - TORCH_SIZE * 0.5, TORCH_SIZE)
		if _intersects_platform_collision(candidate_rect, candidate_world, platform_layers):
			continue
		var overlaps_existing_torch: bool = false
		for placed_rect: Rect2 in placed_rects:
			if candidate_rect.intersects(placed_rect):
				overlaps_existing_torch = true
				break
		if overlaps_existing_torch:
			continue
		var torch: Node2D = TORCH_SCENE.instantiate() as Node2D
		if torch == null:
			return {"placed": false, "adjusted": false}
		host.add_child(torch)
		torch.position = host.to_local(candidate_world)
		torch.z_index = 5
		var warm_glow: PointLight2D = torch.get_node_or_null("WarmGlow") as PointLight2D
		if warm_glow != null:
			warm_glow.energy = glow_energy
		placed_rects.append(candidate_rect)
		return {"placed": true, "adjusted": offset != Vector2i.ZERO, "offset": offset}
	return {"placed": false, "adjusted": false}

func _add_twilight_enemy_torches(scene_root: Node, background_layer: TileMapLayer, host: Node2D, platform_layers: Array[TileMapLayer], placed_rects: Array[Rect2], glow_energy: float) -> int:
	var placed_count: int = 0
	var enemy_search_offsets: Array[Vector2i] = _build_enemy_torch_offsets(TORCH_SEARCH_RADIUS_CELLS)
	for enemy_name: StringName in TWILIGHT_ENEMY_TORCH_TARGETS:
		var enemy_path: NodePath = NodePath("enemies/" + String(enemy_name))
		var enemy: Node = scene_root.get_node_or_null(enemy_path)
		if enemy == null:
			continue
		var sprite: AnimatedSprite2D = enemy.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if sprite == null or sprite.sprite_frames == null:
			continue
		var frame_texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
		if frame_texture == null:
			continue
		var sprite_height: float = frame_texture.get_size().y * sprite.global_scale.y
		var head_y: float = sprite.global_position.y - sprite_height * 0.5
		var torch_anchor: Vector2 = Vector2(sprite.global_position.x, head_y - TORCH_SIZE.y * 0.5 - 8.0)
		var placement: Dictionary = _try_add_torch(torch_anchor, background_layer, host, platform_layers, enemy_search_offsets, placed_rects, glow_energy)
		if bool(placement.get("placed", false)):
			placed_count += 1
	return placed_count

func _intersects_platform_collision(torch_rect: Rect2, torch_center_world: Vector2, platform_layers: Array[TileMapLayer]) -> bool:
	for layer: TileMapLayer in platform_layers:
		var tile_set: TileSet = layer.tile_set
		if tile_set == null:
			continue
		var center_local: Vector2 = layer.to_local(torch_center_world)
		var center_cell: Vector2i = layer.local_to_map(center_local)
		for y: int in range(center_cell.y - 2, center_cell.y + 3):
			for x: int in range(center_cell.x - 2, center_cell.x + 3):
				var cell: Vector2i = Vector2i(x, y)
				var tile_data: TileData = layer.get_cell_tile_data(cell)
				if tile_data == null:
					continue
				for physics_layer: int in range(tile_set.get_physics_layers_count()):
					for polygon_index: int in range(tile_data.get_collision_polygons_count(physics_layer)):
						var polygon_points: PackedVector2Array = tile_data.get_collision_polygon_points(physics_layer, polygon_index)
						if polygon_points.is_empty():
							continue
						var first_point: Vector2 = layer.to_global(layer.map_to_local(cell) + polygon_points[0])
						var min_point: Vector2 = first_point
						var max_point: Vector2 = first_point
						for point: Vector2 in polygon_points:
							var world_point: Vector2 = layer.to_global(layer.map_to_local(cell) + point)
							min_point = Vector2(minf(min_point.x, world_point.x), minf(min_point.y, world_point.y))
							max_point = Vector2(maxf(max_point.x, world_point.x), maxf(max_point.y, world_point.y))
						var collision_rect: Rect2 = Rect2(min_point, max_point - min_point)
						if torch_rect.intersects(collision_rect):
							return true
	return false
