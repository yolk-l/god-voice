extends Node

signal building_placed(building: Node)
signal building_completed(building: Node)

var _buildings: Array[Node] = []
var _occupied_tiles: Dictionary = {}  # {Vector2i: building_ref}
var camp_position: Vector2 = Vector2.ZERO  # camp center, all building around here

func _ready() -> void:
	GameManager.connect("tree_entered", _init_camp)

func _init_camp() -> void:
	camp_position = GameManager.village_center

func set_camp(pos: Vector2) -> void:
	camp_position = pos

func get_camp() -> Vector2:
	if camp_position == Vector2.ZERO:
		return GameManager.village_center
	return camp_position

func register(building: Node) -> void:
	if building not in _buildings:
		_buildings.append(building)
		var tile_pos: Vector2i = Vector2i(building.global_position / 16.0)
		_occupied_tiles[tile_pos] = building
		# first building establishes the camp
		if _buildings.size() == 1:
			camp_position = building.global_position
		building_placed.emit(building)

func unregister(building: Node) -> void:
	_buildings.erase(building)
	var tile_pos: Vector2i = Vector2i(building.global_position / 16.0)
	_occupied_tiles.erase(tile_pos)

func has_building(type: String) -> bool:
	for b in _buildings:
		if is_instance_valid(b) and b.building_type == type and b.is_completed:
			return true
	return false

func get_buildings_of_type(type: String) -> Array[Node]:
	var result: Array[Node] = []
	for b in _buildings:
		if is_instance_valid(b) and b.building_type == type and b.is_completed:
			result.append(b)
	return result

func get_nearest_building(pos: Vector2, type: String) -> Node:
	var best: Node = null
	var best_dist := INF
	for b in _buildings:
		if not is_instance_valid(b) or not b.is_completed:
			continue
		if type != "" and b.building_type != type:
			continue
		var dist: float = pos.distance_to(b.global_position)
		if dist < best_dist:
			best_dist = dist
			best = b
	return best

func is_tile_occupied(tile_pos: Vector2i) -> bool:
	return _occupied_tiles.has(tile_pos)

func find_build_position(world: Node) -> Vector2:
	var center_tile: Vector2i = Vector2i(get_camp() / 16.0)
	for radius in range(1, 12):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue
				var tile: Vector2i = center_tile + Vector2i(dx, dy)
				if is_tile_occupied(tile):
					continue
				if world.is_tile_buildable(tile):
					return Vector2(tile) * 16.0 + Vector2(8, 8)
	return get_camp()

func get_village_center() -> Vector2:
	return get_camp()

func get_storage_items(type: String) -> int:
	var total := 0
	for b in _buildings:
		if is_instance_valid(b) and b.building_type == "chest" and b.is_completed:
			total += b.get_item_count(type)
	return total

func get_storage_food_count(villager: Node) -> int:
	var total := 0
	for b in _buildings:
		if is_instance_valid(b) and b.building_type == "chest" and b.is_completed:
			total += b.get_food_count()
	return total

func get_nearest_chest_with_space(pos: Vector2) -> Node:
	var best: Node = null
	var best_dist := INF
	for b in _buildings:
		if not is_instance_valid(b) or b.building_type != "chest" or not b.is_completed:
			continue
		if b.is_full():
			continue
		var dist: float = pos.distance_to(b.global_position)
		if dist < best_dist:
			best_dist = dist
			best = b
	return best

func has_items_available(villager: Node, cost: Dictionary) -> bool:
	for type in cost:
		var total: int = villager.inventory.get_amount(type) + get_storage_items(type)
		if total < cost[type]:
			return false
	return true

func withdraw_items(villager: Node, cost: Dictionary) -> bool:
	for type in cost:
		var have: int = villager.inventory.get_amount(type)
		var need: int = cost[type] - have
		if need <= 0:
			continue
		for b in _buildings:
			if need <= 0:
				break
			if not is_instance_valid(b) or b.building_type != "chest" or not b.is_completed:
				continue
			var available: int = b.get_item_count(type)
			var take: int = mini(need, available)
			if take > 0:
				b.remove_item(type, take)
				villager.inventory.add_item(type, take)
				need -= take
		if need > 0:
			return false
	return true

func get_unmet_material_urgency(villager: Node) -> float:
	if not has_building("shelter") and not has_building("campfire"):
		return 0.4
	if not has_building("workbench"):
		return 0.3
	return 0.0
