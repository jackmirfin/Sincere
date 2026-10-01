extends Node

const COIN_ASSET_ROOT: String = "res://assets/items/coins"

var _types: Dictionary = {}
var _initialized: bool = false

func _ready() -> void:
	_build_registry()

func _build_registry() -> void:
	if _initialized and not _types.is_empty():
		return
	var root: DirAccess = DirAccess.open(COIN_ASSET_ROOT)
	if root == null:
		_initialized = false
		push_warning("CoinRegistry: %s does not exist" % COIN_ASSET_ROOT)
		return
	_initialized = true
	for folder_name: String in root.get_directories():
		var data: CoinTypeData = _load_coin_type(folder_name)
		if data != null:
			_types[data.stable_id] = data

func _load_coin_type(folder_name: String) -> CoinTypeData:
	var directory: DirAccess = DirAccess.open(COIN_ASSET_ROOT + "/" + folder_name)
	if directory == null:
		push_warning("CoinRegistry: unable to open %s" % folder_name)
		return null
	var files: Array[String] = []
	for file_name: String in directory.get_files():
		if file_name.to_lower().ends_with(".png"):
			files.append(file_name)
	if files.size() != 6:
		push_warning("CoinRegistry: %s contains %d PNG frames; expected exactly 6" % [folder_name, files.size()])
		return null
	files.sort_custom(func(a: String, b: String) -> bool:
		return _frame_number(a, folder_name) < _frame_number(b, folder_name)
	)
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation(&"coin")
	frames.set_animation_speed(&"coin", 11.0)
	frames.set_animation_loop(&"coin", true)
	for file_name: String in files:
		var texture: Texture2D = load("%s/%s/%s" % [COIN_ASSET_ROOT, folder_name, file_name]) as Texture2D
		if texture == null:
			push_warning("CoinRegistry: unable to load %s/%s" % [folder_name, file_name])
			return null
		frames.add_frame(&"coin", texture)
	var data: CoinTypeData = CoinTypeData.new()
	data.stable_id = StringName(folder_name)
	data.display_name = folder_name.capitalize()
	data.source_folder = COIN_ASSET_ROOT + "/" + folder_name
	data.frames = frames
	data.currency_value = 1
	data.selection_weight = 1.0
	if folder_name.to_lower() == "biggold":
		data.visual_scale = Vector2(0.5, 0.5)
	return data

func _frame_number(file_name: String, folder_name: String) -> int:
	var stem: String = file_name.get_basename()
	var suffix: String = stem.trim_prefix(folder_name)
	if suffix.is_valid_int():
		return int(suffix)
	return 999999

func get_type(stable_id: StringName) -> CoinTypeData:
	_build_registry()
	return _types.get(stable_id) as CoinTypeData

func get_type_ids() -> Array[StringName]:
	_build_registry()
	var ids: Array[StringName] = []
	for key: Variant in _types.keys():
		ids.append(key as StringName)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids
