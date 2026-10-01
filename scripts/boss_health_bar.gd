extends CanvasLayer
class_name BossHealthBar

@onready var health_bar: TextureProgressBar = $HUD/BossHealthBar

func _ready() -> void:
	hide_bar()

func show_bar(max_health: int, current_health: int) -> void:
	health_bar.max_value = float(maxi(1, max_health))
	health_bar.value = float(clampi(current_health, 0, max_health))
	visible = true

func update_health(current_health: int, max_health: int) -> void:
	health_bar.max_value = float(maxi(1, max_health))
	var target_value: float = float(clampi(current_health, 0, max_health))
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(health_bar, "value", target_value, 0.18)

func hide_bar() -> void:
	visible = false
