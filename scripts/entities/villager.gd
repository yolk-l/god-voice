extends CharacterBody2D
class_name Villager

signal died(villager: Villager)

const BASE_MOVE_SPEED := 50.0
const ARRIVE_DISTANCE := 8.0

@export var villager_name: String = "Villager"

var needs: VillagerNeeds
var inventory: VillagerInventory
var known_area: Dictionary = {}  # {Vector2i: true}
var home: Node = null
var current_action_name: String = "idle"
var equipment: Dictionary = {}  # {slot_name: item_name}  e.g. {"tool": "stone_axe"}

@onready var sprite: Sprite2D = $Sprite2D
@onready var status_label: Label = $StatusLabel

var _world: Node = null
var _ai: Node = null
var _move_target: Vector2 = Vector2.ZERO
var _has_target: bool = false

func _ready() -> void:
	needs = VillagerNeeds.new()
	inventory = VillagerInventory.new()
	needs.villager_died.connect(_on_died)
	_world = get_tree().current_scene.get_node("World")
	_reveal_initial_area()
	collision_layer = 0
	collision_mask = 0
	_create_texture()

func _create_texture() -> void:
	var img := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	var skin := Color(0.9, 0.75, 0.6)
	var shirt := Color(0.3, 0.55, 0.85)
	var pants := Color(0.3, 0.3, 0.45)
	var hair := Color(0.35, 0.2, 0.1)
	var _px := func(x: int, y: int, c: Color) -> void:
		if x >= 0 and x < 10 and y >= 0 and y < 10:
			img.set_pixel(x, y, c)
	_px.call(4, 0, hair); _px.call(5, 0, hair)
	_px.call(3, 1, hair); _px.call(4, 1, skin); _px.call(5, 1, skin); _px.call(6, 1, hair)
	_px.call(4, 2, skin); _px.call(5, 2, skin)
	_px.call(3, 3, shirt); _px.call(4, 3, shirt); _px.call(5, 3, shirt); _px.call(6, 3, shirt)
	_px.call(3, 4, shirt); _px.call(4, 4, shirt); _px.call(5, 4, shirt); _px.call(6, 4, shirt)
	_px.call(2, 4, skin); _px.call(7, 4, skin)
	_px.call(3, 5, shirt); _px.call(4, 5, shirt); _px.call(5, 5, shirt); _px.call(6, 5, shirt)
	_px.call(4, 6, pants); _px.call(5, 6, pants)
	_px.call(4, 7, pants); _px.call(5, 7, pants)
	_px.call(3, 8, pants); _px.call(4, 8, pants); _px.call(5, 8, pants); _px.call(6, 8, pants)
	_px.call(3, 9, pants); _px.call(6, 9, pants)
	sprite.texture = ImageTexture.create_from_image(img)

func _process(delta: float) -> void:
	needs.update(delta, GameManager.game_speed)
	_reveal_area()
	_update_status_label()

func _physics_process(delta: float) -> void:
	if GameManager.game_speed == 0.0:
		return
	if not _has_target:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var dist: float = global_position.distance_to(_move_target)
	if dist < ARRIVE_DISTANCE:
		_has_target = false
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var direction: Vector2 = global_position.direction_to(_move_target)
	var speed := BASE_MOVE_SPEED * needs.get_move_speed_multiplier() * GameManager.game_speed
	var terrain_cost := 1.0
	if _world:
		var tile_pos: Vector2i = Vector2i(global_position / 16.0)
		terrain_cost = _world.get_move_cost(tile_pos)
	speed /= terrain_cost
	velocity = direction * speed
	move_and_slide()

func navigate_to(target_pos: Vector2) -> void:
	_move_target = target_pos
	_has_target = true

func has_reached_target() -> bool:
	if not _has_target:
		return true
	return global_position.distance_to(_move_target) < ARRIVE_DISTANCE

func get_tile_position() -> Vector2i:
	return Vector2i(global_position / 16.0)

func _reveal_initial_area() -> void:
	var center: Vector2i = get_tile_position()
	for dx in range(-10, 11):
		for dy in range(-10, 11):
			known_area[center + Vector2i(dx, dy)] = true

func _reveal_area() -> void:
	var center: Vector2i = get_tile_position()
	var reveal_radius := 5
	if GameManager.is_night():
		reveal_radius = 3
	for dx in range(-reveal_radius, reveal_radius + 1):
		for dy in range(-reveal_radius, reveal_radius + 1):
			var tile: Vector2i = center + Vector2i(dx, dy)
			if not known_area.has(tile):
				known_area[tile] = true
			if _world:
				_world.request_chunk_at(tile)

func equip(slot: String, item: String) -> void:
	var old_item: String = equipment.get(slot, "")
	if old_item != "" and old_item != item:
		var added: int = inventory.add_item(old_item, 1)
		if added == 0:
			_spawn_drop(old_item, 1)
	equipment[slot] = item

func get_equipped(slot: String) -> String:
	return equipment.get(slot, "")

func has_equipped(item: String) -> bool:
	return item in equipment.values()

func owns_tool(item: String) -> bool:
	return has_equipped(item) or inventory.has_item(item, 1)

func equip_from_inventory(slot: String, item: String) -> bool:
	if inventory.has_item(item, 1):
		inventory.remove_item(item, 1)
		equip(slot, item)
		return true
	return false

func _on_died() -> void:
	EventLog.add(villager_name, "death", "%s has died" % villager_name)
	for slot in equipment:
		_spawn_drop(equipment[slot], 1)
	equipment.clear()
	var dropped: Array = inventory.drop_all()
	for item in dropped:
		_spawn_drop(item["type"], item["amount"])
	ResourceManager.release_all_for(self)
	died.emit(self)
	queue_free()

func _spawn_drop(type: String, amount: int) -> void:
	if not _world:
		return
	var drop_scene := preload("res://scenes/world/ground_item.tscn")
	var drop: Node = drop_scene.instantiate()
	drop.item_type = type
	drop.item_amount = amount
	drop.global_position = global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8))
	_world.get_node("ResourceNodes").add_child(drop)

func _update_status_label() -> void:
	if not status_label:
		return
	var icon := ""
	if needs.hunger > 60:
		icon = "!"
	elif needs.stamina < 30:
		icon = "z"
	elif current_action_name == "gather_food" or current_action_name == "gather_mat":
		icon = "*"
	elif current_action_name == "deposit":
		icon = ">"
	elif current_action_name == "build":
		icon = "#"
	elif current_action_name == "research":
		icon = "?"
	elif current_action_name == "cook":
		icon = "~"
	elif current_action_name == "farm":
		icon = "^"
	elif current_action_name == "smelt":
		icon = "%"
	elif current_action_name == "weave":
		icon = "&"
	status_label.text = icon

func get_gather_efficiency(resource_type: String) -> float:
	var base := 1.0
	var tool: String = get_equipped("tool")
	match resource_type:
		"wood":
			if tool == "stone_axe":
				base = 1.5
		"stone", "iron_ore":
			if tool == "stone_pickaxe":
				base = 1.5
	var all_mult: float = TechTree.get_buff("gather_efficiency_all", 1.0)
	return base * all_mult

static func generate_random_name() -> String:
	var names := ["Ada", "Bob", "Cal", "Dee", "Eve", "Fox", "Gus", "Hal", "Ivy", "Jax", "Kit", "Leo", "Mae", "Neo", "Oak", "Pip", "Rex", "Sky", "Tao", "Uma"]
	return names[randi() % names.size()]
