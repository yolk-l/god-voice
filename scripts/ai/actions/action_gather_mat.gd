extends Action

enum Phase { WALKING_TO_RESOURCE, GATHERING, RETURNING }

var _target_resource: Node = null
var _gather_timer: float = 0.0
var _walk_timer: float = 0.0
var _phase: int = Phase.WALKING_TO_RESOURCE
const MAX_WALK_TIME := 30.0

func get_action_name() -> String:
	return "gather_mat"

const MAX_GATHER_RANGE := 200.0

func can_execute(villager: Villager, world: Node) -> bool:
	if villager.inventory.is_full():
		return false
	var nearest: Node = ResourceManager.find_nearest_in_area(
		villager.global_position, "material", MAX_GATHER_RANGE, villager.known_area, true
	)
	return nearest != null

func calculate_utility(villager: Villager, world: Node) -> float:
	var fullness: float = villager.inventory.get_occupied_slots() / float(VillagerInventory.MAX_SLOTS)
	var base: float = (1.0 - fullness) * 0.5
	var build_need: float = BuildingManager.get_unmet_material_urgency(villager)
	base += build_need * 0.3

	var nearest: Node = ResourceManager.find_nearest_in_area(
		villager.global_position, "material", MAX_GATHER_RANGE, villager.known_area, true
	)
	if nearest == null:
		return 0.0
	var camp: Vector2 = BuildingManager.get_camp()
	var camp_dist: float = nearest.global_position.distance_to(camp)
	var camp_penalty: float = clampf(camp_dist / 300.0, 0.0, 0.5)
	var distance_factor: float = 1.0 - clampf(villager.global_position.distance_to(nearest.global_position) / MAX_GATHER_RANGE, 0.0, 0.8)
	return clampf((base * distance_factor) - camp_penalty, 0.0, 1.0)

func start(villager: Villager, world: Node) -> void:
	_completed = false
	_phase = Phase.WALKING_TO_RESOURCE
	_gather_timer = 0.0
	_walk_timer = 0.0
	var needed_type: String = _find_needed_material_type(villager)
	_target_resource = ResourceManager.find_nearest_in_area(
		villager.global_position, needed_type, MAX_GATHER_RANGE, villager.known_area, true
	)
	if not _target_resource and needed_type != "material":
		_target_resource = ResourceManager.find_nearest_in_area(
			villager.global_position, "material", MAX_GATHER_RANGE, villager.known_area, true
		)
	if _target_resource:
		_auto_equip_tool(villager, _target_resource.resource_type)
		ResourceManager.reserve(_target_resource, villager)
		villager.navigate_to(_target_resource.global_position)
	else:
		_completed = true

func tick(villager: Villager, world: Node, delta: float) -> void:
	match _phase:
		Phase.WALKING_TO_RESOURCE:
			if not is_instance_valid(_target_resource) or _target_resource.is_depleted:
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
			if not is_instance_valid(_target_resource) or _target_resource.is_depleted:
				villager.needs.set_working(false)
				_finish_gathering(villager)
				return
			var efficiency: float = villager.get_gather_efficiency(_target_resource.resource_type)
			_gather_timer += delta * efficiency
			if _gather_timer >= _target_resource.gather_time:
				var result: Dictionary = _target_resource.gather()
				if not result.is_empty():
					villager.inventory.add_item(result["type"], result["amount"])
				villager.needs.set_working(false)
				_release_resource()
				_finish_gathering(villager)
		Phase.RETURNING:
			if villager.has_reached_target():
				_deposit_at_camp(villager)
				_completed = true

func cancel(villager: Villager, world: Node) -> void:
	villager.needs.set_working(false)
	_release_resource()
	_completed = true

func _finish_gathering(villager: Villager) -> void:
	var chest: Node = BuildingManager.get_nearest_chest_with_space(villager.global_position)
	if chest or villager.inventory.is_full():
		_start_returning(villager)
		return
	var needed_type: String = _find_needed_material_type(villager)
	var next_res: Node = ResourceManager.find_nearest_in_area(
		villager.global_position, needed_type, MAX_GATHER_RANGE, villager.known_area, true
	)
	if not next_res and needed_type != "material":
		next_res = ResourceManager.find_nearest_in_area(
			villager.global_position, "material", MAX_GATHER_RANGE, villager.known_area, true
		)
	if next_res:
		_target_resource = next_res
		_auto_equip_tool(villager, _target_resource.resource_type)
		ResourceManager.reserve(_target_resource, villager)
		villager.navigate_to(_target_resource.global_position)
		_phase = Phase.WALKING_TO_RESOURCE
		_walk_timer = 0.0
		_gather_timer = 0.0
	else:
		_completed = true

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
	if _target_resource and is_instance_valid(_target_resource):
		ResourceManager.release(_target_resource)
	_target_resource = null

func _release_and_complete(villager: Villager) -> void:
	_release_resource()
	_completed = true

func _find_needed_material_type(villager: Villager) -> String:
	var target: String = _get_next_building_target()
	if target == "":
		return "material"
	var cost: Dictionary = VillagerInventory.get_recipe_cost(target)
	var biggest_shortfall := 0
	var needed_type := ""
	for type in cost:
		var have: int = villager.inventory.get_amount(type) + BuildingManager.get_storage_items(type)
		var shortfall: int = cost[type] - have
		if shortfall > biggest_shortfall:
			biggest_shortfall = shortfall
			needed_type = type
	if needed_type == "":
		return "material"
	return needed_type

func _get_next_building_target() -> String:
	if not BuildingManager.has_building("shelter"):
		return "shelter"
	if not BuildingManager.has_building("campfire"):
		return "campfire"
	if not BuildingManager.has_building("chest"):
		return "chest"
	if not BuildingManager.has_building("workbench"):
		return "workbench"
	if not BuildingManager.has_building("research_table"):
		return "research_table"
	if TechTree.is_building_unlocked("farm") and not BuildingManager.has_building("farm"):
		return "farm"
	if TechTree.is_building_unlocked("smelter") and not BuildingManager.has_building("smelter"):
		return "smelter"
	if TechTree.is_building_unlocked("loom") and not BuildingManager.has_building("loom"):
		return "loom"
	return ""
