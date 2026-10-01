extends StaticBody2D
class_name CaveGate

signal opened_signal

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var opening: bool = false
var opened: bool = false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 2 | 8
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.play(&"shut")


func open_gate() -> void:
	if opening or opened:
		return
	opening = true
	animated_sprite.play(&"opening")


func _on_animation_finished() -> void:
	if not opening or animated_sprite.animation != &"opening":
		return
	opening = false
	opened = true
	collision_layer = 0
	collision_mask = 0
	collision_shape.set_deferred("disabled", true)
	animated_sprite.play(&"open")
	hide()
	opened_signal.emit()
