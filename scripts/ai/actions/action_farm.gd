extends Action

var _target_building: Node = null
var _harvesting: bool = false
var _harvest_timer: float = 0.0
const HARVEST_TIME := 2.0

func get_action_name() -> String:
	return "farm"

func can_execute(villager: Villager, world: Node) -> bool:
	if villager.inventory.is_full():
		return false
	return _find_harvestable_building(villager) != null

func calculate_utility(villager: Villager, world: Node) -> float:
	if not can_execute(villager, world):
		return 0.0
	return 0.5

func start(villager: Villager, world: Node) -> void:
	_completed = false
	_harvesting = false
	_harvest_timer = 0.0
	_target_building = _find_harvestable_building(villager)
	if _target_building:
		villager.navigate_to(_target_building.global_position)
	else:
		_completed = true

func tick(villager: Villager, world: Node, delta: float) -> void:
	if not is_instance_valid(_target_building):
		_completed = true
		return
	if not _harvesting:
		if villager.has_reached_target():
			if not _target_building.has_harvest():
				_completed = true
				return
			_harvesting = true
			villager.needs.set_working(true)
	else:
		_harvest_timer += delta
		if _harvest_timer >= HARVEST_TIME:
			var result: Dictionary = _target_building.harvest()
			if not result.is_empty():
				villager.inventory.add_item(result["type"], result["amount"])
			villager.needs.set_working(false)
			_completed = true

func cancel(villager: Villager, world: Node) -> void:
	villager.needs.set_working(false)
	_completed = true

func _find_harvestable_building(villager: Villager) -> Node:
	var best: Node = null
	var best_dist := INF
	var buildings: Array[Node] = BuildingManager.get_harvestable_buildings()
	for b in buildings:
		var dist: float = villager.global_position.distance_to(b.global_position)
		if dist < best_dist:
			best_dist = dist
			best = b
	return best
