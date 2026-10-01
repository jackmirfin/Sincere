extends PointLight2D
class_name PlayerLight

@export var base_energy: float = 0.32
@export var flicker_amount: float = 0.035
@export var flicker_speed: float = 3.2
var elapsed: float = 0.0

func _ready() -> void:
	energy = base_energy
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
	elapsed += delta
	energy = base_energy + sin(elapsed * flicker_speed) * flicker_amount + sin(elapsed * flicker_speed * 1.73) * flicker_amount * 0.35
