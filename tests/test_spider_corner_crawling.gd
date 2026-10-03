extends Node
class_name TestSpiderCornerCrawling

const BIG_SPIDER_SCENE: PackedScene = preload("res://scenes/bigspider.tscn")

func test_spider_follows_a_wall_instead_of_flipping_back_at_the_floor_corner() -> void:
	var world: Node2D = Node2D.new()
	add_child(world)
	var floor_body: StaticBody2D = StaticBody2D.new()
	floor_body.collision_layer = 1
	floor_body.position = Vector2(300.0, 108.0)
	var floor_shape: CollisionShape2D = CollisionShape2D.new()
	var floor_rectangle: RectangleShape2D = RectangleShape2D.new()
	floor_rectangle.size = Vector2(600.0, 16.0)
	floor_shape.shape = floor_rectangle
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)

	var wall_body: StaticBody2D = StaticBody2D.new()
	wall_body.collision_layer = 1
	wall_body.position = Vector2(110.0, 0.0)
	var wall_shape: CollisionShape2D = CollisionShape2D.new()
	var wall_rectangle: RectangleShape2D = RectangleShape2D.new()
	wall_rectangle.size = Vector2(20.0, 200.0)
	wall_shape.shape = wall_rectangle
	wall_body.add_child(wall_shape)
	world.add_child(wall_body)

	var player: CharacterBody2D = CharacterBody2D.new()
	player.add_to_group("player")
	player.position = Vector2(300.0, -220.0)
	world.add_child(player)
	var spider: BigSpiderEnemy = BIG_SPIDER_SCENE.instantiate() as BigSpiderEnemy
	spider.position = Vector2(40.0, 100.0)
	world.add_child(spider)
	await get_tree().physics_frame

	var reached_wall: bool = false
	for _frame: int in range(100):
		await get_tree().physics_frame
		if spider.crawler.attached and spider.crawler.surface_normal.x < -0.8:
			reached_wall = true
			break
	assert(reached_wall, "Spider never transitioned from the floor onto the wall")
	var wall_start_y: float = spider.global_position.y
	for _frame: int in range(30):
		await get_tree().physics_frame
	assert(spider.crawler.attached and spider.crawler.surface_normal.x < -0.8,
		"Spider lost its wall surface at the floor corner")
	assert(spider.global_position.y < wall_start_y - 5.0,
		"Spider remained stuck instead of crawling up the wall")
	world.queue_free()
	await get_tree().process_frame
