extends Area2D
class_name FlyingEyeProjectile

@export var damage: int = 10
@export var lifetime: float = 3.0
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
var velocity: Vector2 = Vector2.ZERO
var remaining: float = 0.0
var impacted: bool = false

func _ready() -> void:
	remaining = lifetime
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	animated_sprite.play(&"projectile")

func launch(direction: Vector2, speed: float) -> void:
	velocity = direction.normalized() * speed
	rotation = velocity.angle()

func _physics_process(delta: float) -> void:
	if impacted:
		return
	global_position += velocity * delta
	remaining -= delta
	if remaining <= 0.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if impacted or not area.get_parent().is_in_group("player"):
		return
	var target: Node = area.get_parent()
	if target.has_method("receive_hit"):
		target.call("receive_hit", false)
		if target.has_method("apply_knockback"):
			target.call("apply_knockback", 120.0, signf(target.global_position.x - global_position.x))
	_impact()

func _on_body_entered(body: Node2D) -> void:
	if impacted:
		return
	if body.is_in_group("player") and body.has_method("receive_hit"):
		body.call("receive_hit", false)
		_impact()

func _impact() -> void:
	impacted = true
	velocity = Vector2.ZERO
	animated_sprite.play(&"impact")
	get_tree().create_timer(0.5).timeout.connect(queue_free, CONNECT_ONE_SHOT)
