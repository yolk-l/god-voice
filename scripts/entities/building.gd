extends StaticBody2D
class_name Building

@export var building_type: String = "shelter"
@export var is_completed: bool = false

var _storage: Dictionary = {}  # for chest/production buildings: {item_type: amount}
const MAX_STORAGE_SLOTS := 20
var _occupied: bool = false  # for research_table, smelter, loom

var _production_timer: float = 0.0

const PRODUCTION := {
	"farm": {"output": "berry", "base_amount": 2, "time": 30.0, "max": 8, "buff_key": "farm_output"},
	"lumber_camp": {"output": "wood", "base_amount": 2, "time": 35.0, "max": 8, "buff_key": ""},
	"quarry": {"output": "stone", "base_amount": 2, "time": 40.0, "max": 8, "buff_key": ""},
	"fishing_dock": {"output": "fish", "base_amount": 1, "time": 25.0, "max": 6, "buff_key": ""},
}

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	_draw_building_sprite(img)
	sprite.texture = ImageTexture.create_from_image(img)
	_update_visual()

func _process(delta: float) -> void:
	if not PRODUCTION.has(building_type) or not is_completed:
		return
	if GameManager.game_speed == 0.0:
		return
	var prod: Dictionary = PRODUCTION[building_type]
	var output_type: String = prod["output"]
	var stored: int = _storage.get(output_type, 0)
	if stored >= prod["max"]:
		return
	_production_timer += delta * GameManager.game_speed
	if _production_timer >= prod["time"]:
		_production_timer = 0.0
		var amount: int = prod["base_amount"]
		if prod["buff_key"] != "" and TechTree.get_buff(prod["buff_key"], 1.0) > 1.0:
			amount *= 2
		if not _storage.has(output_type):
			_storage[output_type] = 0
		_storage[output_type] = mini(_storage[output_type] + amount, prod["max"])

func _update_visual() -> void:
	if not sprite:
		return
	if not is_completed:
		sprite.modulate = Color(1, 1, 1, 0.5)
	else:
		sprite.modulate = Color.WHITE

func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		img.set_pixel(x, y, c)

func _draw_building_sprite(img: Image) -> void:
	match building_type:
		"shelter": _draw_shelter(img)
		"campfire": _draw_campfire(img)
		"chest": _draw_chest(img)
		"workbench": _draw_workbench(img)
		"research_table": _draw_research_table(img)
		"farm": _draw_farm(img)
		"smelter": _draw_smelter(img)
		"loom": _draw_loom(img)
		"lumber_camp": _draw_lumber_camp(img)
		"quarry": _draw_quarry(img)
		"fishing_dock": _draw_fishing_dock(img)
		_: img.fill(Color.WHITE)

func _draw_shelter(img: Image) -> void:
	var wall := Color(0.6, 0.4, 0.2)
	var roof := Color(0.5, 0.35, 0.18)
	var dr := Color(0.4, 0.28, 0.12)
	for y in range(7, 13):
		for x in range(2, 12):
			_px(img, x, y, wall)
	for y in range(1, 7):
		var half: int = 7 - y
		for x in range(7 - half, 7 + half):
			_px(img, x, y, roof if y % 2 == 0 else dr)
	_px(img, 6, 10, dr); _px(img, 7, 10, dr)
	_px(img, 6, 11, dr); _px(img, 7, 11, dr)
	_px(img, 6, 12, dr); _px(img, 7, 12, dr)

func _draw_campfire(img: Image) -> void:
	var wood := Color(0.45, 0.28, 0.12)
	var fire := Color(0.95, 0.6, 0.1)
	var hot := Color(1.0, 0.85, 0.2)
	var red := Color(0.9, 0.3, 0.05)
	for x in range(2, 12):
		_px(img, x, 11, wood)
		_px(img, x, 12, wood)
	_px(img, 3, 10, wood); _px(img, 10, 10, wood)
	for x in range(4, 10):
		for y in range(4, 10):
			var dist: float = Vector2(x - 6.5, y - 7.0).length()
			if dist < 3.5:
				if dist < 1.5:
					_px(img, x, y, hot)
				elif dist < 2.5:
					_px(img, x, y, fire)
				else:
					_px(img, x, y, red)
	_px(img, 6, 3, red); _px(img, 7, 2, fire)

func _draw_chest(img: Image) -> void:
	var body := Color(0.55, 0.38, 0.18)
	var dark := Color(0.4, 0.27, 0.12)
	var metal := Color(0.7, 0.65, 0.4)
	for x in range(1, 13):
		for y in range(4, 13):
			_px(img, x, y, body)
	for x in range(1, 13):
		_px(img, x, 4, dark)
		_px(img, x, 8, dark)
		_px(img, x, 12, dark)
	_px(img, 1, 4, dark); _px(img, 12, 4, dark)
	for y in range(4, 13):
		_px(img, 1, y, dark); _px(img, 12, y, dark)
	_px(img, 6, 7, metal); _px(img, 7, 7, metal)
	_px(img, 6, 8, metal); _px(img, 7, 8, metal)

func _draw_workbench(img: Image) -> void:
	var top := Color(0.5, 0.4, 0.3)
	var leg := Color(0.4, 0.3, 0.2)
	var tool := Color(0.6, 0.6, 0.65)
	for x in range(1, 13):
		for y in range(5, 8):
			_px(img, x, y, top)
	for y in range(8, 13):
		_px(img, 2, y, leg); _px(img, 3, y, leg)
		_px(img, 10, y, leg); _px(img, 11, y, leg)
	_px(img, 5, 4, tool); _px(img, 6, 3, tool); _px(img, 7, 2, tool)
	_px(img, 9, 4, tool); _px(img, 9, 3, tool)

func _draw_research_table(img: Image) -> void:
	var desk := Color(0.35, 0.45, 0.6)
	var leg := Color(0.3, 0.35, 0.5)
	var book := Color(0.8, 0.75, 0.5)
	var page := Color(0.95, 0.92, 0.85)
	for x in range(1, 13):
		for y in range(6, 9):
			_px(img, x, y, desk)
	for y in range(9, 13):
		_px(img, 2, y, leg); _px(img, 3, y, leg)
		_px(img, 10, y, leg); _px(img, 11, y, leg)
	for x in range(4, 10):
		for y in range(3, 6):
			_px(img, x, y, book if x == 4 or x == 9 or y == 3 else page)

func _draw_farm(img: Image) -> void:
	var soil := Color(0.45, 0.3, 0.15)
	var ds := Color(0.35, 0.22, 0.1)
	var plant := Color(0.35, 0.7, 0.2)
	var dp := Color(0.25, 0.55, 0.15)
	for x in range(0, 14):
		for y in range(0, 14):
			_px(img, x, y, soil if (x + y) % 3 != 0 else ds)
	for col in [2, 5, 8, 11]:
		_px(img, col, 3, plant); _px(img, col, 2, dp)
		_px(img, col, 7, plant); _px(img, col, 6, dp)
		_px(img, col, 11, plant); _px(img, col, 10, dp)
		_px(img, col - 1, 3, dp); _px(img, col + 1, 7, dp)

func _draw_smelter(img: Image) -> void:
	var brick := Color(0.6, 0.35, 0.2)
	var db := Color(0.5, 0.28, 0.15)
	var fire := Color(0.95, 0.55, 0.1)
	var hot := Color(1.0, 0.8, 0.2)
	for x in range(2, 12):
		for y in range(2, 13):
			_px(img, x, y, brick if (x + y) % 2 == 0 else db)
	for x in range(4, 10):
		for y in range(8, 12):
			_px(img, x, y, fire if y < 10 else hot)
	_px(img, 5, 1, Color(0.4, 0.4, 0.4)); _px(img, 6, 0, Color(0.35, 0.35, 0.35))
	_px(img, 7, 1, Color(0.4, 0.4, 0.4))

func _draw_loom(img: Image) -> void:
	var frame := Color(0.55, 0.4, 0.2)
	var thread := Color(0.85, 0.8, 0.65)
	var dt := Color(0.7, 0.65, 0.5)
	for y in range(1, 13):
		_px(img, 1, y, frame); _px(img, 2, y, frame)
		_px(img, 11, y, frame); _px(img, 12, y, frame)
	for x in range(1, 13):
		_px(img, x, 1, frame); _px(img, x, 12, frame)
	for x in range(3, 11):
		for y in range(2, 12):
			_px(img, x, y, thread if y % 2 == 0 else dt)

func _draw_lumber_camp(img: Image) -> void:
	var wood := Color(0.5, 0.35, 0.15)
	var dw := Color(0.4, 0.25, 0.1)
	var blade := Color(0.65, 0.65, 0.7)
	var leaf := Color(0.2, 0.55, 0.15)
	# log pile
	for x in range(1, 13):
		for y in range(9, 13):
			_px(img, x, y, wood if (x + y) % 2 == 0 else dw)
	# axe handle
	for y in range(2, 9):
		_px(img, 9, y, dw)
	# axe blade
	_px(img, 7, 2, blade); _px(img, 8, 2, blade)
	_px(img, 7, 3, blade); _px(img, 8, 3, blade); _px(img, 10, 3, blade)
	_px(img, 8, 4, blade); _px(img, 10, 4, blade)
	# stump
	for x in range(2, 6):
		for y in range(6, 9):
			_px(img, x, y, wood)
	_px(img, 2, 5, leaf); _px(img, 4, 5, leaf); _px(img, 3, 4, leaf)

func _draw_quarry(img: Image) -> void:
	var rock := Color(0.55, 0.55, 0.55)
	var dr := Color(0.4, 0.4, 0.42)
	var pick := Color(0.6, 0.6, 0.65)
	var handle := Color(0.45, 0.3, 0.15)
	# rock face
	for x in range(1, 13):
		for y in range(6, 13):
			_px(img, x, y, rock if (x * 3 + y) % 4 != 0 else dr)
	for x in range(2, 11):
		_px(img, x, 5, rock)
	for x in range(4, 9):
		_px(img, x, 4, dr)
	# pickaxe
	for y in range(1, 7):
		_px(img, 10, y, handle)
	_px(img, 8, 1, pick); _px(img, 9, 1, pick)
	_px(img, 11, 1, pick); _px(img, 12, 1, pick)
	_px(img, 9, 2, pick); _px(img, 11, 2, pick)

func _draw_fishing_dock(img: Image) -> void:
	var plank := Color(0.55, 0.4, 0.2)
	var dp := Color(0.45, 0.32, 0.15)
	var water := Color(0.3, 0.5, 0.75)
	var rope := Color(0.7, 0.65, 0.5)
	var fish_c := Color(0.6, 0.7, 0.8)
	# water below
	for x in range(0, 14):
		for y in range(10, 14):
			_px(img, x, y, water)
	# dock planks
	for x in range(2, 12):
		for y in range(5, 10):
			_px(img, x, y, plank if x % 3 != 0 else dp)
	# support posts
	for y in range(8, 13):
		_px(img, 3, y, dp); _px(img, 10, y, dp)
	# fishing rod
	for y in range(0, 6):
		_px(img, 8, y, dp)
	_px(img, 9, 0, rope); _px(img, 10, 1, rope); _px(img, 11, 2, rope)
	_px(img, 11, 3, rope); _px(img, 11, 4, fish_c)

func has_harvest() -> bool:
	if not PRODUCTION.has(building_type):
		return false
	var output_type: String = PRODUCTION[building_type]["output"]
	return _storage.get(output_type, 0) > 0

func harvest() -> Dictionary:
	if not PRODUCTION.has(building_type):
		return {}
	var output_type: String = PRODUCTION[building_type]["output"]
	var amount: int = _storage.get(output_type, 0)
	if amount <= 0:
		return {}
	_storage.erase(output_type)
	return {"type": output_type, "amount": amount}

# Storage (chest) methods
func add_item(type: String, amount: int) -> int:
	if building_type != "chest":
		return 0
	if not _storage.has(type) and _storage.size() >= MAX_STORAGE_SLOTS:
		return 0
	if not _storage.has(type):
		_storage[type] = 0
	_storage[type] += amount
	return amount

func remove_item(type: String, amount: int) -> int:
	if not _storage.has(type):
		return 0
	var removed: int = mini(amount, _storage[type])
	_storage[type] -= removed
	if _storage[type] <= 0:
		_storage.erase(type)
	return removed

func get_item_count(type: String) -> int:
	return _storage.get(type, 0)

func get_food_count() -> int:
	var count := 0
	for type in _storage:
		if type in ["berry", "mushroom", "raw_meat", "cooked_meat", "fish", "cooked_fish"]:
			count += _storage[type]
	return count

func take_food() -> String:
	for type in ["cooked_meat", "cooked_fish", "berry", "fish", "mushroom", "raw_meat"]:
		if _storage.has(type) and _storage[type] > 0:
			remove_item(type, 1)
			return type
	return ""

func is_full() -> bool:
	return _storage.size() >= MAX_STORAGE_SLOTS

func get_all_items() -> Dictionary:
	return _storage.duplicate()

# Research table methods
func is_occupied() -> bool:
	return _occupied

func set_occupied(occupied: bool) -> void:
	_occupied = occupied
