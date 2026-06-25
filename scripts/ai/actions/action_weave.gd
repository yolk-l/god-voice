extends Action

enum Phase { FETCHING, WALKING_TO_LOOM, WEAVING }

var _weave_timer: float = 0.0
var _phase: int = Phase.WALKING_TO_LOOM
const WEAVE_TIME := 4.0

func get_action_name() -> String:
	return "weave"

func can_execute(villager: Villager, world: Node) -> bool:
	if not TechTree.is_building_unlocked("loom"):
		return false
	if not BuildingManager.has_building("loom"):
		return false
	var total: int = villager.inventory.get_amount("fiber") + BuildingManager.get_storage_items("fiber")
	return total >= 2

func calculate_utility(villager: Villager, world: Node) -> float:
	if not can_execute(villager, world):
		return 0.0
	var fiber_count: int = villager.inventory.get_amount("fiber") + BuildingManager.get_storage_items("fiber")
	return clampf(0.35 + fiber_count * 0.03, 0.0, 0.6)

func start(villager: Villager, world: Node) -> void:
	_completed = false
	_weave_timer = 0.0

	if villager.inventory.has_item("fiber", 2):
		_phase = Phase.WALKING_TO_LOOM
		var loom: Node = BuildingManager.get_nearest_building(villager.global_position, "loom")
		if loom:
			villager.navigate_to(loom.global_position)
		else:
			_completed = true
	else:
		var chest: Node = BuildingManager.get_nearest_building(villager.global_position, "chest")
		if chest:
			_phase = Phase.FETCHING
			villager.navigate_to(chest.global_position)
		else:
			_completed = true

func tick(villager: Villager, world: Node, delta: float) -> void:
	match _phase:
		Phase.FETCHING:
			if villager.has_reached_target():
				BuildingManager.withdraw_items(villager, {"fiber": 2})
				if not villager.inventory.has_item("fiber", 2):
					_completed = true
					return
				_phase = Phase.WALKING_TO_LOOM
				var loom: Node = BuildingManager.get_nearest_building(villager.global_position, "loom")
				if loom:
					villager.navigate_to(loom.global_position)
				else:
					_completed = true
		Phase.WALKING_TO_LOOM:
			if villager.has_reached_target():
				if not villager.inventory.has_item("fiber", 2):
					_completed = true
					return
				_phase = Phase.WEAVING
				villager.needs.set_working(true)
		Phase.WEAVING:
			_weave_timer += delta
			if _weave_timer >= WEAVE_TIME:
				villager.inventory.remove_item("fiber", 2)
				villager.inventory.add_item("cloth", 1)
				villager.needs.set_working(false)
				_completed = true

func cancel(villager: Villager, world: Node) -> void:
	villager.needs.set_working(false)
	_completed = true
