extends Node

signal building_placed(building: Node)
signal building_completed(building: Node)

const BUILDING_LIMITS := {
	"shelter": 5,
	"campfire": 1,
	"chest": 3,
	"workbench": 1,
	"research_table": 1,
	"farm": 3,
	"smelter": 1,
	"loom": 1,
	"lumber_camp": 2,
	"quarry": 2,
	"fishing_dock": 2,
}

const TERRAIN_REQUIREMENTS := {
	"farm": [3],
	"lumber_camp": [4],
	"quarry": [5],
	"fishing_dock": [2, 3],
}

var _buildings: Array[Node] = []
var _occupied_tiles: Dictionary = {}  # {Vector2i: building_ref}
var _build_reservations: Dictionary = {}  # {building_type: int}
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

func get_building_count(type: String) -> int:
	return get_buildings_of_type(type).size()

func can_build_more(type: String) -> bool:
	var total: int = get_building_count(type) + int(_build_reservations.get(type, 0))
	return total < int(BUILDING_LIMITS.get(type, 1))

func reserve_build(type: String) -> bool:
	var total: int = get_building_count(type) + int(_build_reservations.get(type, 0))
	if total >= int(BUILDING_LIMITS.get(type, 1)):
		return false
	_build_reservations[type] = int(_build_reservations.get(type, 0)) + 1
	return true

func release_reservation(type: String) -> void:
	if _build_reservations.has(type):
		_build_reservations[type] -= 1
		if _build_reservations[type] <= 0:
			_build_reservations.erase(type)

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

func find_build_position(world: Node, building_type: String = "") -> Vector2:
	var center_tile: Vector2i = Vector2i(get_camp() / 16.0)
	for radius in range(1, 16):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue
				var tile: Vector2i = center_tile + Vector2i(dx, dy)
				if is_tile_occupied(tile):
					continue
				if not _is_valid_build_tile(world, tile, building_type):
					continue
				return Vector2(tile) * 16.0 + Vector2(8, 8)
	return get_camp()

func _is_valid_build_tile(world: Node, tile: Vector2i, building_type: String) -> bool:
	if not world.is_tile_walkable(tile):
		return false
	var terrain: int = world.get_terrain_at(tile)
	if TERRAIN_REQUIREMENTS.has(building_type):
		var allowed: Array = TERRAIN_REQUIREMENTS[building_type]
		if terrain not in allowed:
			return false
		if building_type == "fishing_dock" and world.has_method("is_adjacent_to_water"):
			if not world.is_adjacent_to_water(tile):
				return false
		return true
	return terrain == 3 or terrain == 2

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

func get_harvestable_buildings() -> Array[Node]:
	var result: Array[Node] = []
	for b in _buildings:
		if is_instance_valid(b) and b.is_completed and b.has_harvest():
			result.append(b)
	return result

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
	if can_build_more("shelter") or can_build_more("campfire"):
		return 0.4
	if can_build_more("chest") or can_build_more("workbench"):
		return 0.3
	if can_build_more("research_table"):
		return 0.25
	if TechTree.is_building_unlocked("farm") and can_build_more("farm"):
		return 0.2
	if TechTree.is_building_unlocked("smelter") and can_build_more("smelter"):
		return 0.2
	if TechTree.is_building_unlocked("loom") and can_build_more("loom"):
		return 0.2
	if TechTree.is_building_unlocked("lumber_camp") and can_build_more("lumber_camp"):
		return 0.2
	if TechTree.is_building_unlocked("quarry") and can_build_more("quarry"):
		return 0.2
	if TechTree.is_building_unlocked("fishing_dock") and can_build_more("fishing_dock"):
		return 0.2
	if not TechTree.get_researchable_techs().is_empty():
		return 0.15
	return 0.0
