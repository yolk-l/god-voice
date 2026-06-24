extends Area2D

signal depleted
signal regenerated

@export var resource_type: String = "berry"
@export var resource_category: String = "food"
@export var max_amount: int = 5
@export var current_amount: int = 5
@export var gather_time: float = 2.0
@export var gather_amount: int = 1
@export var regenerate: bool = true
@export var regen_rate: float = 0.5
@export var regen_delay: float = 30.0

var is_depleted: bool = false
var _regen_timer: float = 0.0
var _regen_waiting: bool = false

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	ResourceManager.register(self)
	_create_texture()
	_update_visual()

func _create_texture() -> void:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	match resource_type:
		"berry": _draw_berry(img)
		"wood": _draw_tree(img)
		"stone": _draw_stone(img)
		"fiber": _draw_fiber(img)
		"mushroom": _draw_mushroom(img)
		"iron_ore": _draw_iron_ore(img)
		_: img.fill(Color.WHITE)
	sprite.texture = ImageTexture.create_from_image(img)

func _exit_tree() -> void:
	ResourceManager.unregister(self)

func _process(delta: float) -> void:
	if not is_depleted or not regenerate:
		return
	if GameManager.game_speed == 0.0:
		return
	var scaled_delta := delta * GameManager.game_speed
	if _regen_waiting:
		_regen_timer -= scaled_delta
		if _regen_timer <= 0.0:
			_regen_waiting = false
	else:
		current_amount += int(regen_rate * scaled_delta)
		if current_amount >= max_amount:
			current_amount = max_amount
			is_depleted = false
			_update_visual()
			regenerated.emit()

func gather() -> Dictionary:
	if is_depleted:
		return {}
	var amount: int = mini(gather_amount, current_amount)
	current_amount -= amount
	if current_amount <= 0:
		current_amount = 0
		is_depleted = true
		_regen_waiting = true
		_regen_timer = regen_delay
		_update_visual()
		depleted.emit()
	return {"type": resource_type, "amount": amount}

func _update_visual() -> void:
	if not sprite:
		return
	if is_depleted:
		sprite.modulate = Color(0.6, 0.6, 0.6, 0.5)
		sprite.scale = Vector2(0.7, 0.7)
	else:
		sprite.modulate = Color.WHITE
		sprite.scale = Vector2(1.0, 1.0)

func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		img.set_pixel(x, y, c)

func _draw_berry(img: Image) -> void:
	var g := Color(0.25, 0.55, 0.2)
	var r := Color(0.85, 0.15, 0.25)
	var dr := Color(0.6, 0.1, 0.2)
	for x in range(2, 10):
		for y in range(4, 10):
			_px(img, x, y, g)
	for y in range(2, 5):
		for x in range(3, 9):
			_px(img, x, y, g)
	_px(img, 3, 3, r); _px(img, 4, 3, r)
	_px(img, 6, 4, r); _px(img, 7, 4, r)
	_px(img, 4, 6, r); _px(img, 5, 6, r)
	_px(img, 7, 7, r); _px(img, 8, 7, r)
	_px(img, 3, 8, dr); _px(img, 6, 5, dr)

func _draw_tree(img: Image) -> void:
	var trunk := Color(0.45, 0.28, 0.12)
	var leaf := Color(0.2, 0.6, 0.15)
	var dl := Color(0.15, 0.45, 0.1)
	for y in range(8, 12):
		_px(img, 5, y, trunk); _px(img, 6, y, trunk)
	for x in range(2, 10):
		for y in range(1, 8):
			var dist: float = Vector2(x - 5.5, y - 4.0).length()
			if dist < 4.0:
				_px(img, x, y, leaf if (x + y) % 3 != 0 else dl)

func _draw_stone(img: Image) -> void:
	var c1 := Color(0.6, 0.6, 0.6)
	var c2 := Color(0.5, 0.5, 0.52)
	var hi := Color(0.75, 0.75, 0.75)
	for x in range(2, 10):
		for y in range(4, 10):
			_px(img, x, y, c1)
	for x in range(3, 9):
		_px(img, x, 3, c1)
	for x in range(4, 8):
		_px(img, x, 2, c1)
	_px(img, 3, 4, hi); _px(img, 4, 4, hi); _px(img, 4, 5, hi)
	_px(img, 7, 6, c2); _px(img, 8, 7, c2); _px(img, 6, 8, c2)

func _draw_fiber(img: Image) -> void:
	var g1 := Color(0.5, 0.75, 0.25)
	var g2 := Color(0.4, 0.65, 0.2)
	var g3 := Color(0.55, 0.8, 0.3)
	for i in [2, 4, 6, 8]:
		for y in range(3, 11):
			var c: Color = g1 if i % 4 == 0 else g2
			if y < 5:
				c = g3
			_px(img, i, y, c)
			if y > 4:
				_px(img, i + 1, y, c)

func _draw_mushroom(img: Image) -> void:
	var cap := Color(0.7, 0.35, 0.2)
	var dc := Color(0.55, 0.25, 0.15)
	var stem := Color(0.9, 0.85, 0.75)
	var dot := Color(0.95, 0.9, 0.7)
	for x in range(2, 10):
		for y in range(2, 6):
			var dist: float = abs(x - 5.5)
			if dist < 4.5 - y * 0.3:
				_px(img, x, y, cap if (x + y) % 3 != 0 else dc)
	_px(img, 4, 3, dot); _px(img, 7, 4, dot)
	for y in range(6, 11):
		_px(img, 5, y, stem); _px(img, 6, y, stem)

func _draw_iron_ore(img: Image) -> void:
	var rock := Color(0.4, 0.38, 0.35)
	var dr := Color(0.33, 0.3, 0.28)
	var ore := Color(0.75, 0.5, 0.25)
	for x in range(2, 10):
		for y in range(3, 10):
			_px(img, x, y, rock)
	for x in range(3, 9):
		_px(img, x, 2, rock)
	_px(img, 3, 4, ore); _px(img, 4, 4, ore)
	_px(img, 7, 6, ore); _px(img, 6, 6, ore)
	_px(img, 4, 8, ore); _px(img, 5, 7, ore)
	_px(img, 8, 5, dr); _px(img, 5, 9, dr); _px(img, 2, 7, dr)
