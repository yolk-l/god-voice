extends Area2D

@export var item_type: String = ""
@export var item_amount: int = 1

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	_draw_item(img)
	sprite.texture = ImageTexture.create_from_image(img)

func pickup() -> Dictionary:
	var result: Dictionary = {"type": item_type, "amount": item_amount}
	queue_free()
	return result

func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < 8 and y >= 0 and y < 8:
		img.set_pixel(x, y, c)

func _draw_item(img: Image) -> void:
	match item_type:
		"berry":
			var r := Color(0.85, 0.15, 0.3)
			var g := Color(0.3, 0.6, 0.2)
			_px(img, 3, 1, g); _px(img, 4, 1, g)
			_px(img, 2, 2, r); _px(img, 3, 2, r); _px(img, 4, 2, r); _px(img, 5, 2, r)
			_px(img, 2, 3, r); _px(img, 3, 3, r); _px(img, 4, 3, r); _px(img, 5, 3, r)
			_px(img, 3, 4, r); _px(img, 4, 4, r)
		"wood":
			var w := Color(0.5, 0.32, 0.15)
			var l := Color(0.6, 0.4, 0.2)
			for x in range(1, 7):
				_px(img, x, 3, w); _px(img, x, 4, l)
			_px(img, 0, 3, l); _px(img, 7, 4, w)
			_px(img, 3, 2, l); _px(img, 4, 5, l)
		"stone":
			var s := Color(0.6, 0.6, 0.6)
			var h := Color(0.75, 0.75, 0.75)
			for x in range(2, 6):
				for y in range(2, 6):
					_px(img, x, y, s)
			_px(img, 3, 1, s); _px(img, 4, 1, s)
			_px(img, 2, 2, h); _px(img, 3, 2, h)
		"fiber":
			var g := Color(0.5, 0.75, 0.25)
			for i in [2, 4, 5]:
				_px(img, i, 2, g); _px(img, i, 3, g); _px(img, i, 4, g); _px(img, i, 5, g)
		"mushroom":
			var c := Color(0.7, 0.35, 0.2)
			var st := Color(0.9, 0.85, 0.75)
			_px(img, 3, 1, c); _px(img, 4, 1, c)
			_px(img, 2, 2, c); _px(img, 3, 2, c); _px(img, 4, 2, c); _px(img, 5, 2, c)
			_px(img, 3, 3, st); _px(img, 4, 3, st)
			_px(img, 3, 4, st); _px(img, 4, 4, st)
		"raw_meat":
			var m := Color(0.8, 0.3, 0.3)
			var f := Color(0.9, 0.85, 0.8)
			_px(img, 2, 2, m); _px(img, 3, 2, m); _px(img, 4, 2, m)
			_px(img, 2, 3, m); _px(img, 3, 3, m); _px(img, 4, 3, m); _px(img, 5, 3, m)
			_px(img, 3, 4, m); _px(img, 4, 4, m); _px(img, 5, 4, m)
			_px(img, 4, 2, f)
		"cooked_meat":
			var m := Color(0.55, 0.3, 0.15)
			var g := Color(0.7, 0.45, 0.2)
			_px(img, 2, 2, m); _px(img, 3, 2, m); _px(img, 4, 2, g)
			_px(img, 2, 3, m); _px(img, 3, 3, g); _px(img, 4, 3, m); _px(img, 5, 3, m)
			_px(img, 3, 4, m); _px(img, 4, 4, m); _px(img, 5, 4, g)
		"iron_ore":
			var r := Color(0.45, 0.4, 0.35)
			var o := Color(0.75, 0.5, 0.25)
			_px(img, 2, 2, r); _px(img, 3, 2, r); _px(img, 4, 2, r)
			_px(img, 2, 3, r); _px(img, 3, 3, o); _px(img, 4, 3, r); _px(img, 5, 3, r)
			_px(img, 3, 4, r); _px(img, 4, 4, o); _px(img, 5, 4, r)
		"iron_ingot":
			var i := Color(0.65, 0.65, 0.7)
			var h := Color(0.8, 0.8, 0.85)
			for x in range(1, 7):
				_px(img, x, 3, i); _px(img, x, 4, i)
			_px(img, 1, 3, h); _px(img, 2, 3, h)
		"cloth":
			var c := Color(0.85, 0.8, 0.65)
			var d := Color(0.7, 0.65, 0.5)
			for x in range(2, 6):
				for y in range(2, 6):
					_px(img, x, y, c if (x + y) % 2 == 0 else d)
		"rope":
			var r := Color(0.7, 0.6, 0.35)
			_px(img, 2, 2, r); _px(img, 3, 3, r); _px(img, 4, 4, r); _px(img, 5, 5, r)
			_px(img, 3, 2, r); _px(img, 4, 3, r); _px(img, 5, 4, r)
		_:
			var w := Color(0.9, 0.9, 0.9)
			for x in range(2, 6):
				for y in range(2, 6):
					_px(img, x, y, w)
