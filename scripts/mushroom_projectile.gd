extends Area2D
class_name MushroomProjectile

@export var speed: float = 155.0
@export var damage: int = 1
@export var lifetime: float = 3.0

@onready var hitbox: CollisionShape2D = $hurtbox
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var direction: Vector2 = Vector2.LEFT
var age: float = 0.0
var impacted: bool = false
var hit_targets: Dictionary = {}

func _ready() -> void:
	add_to_group("enemy_weapon_hitbox")
	area_entered.connect(_on_area_entered)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.play(&"projectileflying")

func set_direction(new_direction: Vector2) -> void:
	direction = new_direction.normalized()
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	if impacted:
		return
	age += delta
	global_position += direction * speed * delta
	if age >= lifetime:
		_impact()

func _on_area_entered(area: Area2D) -> void:
	if impacted or not area.name.to_lower().contains("hurtbox"):
		return
	var target: Node = area.get_parent()
	if not target.is_in_group("player") or hit_targets.has(target.get_instance_id()):
		return
	hit_targets[target.get_instance_id()] = true
	if target.has_method("handle_enemy_attack"):
		target.call("handle_enemy_attack", self, 130.0)
	elif target.has_method("receive_hit"):
		target.call("receive_hit", false)
	_impact()

func _impact() -> void:
	if impacted:
		return
	impacted = true
	hitbox.set_deferred("disabled", true)
	set_deferred("monitoring", false)
	animated_sprite.play(&"projectileimpact")

func _on_animation_finished() -> void:
	if impacted and animated_sprite.animation == &"projectileimpact":
		queue_free()
