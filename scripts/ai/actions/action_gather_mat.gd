extends Action

enum Phase { WALKING_TO_RESOURCE, GATHERING, RETURNING }

var _target_tile: Variant = null  # Vector2i or null
var _gather_timer: float = 0.0
var _walk_timer: float = 0.0
var _phase: int = Phase.WALKING_TO_RESOURCE
const MAX_WALK_TIME := 30.0
const MAX_GATHER_RANGE := 200.0

func get_action_name() -> String:
	return "gather_mat"

func can_execute(villager: Villager, world: Node) -> bool:
	if villager.inventory.is_full():
		return false
	var nearest = ResourceManager.find_nearest_in_area(
		villager.global_position, "material", MAX_GATHER_RANGE, villager.known_area, true
	)
	return nearest != null

func calculate_utility(villager: Villager, world: Node) -> float:
	var fullness: float = villager.inventory.get_occupied_slots() / float(VillagerInventory.MAX_SLOTS)
	var base: float = (1.0 - fullness) * 0.5
	var build_need: float = BuildingManager.get_unmet_material_urgency(villager)
	base += build_need * 0.3

	var nearest = ResourceManager.find_nearest_in_area(
		villager.global_position, "material", MAX_GATHER_RANGE, villager.known_area, true
	)
	if nearest == null:
		return 0.0
	var nearest_world_pos: Vector2 = ResourceManager.tile_to_world_pos(nearest)
	var camp: Vector2 = BuildingManager.get_camp()
	var camp_dist: float = nearest_world_pos.distance_to(camp)
	var camp_factor: float = 1.0 - clampf(camp_dist / 400.0, 0.0, 0.5)
	var distance_factor: float = 1.0 - clampf(villager.global_position.distance_to(nearest_world_pos) / MAX_GATHER_RANGE, 0.0, 0.8)
	return clampf(base * distance_factor * camp_factor, 0.0, 1.0)

func start(villager: Villager, world: Node) -> void:
	_completed = false
	_phase = Phase.WALKING_TO_RESOURCE
	_gather_timer = 0.0
	_walk_timer = 0.0
	var needed_type: String = _find_needed_material_type(villager)
	_target_tile = ResourceManager.find_nearest_in_area(
		villager.global_position, needed_type, MAX_GATHER_RANGE, villager.known_area, true
	)
	if _target_tile == null and needed_type != "material":
		_target_tile = ResourceManager.find_nearest_in_area(
			villager.global_position, "material", MAX_GATHER_RANGE, villager.known_area, true
		)
	if _target_tile != null:
		var resource_type: String = ""
		var world_node: Node = villager.get_tree().current_scene.get_node("World")
		if world_node:
			resource_type = world_node.get_tile_resource_type(_target_tile)
		_auto_equip_tool(villager, resource_type)
		ResourceManager.reserve(_target_tile, villager)
		villager.navigate_to(ResourceManager.tile_to_world_pos(_target_tile))
		print("[GATHER] %s: targeting %s (%s)" % [villager.villager_name, needed_type, resource_type])
	else:
		print("[GATHER] %s: no resource found for %s" % [villager.villager_name, needed_type])
		_completed = true

func tick(villager: Villager, world: Node, delta: float) -> void:
	match _phase:
		Phase.WALKING_TO_RESOURCE:
			if _target_tile == null or world.is_tile_depleted(_target_tile):
				_release_and_complete(villager)
				return
			_walk_timer += delta
			if _walk_timer >= MAX_WALK_TIME:
				_release_and_complete(villager)
				return
			if villager.has_reached_target():
				_phase = Phase.GATHERING
				_gather_timer = 0.0
				villager.needs.set_working(true)
		Phase.GATHERING:
			if _target_tile == null or world.is_tile_depleted(_target_tile):
				villager.needs.set_working(false)
				_finish_gathering(villager, world)
				return
			var resource_type: String = world.get_tile_resource_type(_target_tile)
			var efficiency: float = villager.get_gather_efficiency(resource_type)
			_gather_timer += delta * efficiency
			if _gather_timer >= world.get_tile_gather_time(_target_tile):
				var result: Dictionary = world.gather_tile(_target_tile)
				if not result.is_empty():
					villager.inventory.add_item(result["type"], result["amount"])
				villager.needs.set_working(false)
				_release_resource()
				_finish_gathering(villager, world)
		Phase.RETURNING:
			if villager.has_reached_target():
				_deposit_at_camp(villager)
				_completed = true

func cancel(villager: Villager, world: Node) -> void:
	villager.needs.set_working(false)
	_release_resource()
	_completed = true

func _finish_gathering(villager: Villager, world: Node) -> void:
	if villager.inventory.is_full():
		_start_returning(villager)
		return
	var needed_type: String = _find_needed_material_type(villager)
	var next_tile = ResourceManager.find_nearest_in_area(
		villager.global_position, needed_type, MAX_GATHER_RANGE, villager.known_area, true
	)
	if next_tile == null and needed_type != "material":
		next_tile = ResourceManager.find_nearest_in_area(
			villager.global_position, "material", MAX_GATHER_RANGE, villager.known_area, true
		)
	if next_tile != null:
		_target_tile = next_tile
		var resource_type: String = world.get_tile_resource_type(_target_tile)
		_auto_equip_tool(villager, resource_type)
		ResourceManager.reserve(_target_tile, villager)
		villager.navigate_to(ResourceManager.tile_to_world_pos(_target_tile))
		_phase = Phase.WALKING_TO_RESOURCE
		_walk_timer = 0.0
		_gather_timer = 0.0
	else:
		_start_returning(villager)

func _start_returning(villager: Villager) -> void:
	_phase = Phase.RETURNING
	var chest: Node = BuildingManager.get_nearest_chest_with_space(villager.global_position)
	if chest:
		villager.navigate_to(chest.global_position)
	else:
		villager.navigate_to(BuildingManager.get_camp())

func _deposit_at_camp(villager: Villager) -> void:
	var chest: Node = BuildingManager.get_nearest_chest_with_space(villager.global_position)
	if chest and villager.global_position.distance_to(chest.global_position) < 20.0:
		var items: Dictionary = villager.inventory.get_all_items()
		for type in items:
			if _is_tool(type):
				continue
			var amount: int = items[type]
			var deposited: int = chest.add_item(type, amount)
			villager.inventory.remove_item(type, deposited)

func _auto_equip_tool(villager: Villager, resource_type: String) -> void:
	var needed: String = _get_tool_for_resource(resource_type)
	if needed == "" or villager.get_equipped("tool") == needed:
		return
	if villager.inventory.has_item(needed, 1):
		villager.equip_from_inventory("tool", needed)

func _get_tool_for_resource(resource_type: String) -> String:
	match resource_type:
		"wood": return "stone_axe"
		"stone", "iron_ore": return "stone_pickaxe"
		_: return ""

static func _is_tool(type: String) -> bool:
	return type in ["stone_axe", "stone_pickaxe"]

func _release_resource() -> void:
	if _target_tile != null:
		ResourceManager.release(_target_tile)
	_target_tile = null

func _release_and_complete(villager: Villager) -> void:
	_release_resource()
	_completed = true

func _find_needed_material_type(villager: Villager) -> String:
	var targets: Array[String] = _get_all_building_targets()
	for target in targets:
		var cost: Dictionary = VillagerInventory.get_recipe_cost(target)
		var result: String = _find_shortfall_type(villager, cost)
		if result != "":
			return result
	var techs: Array = TechTree.get_researchable_techs()
	for tech in techs:
		var cost: Dictionary = tech["research_cost"]
		var result: String = _find_shortfall_type(villager, cost)
		if result != "":
			return result
	return "material"

func _find_shortfall_type(villager: Villager, cost: Dictionary) -> String:
	var shortfalls := []
	for type in cost:
		var have: int = villager.inventory.get_amount(type) + BuildingManager.get_storage_items(type)
		var shortfall: int = cost[type] - have
		if shortfall > 0:
			shortfalls.append({"type": type, "amount": shortfall})
	if shortfalls.is_empty():
		return ""
	shortfalls.sort_custom(func(a, b): return a["amount"] > b["amount"])
	for entry in shortfalls:
		var source = ResourceManager.find_nearest_in_area(
			villager.global_position, entry["type"], MAX_GATHER_RANGE, villager.known_area, true
		)
		if source != null:
			return entry["type"]
	return ""

func _get_all_building_targets() -> Array[String]:
	var targets: Array[String] = []
	if BuildingManager.can_build_more("shelter"):
		targets.append("shelter")
	if BuildingManager.can_build_more("campfire"):
		targets.append("campfire")
	if BuildingManager.can_build_more("chest"):
		targets.append("chest")
	if BuildingManager.can_build_more("workbench"):
		targets.append("workbench")
	if BuildingManager.has_building("workbench") and BuildingManager.can_build_more("research_table"):
		targets.append("research_table")
	if TechTree.is_building_unlocked("farm") and BuildingManager.can_build_more("farm"):
		targets.append("farm")
	if TechTree.is_building_unlocked("smelter") and BuildingManager.can_build_more("smelter"):
		targets.append("smelter")
	if TechTree.is_building_unlocked("loom") and BuildingManager.can_build_more("loom"):
		targets.append("loom")
	if TechTree.is_building_unlocked("lumber_camp") and BuildingManager.can_build_more("lumber_camp"):
		targets.append("lumber_camp")
	if TechTree.is_building_unlocked("quarry") and BuildingManager.can_build_more("quarry"):
		targets.append("quarry")
	if TechTree.is_building_unlocked("fishing_dock") and BuildingManager.can_build_more("fishing_dock"):
		targets.append("fishing_dock")
	return targets
