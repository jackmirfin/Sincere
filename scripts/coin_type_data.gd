extends Resource
class_name CoinTypeData

@export var stable_id: StringName
@export var display_name: String = "Coin"
@export var source_folder: String = ""
@export var frames: SpriteFrames
@export var currency_value: int = 1
@export var selection_weight: float = 1.0
@export var pickup_sound: AudioStream
@export var visual_scale: Vector2 = Vector2.ONE
