extends Control
class_name PauseMenu

@export var open_on_ready: bool = false
@export var wait_for_player_landing: bool = false
var skip_startup_sequence: bool = false

@export_range(0.1, 1.5) var screen_fraction: float = 0.8
@export var device_scale_multiplier: float = 1.25
@export var device_vertical_offset: float = 0.0
@export_range(0.5, 1.0) var menu_content_scale: float = 0.9
@export var menu_content_vertical_offset: float = -14.0
@export var device_animation_path: NodePath
@export var device_on_animation: StringName = &"turn_on"
@export var screen_left: float = 113.0
@export var screen_top: float = 103.0
@export var screen_width: float = 104.0
@export var screen_height: float = 62.0
@export var row_height: float = 20.0

const PIXEL_FONT: Font = preload("res://assets/fonts/pixelfont.ttf")
const SCREEN_COLOR: Color = Color(0.96, 0.97, 0.91, 0.99)
const SCREEN_BORDER_COLOR: Color = Color(0.29, 0.66, 0.58, 1.0)
const SCREEN_TEXT_COLOR: Color = Color(0.12, 0.23, 0.22, 1.0)
const SCREEN_MUTED_COLOR: Color = Color(0.34, 0.48, 0.44, 1.0)
const SCREEN_ACCENT_COLOR: Color = Color(0.52, 0.83, 0.68, 1.0)

@onready var artwork: TextureRect = $TextureRect

var menu_scroll: ScrollContainer
var menu_list: VBoxContainer
var title_label: Label
var options_visible: bool = false
var menu_open: bool = false
var main_buttons: Array[Button] = []
var options_buttons: Array[Button] = []
var pause_open_pending: bool = false
var menu_background: Panel
var selector: ColorRect
var battery_empty: ColorRect
var battery_charge: ColorRect
var battery_ratio: float = 1.0
var tracked_player: PlayerController = null
var coin_row: Control
var coin_icon: AnimatedSprite2D
var coin_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	artwork.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	artwork.position = Vector2.ZERO
	artwork.size = Vector2(320.0, 308.0)
	_build_menu()
	_layout_device()
	get_viewport().size_changed.connect(_layout_device)
	_connect_device_animation()
	call_deferred("_connect_player_health")
	call_deferred("_connect_currency")
	visible = false
	if skip_startup_sequence:
		return
	call_deferred("_play_startup_sequence")
	if open_on_ready:
		call_deferred("open_pause_menu")

func _layout_device() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var base_size: Vector2 = Vector2(320.0, 308.0)
	var scale_factor: float = minf(viewport_size.x * screen_fraction / base_size.x, viewport_size.y * screen_fraction / base_size.y) * device_scale_multiplier
	var device_size: Vector2 = base_size * scale_factor
	var device_position: Vector2 = (viewport_size - device_size) * 0.5
	device_position.y += device_vertical_offset
	artwork.position = device_position
	artwork.scale = Vector2.ONE * scale_factor
	if menu_scroll != null:
		var screen_position: Vector2 = device_position + Vector2(screen_left, screen_top) * scale_factor
		var content_scale: float = scale_factor * menu_content_scale
		var content_size: Vector2 = Vector2(screen_width, screen_height) * menu_content_scale
		var content_position: Vector2 = screen_position + (Vector2(screen_width, screen_height) - content_size) * 0.5
		content_position.y += menu_content_vertical_offset * scale_factor
		menu_background.position = content_position
		menu_background.size = Vector2(screen_width, screen_height)
		menu_background.scale = Vector2.ONE * content_scale
		menu_scroll.position = content_position + Vector2(7.0, 3.0) * content_scale
		menu_scroll.size = Vector2(screen_width - 12.0, screen_height - 3.0)
		menu_scroll.scale = Vector2.ONE * content_scale
		selector.position = content_position + Vector2(3.0, 6.0) * content_scale
		selector.size = Vector2(2.0, 11.0) * content_scale
		var artwork_pixel_scale: Vector2 = Vector2(320.0 / 85.0, 308.0 / 85.0) * scale_factor
		battery_empty.position = device_position + Vector2(53.0, 20.0) * artwork_pixel_scale
		battery_empty.size = Vector2(3.0, 1.0) * artwork_pixel_scale
		battery_charge.position = battery_empty.position
		battery_charge.size = Vector2(battery_empty.size.x * battery_ratio, battery_empty.size.y)
	if coin_row != null:
		# Sit the coin count on the device screen strip, just left of the battery.
		coin_row.position = device_position + Vector2(143.0, 66.0) * scale_factor
		coin_row.scale = Vector2.ONE * scale_factor

func _build_menu() -> void:
	menu_background = Panel.new()
	menu_background.name = "ModernScreen"
	menu_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var screen_style: StyleBoxFlat = _style_box(SCREEN_COLOR, SCREEN_BORDER_COLOR)
	screen_style.set_border_width_all(1)
	screen_style.corner_radius_top_left = 2
	screen_style.corner_radius_top_right = 2
	screen_style.corner_radius_bottom_left = 2
	screen_style.corner_radius_bottom_right = 2
	menu_background.add_theme_stylebox_override("panel", screen_style)
	add_child(menu_background)

	menu_scroll = ScrollContainer.new()
	menu_scroll.name = "DeviceScreenScroll"
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.clip_contents = true
	menu_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(menu_scroll)

	menu_list = VBoxContainer.new()
	menu_list.name = "MenuList"
	menu_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_list.add_theme_constant_override("separation", 3)
	menu_scroll.add_child(menu_list)

	selector = ColorRect.new()
	selector.name = "MenuSelector"
	selector.color = SCREEN_ACCENT_COLOR
	selector.visible = false
	selector.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(selector)

	title_label = Label.new()
	title_label.text = "PAUSED"
	title_label.visible = false
	title_label.add_theme_font_override("font", PIXEL_FONT)
	title_label.add_theme_font_size_override("font_size", 7)
	title_label.add_theme_color_override("font_color", SCREEN_TEXT_COLOR)
	title_label.custom_minimum_size = Vector2.ZERO
	menu_list.add_child(title_label)

	battery_empty = ColorRect.new()
	battery_empty.name = "BatteryInterior"
	battery_empty.color = Color(0.08, 0.18, 0.15, 1.0)
	battery_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(battery_empty)
	battery_charge = ColorRect.new()
	battery_charge.name = "BatteryCharge"
	battery_charge.color = SCREEN_ACCENT_COLOR
	battery_charge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(battery_charge)
	_build_coin_counter()
	_build_main_menu()

func _build_coin_counter() -> void:
	coin_row = Control.new()
	coin_row.name = "CoinCounter"
	coin_row.size = Vector2(52.0, 22.0)
	coin_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(coin_row)

	coin_icon = AnimatedSprite2D.new()
	coin_icon.name = "CoinIcon"
	coin_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coin_icon.position = Vector2(0.0, 11.0)
	var registry: Node = get_node_or_null("/root/CoinRegistry")
	if registry != null:
		var data: CoinTypeData = registry.call("get_type", &"gold") as CoinTypeData
		if data != null and data.frames != null:
			coin_icon.sprite_frames = data.frames
			coin_icon.play(&"coin")
	coin_row.add_child(coin_icon)

	coin_label = Label.new()
	coin_label.name = "CoinCount"
	coin_label.text = "0"
	coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coin_label.add_theme_font_override("font", PIXEL_FONT)
	coin_label.add_theme_font_size_override("font_size", 11)
	coin_label.add_theme_color_override("font_color", SCREEN_TEXT_COLOR)
	coin_label.add_theme_color_override("font_outline_color", SCREEN_COLOR)
	coin_label.add_theme_constant_override("outline_size", 2)
	coin_label.position = Vector2(12.0, 0.0)
	coin_label.size = Vector2(40.0, 22.0)
	coin_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_row.add_child(coin_label)

func _build_main_menu() -> void:
	_clear_menu_rows()
	options_visible = false
	var play_button: Button = _make_button("RESUME", 0)
	play_button.pressed.connect(resume_game)
	menu_list.add_child(play_button)
	main_buttons.append(play_button)
	var options_button: Button = _make_button("OPTIONS", 1)
	options_button.pressed.connect(_show_options)
	menu_list.add_child(options_button)
	main_buttons.append(options_button)
	var turn_off_button: Button = _make_button("POWER OFF", 2)
	turn_off_button.pressed.connect(_turn_off)
	menu_list.add_child(turn_off_button)
	main_buttons.append(turn_off_button)
	_focus_first(main_buttons)

func _turn_off() -> void:
	get_tree().quit()

func _show_options() -> void:
	_clear_menu_rows()
	options_visible = true
	var controls_button: Button = _make_button("CONTROLS", 0)
	controls_button.tooltip_text = "Control settings"
	menu_list.add_child(controls_button)
	options_buttons.append(controls_button)
	var back_button: Button = _make_button("< BACK", 1)
	back_button.pressed.connect(_show_main_menu)
	menu_list.add_child(back_button)
	options_buttons.append(back_button)
	_focus_first(options_buttons)

func _show_main_menu() -> void:
	_build_main_menu()

func _clear_menu_rows() -> void:
	for child: Node in menu_list.get_children():
		if child == title_label:
			continue
		child.queue_free()
	main_buttons.clear()
	options_buttons.clear()

func _make_button(label_text: String, selector_row: int) -> Button:
	var button: Button = Button.new()
	button.text = label_text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.set_meta("selector_row", selector_row)
	button.custom_minimum_size = Vector2(0.0, 14.0)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_entered.connect(_ensure_button_visible.bind(button))
	button.focus_entered.connect(_update_selector_for_button.bind(button))
	button.add_theme_font_override("font", PIXEL_FONT)
	button.add_theme_font_size_override("font_size", 8)
	button.add_theme_color_override("font_color", SCREEN_TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", SCREEN_TEXT_COLOR)
	button.add_theme_color_override("font_focus_color", SCREEN_TEXT_COLOR)
	button.add_theme_color_override("font_pressed_color", SCREEN_TEXT_COLOR)
	button.add_theme_stylebox_override("normal", _style_box(Color(0.96, 0.97, 0.91, 0.0), Color(0.29, 0.53, 0.46, 0.25)))
	button.add_theme_stylebox_override("hover", _style_box(Color(0.84, 0.94, 0.85, 1.0), SCREEN_BORDER_COLOR))
	button.add_theme_stylebox_override("focus", _style_box(SCREEN_ACCENT_COLOR, SCREEN_BORDER_COLOR))
	button.add_theme_stylebox_override("pressed", _style_box(Color(0.77, 0.91, 0.78, 1.0), SCREEN_BORDER_COLOR))
	return button

func _style_box(fill: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 1
	style.corner_radius_top_right = 1
	style.corner_radius_bottom_left = 1
	style.corner_radius_bottom_right = 1
	style.content_margin_left = 3.0
	style.content_margin_right = 3.0
	return style

func _update_selector_for_button(button: Button) -> void:
	if selector == null or not is_instance_valid(button):
		return
	var selector_row: int = int(button.get_meta("selector_row", 0))
	var row_positions: Array[float] = [2.0, 14.0, 24.0]
	var row_y: float = row_positions[mini(selector_row, row_positions.size() - 1)]
	selector.position.y = menu_scroll.position.y + row_y * screen_height / 33.0 * menu_scroll.scale.y

func _ensure_button_visible(button: Button) -> void:
	if menu_scroll != null and is_instance_valid(button):
		menu_scroll.ensure_control_visible(button)

func _focus_first(buttons: Array[Button]) -> void:
	if buttons.is_empty():
		return
	buttons[0].grab_focus()
	menu_scroll.ensure_control_visible(buttons[0])

func _connect_player_health() -> void:
	tracked_player = get_tree().get_first_node_in_group("player") as PlayerController
	if tracked_player == null:
		return
	if not tracked_player.health_changed.is_connected(_on_player_health_changed):
		tracked_player.health_changed.connect(_on_player_health_changed)
	_on_player_health_changed(tracked_player.health, tracked_player.max_health)

func _connect_currency() -> void:
	var currency: Node = get_node_or_null("/root/CurrencyManager")
	if currency != null and currency.has_signal("currency_changed") and not currency.currency_changed.is_connected(_on_currency_changed):
		currency.currency_changed.connect(_on_currency_changed)
	_refresh_coin_count()

func _on_currency_changed(_total: int, _delta: int) -> void:
	_refresh_coin_count()

func _refresh_coin_count() -> void:
	if coin_label == null:
		return
	coin_label.text = str(_current_coin_count())

func _current_coin_count() -> int:
	var currency: Node = get_node_or_null("/root/CurrencyManager")
	if currency == null:
		return 0
	return int(currency.get("total_currency"))

func _on_player_health_changed(current_health: int, maximum_health: int) -> void:
	battery_ratio = clampf(float(current_health) / float(maximum_health), 0.0, 1.0) if maximum_health > 0 else 0.0
	if battery_empty != null and battery_charge != null:
		battery_charge.size = Vector2(battery_empty.size.x * battery_ratio, battery_empty.size.y)

func set_startup_sequence_enabled(enabled: bool) -> void:
	skip_startup_sequence = not enabled

func _play_startup_sequence() -> void:
	if skip_startup_sequence:
		return
	_pause_music(true)
	var player: Node = get_tree().get_first_node_in_group("player")
	var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D if player != null else null
	if camera != null:
		camera.zoom = Vector2(6.6, 6.6)
	var player_body: CharacterBody2D = player as CharacterBody2D
	if wait_for_player_landing and player_body != null:
		while is_instance_valid(player_body) and not player_body.is_on_floor():
			await get_tree().physics_frame
	if player != null and player.has_method("play_menu_animation"):
		var played: bool = bool(player.call("play_menu_animation", &"pause", Callable(self, "_start_startup_resume")))
		if played:
			return
	_start_startup_resume()

func _start_startup_resume() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("play_menu_animation"):
		var played: bool = bool(player.call("play_menu_animation", &"resume", Callable(player, "finish_menu_resume"), Callable(self, "_start_music"), Callable(self, "_zoom_out_startup")))
		if played:
			return
	_start_music()

func _zoom_out_startup() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		var zoom_tween: Tween = create_tween()
		zoom_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		zoom_tween.tween_property(camera, "zoom", Vector2(3.3, 3.3), 0.6)

func _start_music() -> void:
	_pause_music(false)

func open_pause_menu() -> void:
	if menu_open or pause_open_pending:
		return
	pause_open_pending = true
	var player: Node = get_tree().get_first_node_in_group("player")
	var player_busy: bool = false
	if player != null:
		player_busy = bool(player.get("elevator_ride_active")) or bool(player.get("intro_run_active")) or bool(player.get("exit_run_active")) or bool(player.get("teleport_locked"))
	if player != null and player.has_method("play_menu_animation") and not player_busy:
		var played: bool = bool(player.call("play_menu_animation", &"pause", Callable(self, "_finish_pause_open")))
		if played:
			return
	_finish_pause_open()

func _finish_pause_open() -> void:
	pause_open_pending = false
	menu_open = true
	options_visible = false
	_build_main_menu()
	if tracked_player == null:
		_connect_player_health()
	if tracked_player != null:
		_on_player_health_changed(tracked_player.health, tracked_player.max_health)
	_refresh_coin_count()
	var canvas_layer: CanvasLayer = get_parent() as CanvasLayer
	if canvas_layer != null:
		canvas_layer.visible = true
	visible = true
	_layout_device()
	_pause_music(true)
	get_tree().paused = true

func resume_game() -> void:
	if not menu_open:
		return
	menu_open = false
	visible = false
	get_tree().paused = false
	_pause_music(false)
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("play_menu_animation"):
		var played: bool = bool(player.call("play_menu_animation", &"resume", Callable(player, "finish_menu_resume")))
		if played:
			return
	_play_put_away_hook()

func _input(event: InputEvent) -> void:
	var escape_pressed: bool = event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE and (event as InputEventKey).pressed
	if event.is_action_pressed("ui_cancel") or escape_pressed:
		if not menu_open:
			open_pause_menu()
		elif options_visible:
			_show_main_menu()
		else:
			resume_game()
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not menu_open:
		open_pause_menu()

func _pause_music(should_pause: bool) -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	var music: AudioStreamPlayer = current_scene.get_node_or_null("BackgroundMusic") as AudioStreamPlayer
	if music != null:
		if should_pause:
			# Keep the playback instance alive; stop() resets the track to its start.
			music.stream_paused = true
		else:
			music.stream_paused = false
			if not music.playing:
				music.play()

func _play_put_away_hook() -> void:
	# Hook for the existing device put-away animation when that animation is added.
	var animator: AnimationPlayer = get_node_or_null("../AnimationPlayer") as AnimationPlayer
	if animator != null and animator.has_animation("put_away"):
		animator.play("put_away")

func _connect_device_animation() -> void:
	if device_animation_path.is_empty():
		return
	var animation_node: Node = get_node_or_null(device_animation_path)
	if animation_node is AnimatedSprite2D:
		var animated_sprite: AnimatedSprite2D = animation_node as AnimatedSprite2D
		if not animated_sprite.animation_finished.is_connected(_on_device_sprite_finished):
			animated_sprite.animation_finished.connect(_on_device_sprite_finished)
	elif animation_node is AnimationPlayer:
		var animation_player: AnimationPlayer = animation_node as AnimationPlayer
		if not animation_player.animation_finished.is_connected(_on_device_animation_finished):
			animation_player.animation_finished.connect(_on_device_animation_finished)

func _on_device_sprite_finished() -> void:
	var animation_node: AnimatedSprite2D = get_node_or_null(device_animation_path) as AnimatedSprite2D
	if animation_node != null and animation_node.animation == device_on_animation:
		open_pause_menu()

func _on_device_animation_finished(animation_name: StringName) -> void:
	if animation_name == device_on_animation:
		open_pause_menu()

func trigger_from_device_animation() -> void:
	# Connect this to the pull-out/turn-on animation_finished callback.
	open_pause_menu()
