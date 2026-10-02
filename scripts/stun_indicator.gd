extends Label
class_name StunIndicator

func play_for(duration: float) -> void:
	text = "Zz"
	position = Vector2(-10.0, -54.0)
	size = Vector2(24.0, 16.0)
	pivot_offset = size * 0.5
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	add_theme_font_size_override("font_size", 12)
	add_theme_color_override("font_color", Color(1.0, 0.88, 0.24, 1.0))
	add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.16, 1.0))
	add_theme_constant_override("outline_size", 2)
	var motion: Tween = create_tween().set_loops().bind_node(self)
	motion.tween_property(self, "position:y", -60.0, 0.22).set_trans(Tween.TRANS_SINE)
	motion.parallel().tween_property(self, "rotation_degrees", -9.0, 0.22)
	motion.tween_property(self, "position:y", -54.0, 0.22).set_trans(Tween.TRANS_SINE)
	motion.parallel().tween_property(self, "rotation_degrees", 9.0, 0.22)
	var timer: SceneTreeTimer = get_tree().create_timer(duration)
	timer.timeout.connect(queue_free, CONNECT_ONE_SHOT)
