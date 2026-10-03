extends Node
class_name TestSpiderOgreCoinDrops

const OGRE_SCENE: PackedScene = preload("res://scenes/orge.tscn")
const SMALL_SPIDER_SCENE: PackedScene = preload("res://scenes/smallspider.tscn")
const BIG_SPIDER_SCENE: PackedScene = preload("res://scenes/bigspider.tscn")

func test_ogre_and_both_spider_sizes_always_drop_coins_on_death() -> void:
	var enemy_parent: Node2D = Node2D.new()
	add_child(enemy_parent)
	var ogre: OgreEnemy = OGRE_SCENE.instantiate() as OgreEnemy
	ogre.max_health = 1
	enemy_parent.add_child(ogre)
	var small_spider: SmallSpiderEnemy = SMALL_SPIDER_SCENE.instantiate() as SmallSpiderEnemy
	enemy_parent.add_child(small_spider)
	var big_spider: BigSpiderEnemy = BIG_SPIDER_SCENE.instantiate() as BigSpiderEnemy
	big_spider.max_health = 1
	enemy_parent.add_child(big_spider)
	await get_tree().process_frame

	ogre.take_damage(1)
	small_spider.take_damage(1)
	small_spider.take_damage(1)
	big_spider.take_damage(1)
	var coin_count: int = 0
	for child: Node in enemy_parent.get_children():
		if child is CoinPickup:
			coin_count += 1
	assert(coin_count >= 5, "Ogre and spider deaths should always produce coins; got %d" % coin_count)

	enemy_parent.queue_free()
	await get_tree().process_frame
