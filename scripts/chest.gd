extends Area2D
class_name TreasureChest

@export var coin_count_min: int = 12
@export var coin_count_max: int = 18
@export var coin_amount_multiplier: int = 3

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var opened: bool = false

func _ready() -> void:
	collision_layer = 8
	collision_mask = 4
	area_entered.connect(_on_area_entered)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.play(&"shut")

func _on_area_entered(area: Area2D) -> void:
	if opened or not area.is_in_group("player_attack_hitbox"):
		return
	opened = true
	monitoring = false
	animated_sprite.play(&"opening")

func _on_animation_finished() -> void:
	if animated_sprite.animation == &"opening":
		_drop_coins()
		animated_sprite.play(&"open")

func get_drop_profile() -> Dictionary:
	return {
		"drop_chance": 1.0,
		"min_coins": coin_count_min * coin_amount_multiplier,
		"max_coins": coin_count_max * coin_amount_multiplier,
		"min_types": 2,
		"max_types": 5,
		"value_multiplier": 1.0
	}


func _drop_coins() -> void:
	var manager: Node = get_node_or_null("/root/CoinDropManager")
	if manager == null or not manager.has_method("drop_at"):
		return
	manager.call("drop_at", get_parent(), $AnimatedSprite2D.global_position, get_drop_profile())
