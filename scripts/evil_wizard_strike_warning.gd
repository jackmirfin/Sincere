extends Node2D
class_name EvilWizardStrikeWarning

const ATTACK_INDICATOR_SCENE: PackedScene = preload("res://scenes/attackindicator.tscn")
const SPELL_SCENE: PackedScene = preload("res://scenes/evilwizardspell.tscn")
const MARKER_TEXTURE: Texture2D = preload("res://assets/anims/attackmarker.png")

const INDICATOR_SCALE: Vector2 = Vector2(2.6, 2.6)
const HALO_SCALE: Vector2 = Vector2(4.4, 4.4)
const BEAM_HEIGHT: float = 240.0
const PULSE_SPEED: float = 0.16

var dead: bool = false
var wizard: Node2D
var pulse_tween: Tween = null

func setup(owner_wizard: Node2D) -> void:
	wizard = owner_wizard
	_add_warning_beam()
	_add_halo()
	var indicator: AnimatedSprite2D = ATTACK_INDICATOR_SCENE.instantiate() as AnimatedSprite2D
	indicator.position = Vector2(0.0, -38.0)
	indicator.scale = INDICATOR_SCALE
	indicator.modulate = Color(1.6, 1.45, 1.0, 1.0)
	add_child(indicator)
	_start_pulse()

func _add_warning_beam() -> void:
	var beam: Sprite2D = Sprite2D.new()
	beam.texture = MARKER_TEXTURE
	beam.region_enabled = true
	beam.region_rect = Rect2(64.0, 0.0, 16.0, 16.0)
	beam.centered = false
	beam.scale = Vector2(1.7, BEAM_HEIGHT / 16.0)
	beam.position = Vector2(-13.6, -BEAM_HEIGHT)
	beam.modulate = Color(1.0, 0.82, 0.25, 0.5)
	add_child(beam)

func _add_halo() -> void:
	var halo: AnimatedSprite2D = ATTACK_INDICATOR_SCENE.instantiate() as AnimatedSprite2D
	halo.position = Vector2(0.0, -34.0)
	halo.scale = HALO_SCALE
	halo.modulate = Color(1.0, 0.55, 0.2, 0.32)
	halo.z_index = -1
	add_child(halo)

func _start_pulse() -> void:
	pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.55), PULSE_SPEED)
	pulse_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), PULSE_SPEED)

func attack_indicator_frame_reached() -> void:
	if pulse_tween != null and pulse_tween.is_valid():
		pulse_tween.kill()
	if dead or wizard == null or not is_instance_valid(wizard):
		queue_free()
		return
	var strike: EvilWizardSpellEffect = SPELL_SCENE.instantiate() as EvilWizardSpellEffect
	get_parent().add_child(strike)
	strike.global_position = global_position + Vector2(0.0, -32.0)
	strike.play_effect(&"thunderstrike", true)
	dead = true
	queue_free()
