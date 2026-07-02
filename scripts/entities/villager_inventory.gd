class_name VillagerInventory
extends RefCounted

const MAX_SLOTS := 5

var _items: Dictionary = {}  # {type: amount}

func add_item(type: String, amount: int) -> int:
	var total_occupied: int = get_occupied_slots()
	if not _items.has(type) and total_occupied >= MAX_SLOTS:
		return 0
	if not _items.has(type):
		_items[type] = 0
	var can_add: int = amount
	_items[type] += can_add
	return can_add

func remove_item(type: String, amount: int) -> int:
	if not _items.has(type):
		return 0
	var removed: int = mini(amount, _items[type])
	_items[type] -= removed
	if _items[type] <= 0:
		_items.erase(type)
	return removed

func has_item(type: String, amount: int) -> bool:
	return _items.get(type, 0) >= amount

func get_amount(type: String) -> int:
	return _items.get(type, 0)

func get_occupied_slots() -> int:
	return _items.size()

func is_full() -> bool:
	return get_occupied_slots() >= MAX_SLOTS

func get_food_items() -> Array:
	var foods: Array = []
	for type in _items:
		if _is_food(type) and _items[type] > 0:
			foods.append({"type": type, "amount": _items[type]})
	return foods

func get_food_count() -> int:
	var count := 0
	for type in _items:
		if _is_food(type):
			count += _items[type]
	return count

func has_food() -> bool:
	return get_food_count() > 0

func has_materials_for(recipe: String) -> bool:
	var cost: Dictionary = get_recipe_cost(recipe)
	for type in cost:
		if get_amount(type) < cost[type]:
			return false
	return true

func consume_materials(recipe: String) -> bool:
	var cost: Dictionary = get_recipe_cost(recipe)
	for type in cost:
		if get_amount(type) < cost[type]:
			return false
	for type in cost:
		remove_item(type, cost[type])
	return true

func get_all_items() -> Dictionary:
	return _items.duplicate()

func drop_all() -> Array:
	var dropped: Array = []
	for type in _items:
		dropped.append({"type": type, "amount": _items[type]})
	_items.clear()
	return dropped

func _is_food(type: String) -> bool:
	return type in ["berry", "mushroom", "raw_meat", "cooked_meat", "fish", "cooked_fish"]

static func get_recipe_cost(recipe: String) -> Dictionary:
	match recipe:
		"shelter": return {"fiber": 5, "wood": 3}
		"campfire": return {"wood": 3, "stone": 1}
		"chest": return {"wood": 5}
		"workbench": return {"wood": 5, "stone": 3}
		"research_table": return {"wood": 8, "stone": 5}
		"farm": return {"wood": 5, "fiber": 5}
		"smelter": return {"stone": 8, "wood": 3}
		"loom": return {"wood": 5, "rope": 2}
		"lumber_camp": return {"wood": 5, "stone": 3}
		"quarry": return {"stone": 5, "wood": 5}
		"fishing_dock": return {"wood": 8, "fiber": 3}
		"rope": return {"fiber": 3}
		"stone_axe": return {"wood": 2, "stone": 2}
		"stone_pickaxe": return {"wood": 2, "stone": 2}
		_: return {}

static func get_food_nutrition(type: String) -> float:
	match type:
		"berry": return 15.0
		"mushroom": return 20.0
		"raw_meat": return 10.0
		"cooked_meat": return 30.0
		"fish": return 18.0
		"cooked_fish": return 28.0
		_: return 0.0
