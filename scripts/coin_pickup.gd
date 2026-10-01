extends CharacterBody2D
class_name CoinPickup

const COIN_PICKUP_SOUND: AudioStream = preload("res://assets/sounds/coinpickup.mp3")

signal collected(value: int, stable_id: StringName)

@export var attraction_radius: float = 64.0
@export var attraction_speed: float = 260.0
@export var attraction_acceleration: float = 900.0
@export var initial_collection_delay: float = 0.20
@export var gravity: float = 620.0
@export var max_bounces: int = 2

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collection_area: Area2D = $CollectionArea

var stable_id: StringName = &""
var value_multiplier: float = 1.0
var coin_type: CoinTypeData
var age: float = 0.0
var bounces: int = 0
var attracting: bool = false
var collected_once: bool = false
var settled: bool = false

func _ready() -> void:
	collection_area.body_entered.connect(_on_collection_body_entered)
	if not stable_id.is_empty():
		_apply_coin_type()
	animated_sprite.play(&"coin")
	animated_sprite.frame = randi_range(0, 5)

func configure(coin_id: StringName, launch_velocity: Vector2, multiplier: float = 1.0) -> void:
	stable_id = coin_id
	value_multiplier = multiplier
	velocity = launch_velocity
	if is_node_ready():
		_apply_coin_type()

func _physics_process(delta: float) -> void:
	age += delta
	if not attracting:
		velocity.y += gravity * delta
		move_and_slide()
		if is_on_floor():
			if absf(velocity.y) > 20.0 and bounces < max_bounces:
				velocity.y = -absf(velocity.y) * 0.42
				velocity.x *= 0.72
				bounces += 1
			else:
				velocity.y = 0.0
				velocity.x = move_toward(velocity.x, 0.0, 80.0 * delta)
				settled = true
	if settled and age >= initial_collection_delay:
		var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
		if player != null:
			var distance: float = global_position.distance_to(player.global_position)
			if distance <= attraction_radius:
				attracting = true
				velocity = velocity.move_toward(global_position.direction_to(player.global_position) * attraction_speed, attraction_acceleration * delta)
				global_position += velocity * delta
				if distance <= 8.0:
					_collect()

func _on_collection_body_entered(body: Node2D) -> void:
	if not settled or age < initial_collection_delay or not body.is_in_group("player"):
		return
	_collect()

func _collect() -> void:
	if collected_once:
		return
	collected_once = true
	var base_value: int = coin_type.currency_value if coin_type != null else 1
	var value: int = maxi(1, roundi(base_value * value_multiplier))
	var currency_manager: Node = get_node_or_null("/root/CurrencyManager")
	if currency_manager != null:
		if currency_manager.has_method("record_coin"):
			currency_manager.call("record_coin", value)
		else:
			currency_manager.call("add_currency", value)
	var audio: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	audio.stream = COIN_PICKUP_SOUND
	audio.volume_db = 4.0
	get_tree().root.add_child(audio)
	audio.global_position = global_position
	audio.finished.connect(audio.queue_free)
	audio.play()
	collected.emit(value, stable_id)
	queue_free()

func _apply_coin_type() -> void:
	var registry: Node = get_node_or_null("/root/CoinRegistry")
	if registry == null:
		return
	coin_type = registry.call("get_type", stable_id) as CoinTypeData
	if coin_type == null:
		return
	animated_sprite.sprite_frames = coin_type.frames
	animated_sprite.scale = coin_type.visual_scale
	animated_sprite.animation = &"coin"
	animated_sprite.frame = randi_range(0, 5)
	animated_sprite.play()
