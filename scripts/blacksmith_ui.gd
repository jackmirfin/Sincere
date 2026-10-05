extends CanvasLayer
class_name BlacksmithUI

signal blacksmith_closed

const PIXEL_FONT: Font = preload("res://assets/fonts/pixelfont.ttf")
const BLACKSMITH_ART: Texture2D = preload("res://assets/ui/blacksmithui.png")
const COIN_SOUND: AudioStream = preload("res://assets/sounds/coinpickup.mp3")
const ART_REGION: Rect2 = Rect2(56.0, 89.0, 152.0, 87.0)
const FRAME_SIZE: Vector2 = Vector2(152.0, 87.0)
const TITLE_BOX: Rect2 = Rect2(24.0, 3.0, 104.0, 11.0)
const CLOSE_BOX: Rect2 = Rect2(127.0, 4.0, 15.0, 10.0)
const ITEM_BOX: Rect2 = Rect2(10.0, 18.0, 42.0, 31.0)
const STATS_BOX: Rect2 = Rect2(56.0, 18.0, 86.0, 31.0)
const ITEM_NAME_BOX: Rect2 = Rect2(12.0, 51.0, 38.0, 8.0)
const STATS_NAME_BOX: Rect2 = Rect2(59.0, 51.0, 82.0, 8.0)
const DESCRIPTION_BOX: Rect2 = Rect2(10.0, 63.0, 96.0, 16.0)
const TINKER_BOX: Rect2 = Rect2(108.0, 66.0, 34.0, 11.0)
const VIEWPORT_FRACTION: float = 0.72
const TINKER_COST: int = 50
const TEXT_COLOR: Color = Color(1.0, 0.94, 0.72, 1.0)
const MUTED_COLOR: Color = Color(0.78, 0.70, 0.58, 1.0)
const DISABLED_COLOR: Color = Color(0.48, 0.43, 0.38, 1.0)
const BORDER_COLOR: Color = Color(0.85, 0.72, 0.42, 1.0)
const BACKDROP_COLOR: Color = Color(0.0, 0.0, 0.0, 0.58)

var blacksmith_open: bool = false
var player: PlayerController = null
var backdrop: ColorRect
var window: Panel
var frame: TextureRect
var header_label: Label
var close_button: Button
var item_icon: TextureRect
var item_name_panel: Panel
var stats_name_panel: Panel
var item_name_label: Label
var stats_title_label: Label
var stats_label: Label
var instructions_label: Label
var tinker_button: Button
var coin_audio: AudioStreamPlayer


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	get_viewport().size_changed.connect(_layout)
	call_deferred("_layout")


func _build() -> void:
	backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = BACKDROP_COLOR
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)

	window = Panel.new()
	window.name = "Window"
	window.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(window)

	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = BLACKSMITH_ART
	atlas.region = ART_REGION
	frame = TextureRect.new()
	frame.name = "BlacksmithFrame"
	frame.texture = atlas
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(frame)

	header_label = _make_label("BLACKSMITH", TEXT_COLOR, 7)
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	window.add_child(header_label)

	close_button = _make_button("CloseButton", "X", 7)
	close_button.pressed.connect(close)
	window.add_child(close_button)

	item_icon = TextureRect.new()
	item_icon.name = "EquippedItemIcon"
	item_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(item_icon)

	var name_style: StyleBoxFlat = _style_box(Color(0.08, 0.045, 0.025, 0.92), Color(0.62, 0.40, 0.18, 1.0))
	name_style.set_border_width_all(1)
	name_style.corner_radius_top_left = 1
	name_style.corner_radius_top_right = 1
	name_style.corner_radius_bottom_left = 1
	name_style.corner_radius_bottom_right = 1
	item_name_panel = Panel.new()
	item_name_panel.name = "ItemNameBox"
	item_name_panel.add_theme_stylebox_override("panel", name_style)
	window.add_child(item_name_panel)
	stats_name_panel = Panel.new()
	stats_name_panel.name = "StatsNameBox"
	stats_name_panel.add_theme_stylebox_override("panel", name_style.duplicate() as StyleBox)
	window.add_child(stats_name_panel)

	item_name_label = _make_label("Sword", TEXT_COLOR, 5)
	item_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_name_panel.add_child(item_name_label)

	stats_title_label = _make_label("Stats", TEXT_COLOR, 5)
	stats_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_name_panel.add_child(stats_title_label)

	stats_label = _make_label("No stats yet", MUTED_COLOR, 4)
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	window.add_child(stats_label)

	instructions_label = _make_label("Tinker to randomise 3 stats\nPrice: 50 coins", TEXT_COLOR, 4)
	instructions_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	window.add_child(instructions_label)

	tinker_button = _make_button("TinkerButton", "Tinker", 7)
	tinker_button.pressed.connect(tinker)
	window.add_child(tinker_button)

	coin_audio = AudioStreamPlayer.new()
	coin_audio.stream = COIN_SOUND
	coin_audio.volume_db = 2.0
	add_child(coin_audio)

	var currency: Node = get_node_or_null("/root/CurrencyManager")
	if currency != null and currency.has_signal("currency_changed"):
		var currency_callable: Callable = Callable(self, "_on_currency_changed")
		if not currency.is_connected("currency_changed", currency_callable):
			currency.connect("currency_changed", currency_callable)


func _make_label(label_text: String, colour: Color, base_font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = label_text
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", base_font_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 1.0))
	label.add_theme_constant_override("outline_size", 3)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_button(node_name: String, button_text: String, base_font_size: int) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = button_text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", PIXEL_FONT)
	button.add_theme_font_size_override("font_size", base_font_size)
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", TEXT_COLOR)
	button.add_theme_color_override("font_pressed_color", TEXT_COLOR)
	button.add_theme_color_override("font_disabled_color", DISABLED_COLOR)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	var hover_style: StyleBoxFlat = _style_box(Color(1.0, 0.86, 0.46, 0.14), BORDER_COLOR)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", _style_box(Color(1.0, 0.72, 0.3, 0.24), BORDER_COLOR))
	return button


func _style_box(fill: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style


func _place(control: Control, box: Rect2, ui_scale: float) -> void:
	control.position = box.position * ui_scale
	control.size = box.size * ui_scale


func _layout() -> void:
	if backdrop == null or window == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	backdrop.position = Vector2.ZERO
	backdrop.size = viewport_size
	var ui_scale: float = viewport_size.x * VIEWPORT_FRACTION / FRAME_SIZE.x
	var frame_size: Vector2 = FRAME_SIZE * ui_scale
	window.position = (viewport_size - frame_size) * 0.5
	window.size = frame_size
	frame.position = Vector2.ZERO
	frame.size = frame_size

	header_label.add_theme_font_size_override("font_size", maxi(1, int(round(7.0 * ui_scale))))
	_place(header_label, Rect2(TITLE_BOX.position + Vector2(3.0, 0.0), Vector2(TITLE_BOX.size.x - 6.0, TITLE_BOX.size.y)), ui_scale)
	close_button.add_theme_font_size_override("font_size", maxi(1, int(round(7.0 * ui_scale))))
	_place(close_button, CLOSE_BOX, ui_scale)
	_place(item_icon, Rect2(ITEM_BOX.position + Vector2(4.0, 2.0), ITEM_BOX.size - Vector2(8.0, 4.0)), ui_scale)
	_place(item_name_panel, ITEM_NAME_BOX, ui_scale)
	item_name_label.add_theme_font_size_override("font_size", maxi(1, int(round(5.0 * ui_scale))))
	item_name_label.position = Vector2.ZERO
	item_name_label.size = item_name_panel.size
	_place(stats_name_panel, STATS_NAME_BOX, ui_scale)
	stats_title_label.add_theme_font_size_override("font_size", maxi(1, int(round(5.0 * ui_scale))))
	stats_title_label.position = Vector2.ZERO
	stats_title_label.size = stats_name_panel.size
	stats_label.add_theme_font_size_override("font_size", maxi(1, int(round(4.0 * ui_scale))))
	_place(stats_label, Rect2(STATS_BOX.position + Vector2(3.0, 2.0), STATS_BOX.size - Vector2(6.0, 4.0)), ui_scale)
	instructions_label.add_theme_font_size_override("font_size", maxi(1, int(round(4.0 * ui_scale))))
	_place(instructions_label, Rect2(DESCRIPTION_BOX.position + Vector2(2.0, 1.0), DESCRIPTION_BOX.size - Vector2(4.0, 2.0)), ui_scale)
	tinker_button.add_theme_font_size_override("font_size", maxi(1, int(round(7.0 * ui_scale))))
	_place(tinker_button, TINKER_BOX, ui_scale)


func open(p_player: PlayerController) -> void:
	player = p_player
	if player != null:
		player.set_teleport_locked(true)
	blacksmith_open = true
	visible = true
	_update_weapon_icon()
	_layout()
	_refresh()


func close() -> void:
	if not blacksmith_open:
		return
	blacksmith_open = false
	visible = false
	if player != null and is_instance_valid(player):
		player.set_teleport_locked(false)
	blacksmith_closed.emit()


func _update_weapon_icon() -> void:
	item_icon.texture = null
	var currency: Node = get_node_or_null("/root/CurrencyManager")
	if currency == null:
		return
	var icon_path: String = str(currency.get("equipped_weapon_icon_path"))
	if ResourceLoader.exists(icon_path):
		item_icon.texture = load(icon_path) as Texture2D


func tinker() -> bool:
	if not blacksmith_open:
		return false
	var currency: Node = get_node_or_null("/root/CurrencyManager")
	if currency == null or not bool(currency.call("tinker_equipped_weapon")):
		instructions_label.text = "Need 50 coins to tinker\nPrice: 50 coins"
		_refresh()
		return false
	if coin_audio != null:
		coin_audio.play()
	instructions_label.text = "Tinker to randomise 3 stats\nPrice: 50 coins"
	_refresh()
	return true


func _refresh() -> void:
	var currency: Node = get_node_or_null("/root/CurrencyManager")
	if currency == null:
		tinker_button.disabled = true
		return
	item_name_label.text = str(currency.get("equipped_weapon_name"))
	var stats_variant: Variant = currency.get("equipped_weapon_stats")
	var weapon_stats: Array[String] = []
	if stats_variant is Array:
		for stat: Variant in stats_variant:
			weapon_stats.append(String(stat))
	stats_label.text = "\n".join(weapon_stats) if not weapon_stats.is_empty() else "No stats yet"
	stats_label.add_theme_color_override("font_color", TEXT_COLOR if not weapon_stats.is_empty() else MUTED_COLOR)
	var balance: int = int(currency.get("total_currency"))
	tinker_button.disabled = balance < TINKER_COST
	if balance >= TINKER_COST:
		instructions_label.text = "Tinker to randomise 3 stats\nPrice: 50 coins"
	else:
		instructions_label.text = "Need 50 coins to tinker\nPrice: 50 coins"


func _on_currency_changed(_total: int, _delta: int) -> void:
	_refresh()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if not blacksmith_open:
		return
	var escape_pressed: bool = event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE and (event as InputEventKey).pressed
	if escape_pressed or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
