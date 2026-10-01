extends AnimatedSprite2D
class_name EvilWizardSpellEffect

signal effect_finished(animation_name: StringName)

@onready var hitbox: Area2D = $Hitbox
@onready var hit_shape: CollisionShape2D = $Hitbox/CollisionShape2D

var auto_free: bool = false
var thunder_active: bool = false

func _ready() -> void:
	visible = false
	hit_shape.disabled = true
	hitbox.monitoring = false
	frame_changed.connect(_on_frame_changed)
	animation_finished.connect(_on_animation_finished)

func play_effect(animation_name: StringName, should_auto_free: bool = false) -> void:
	auto_free = should_auto_free
	thunder_active = animation_name == &"thunderstrike"
	visible = true
	play(animation_name)

func stop_effect() -> void:
	_set_hitbox_active(false)
	stop()
	visible = false

func _on_frame_changed() -> void:
	if not thunder_active:
		return
	_set_hitbox_active(frame >= 5 and frame <= 7)

func _on_animation_finished() -> void:
	var finished_animation: StringName = animation
	_set_hitbox_active(false)
	visible = false
	effect_finished.emit(finished_animation)
	if auto_free:
		queue_free()

func _set_hitbox_active(active: bool) -> void:
	hit_shape.set_deferred("disabled", not active)
	hitbox.set_deferred("monitoring", active)
