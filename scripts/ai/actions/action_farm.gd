extends Action

var _target_farm: Node = null
var _harvesting: bool = false
var _harvest_timer: float = 0.0
const HARVEST_TIME := 2.0

func get_action_name() -> String:
	return "farm"

func can_execute(villager: Villager, world: Node) -> bool:
	if villager.inventory.is_full():
		return false
	return _find_harvestable_farm(villager) != null

func calculate_utility(villager: Villager, world: Node) -> float:
	if not can_execute(villager, world):
		return 0.0
	return 0.5

func start(villager: Villager, world: Node) -> void:
	_completed = false
	_harvesting = false
	_harvest_timer = 0.0
	_target_farm = _find_harvestable_farm(villager)
	if _target_farm:
		villager.navigate_to(_target_farm.global_position)
	else:
		_completed = true

func tick(villager: Villager, world: Node, delta: float) -> void:
	if not is_instance_valid(_target_farm):
		_completed = true
		return
	if not _harvesting:
		if villager.has_reached_target():
			if not _target_farm.has_harvest():
				_completed = true
				return
			_harvesting = true
			villager.needs.set_working(true)
	else:
		_harvest_timer += delta
		if _harvest_timer >= HARVEST_TIME:
			var result: Dictionary = _target_farm.harvest()
			if not result.is_empty():
				villager.inventory.add_item(result["type"], result["amount"])
			villager.needs.set_working(false)
			_completed = true

func cancel(villager: Villager, world: Node) -> void:
	villager.needs.set_working(false)
	_completed = true

func _find_harvestable_farm(villager: Villager) -> Node:
	var farms: Array[Node] = BuildingManager.get_buildings_of_type("farm")
	var best: Node = null
	var best_dist := INF
	for farm in farms:
		if not is_instance_valid(farm) or not farm.has_harvest():
			continue
		var dist: float = villager.global_position.distance_to(farm.global_position)
		if dist < best_dist:
			best_dist = dist
			best = farm
	return best
