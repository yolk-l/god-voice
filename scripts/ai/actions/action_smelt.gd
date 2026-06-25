extends Action

enum Phase { FETCHING, WALKING_TO_SMELTER, SMELTING }

var _smelt_timer: float = 0.0
var _phase: int = Phase.WALKING_TO_SMELTER
const SMELT_TIME := 5.0

func get_action_name() -> String:
	return "smelt"

func can_execute(villager: Villager, world: Node) -> bool:
	if not TechTree.is_building_unlocked("smelter"):
		return false
	if not BuildingManager.has_building("smelter"):
		return false
	var total: int = villager.inventory.get_amount("iron_ore") + BuildingManager.get_storage_items("iron_ore")
	return total >= 1

func calculate_utility(villager: Villager, world: Node) -> float:
	if not can_execute(villager, world):
		return 0.0
	var ore_count: int = villager.inventory.get_amount("iron_ore") + BuildingManager.get_storage_items("iron_ore")
	return clampf(0.45 + ore_count * 0.05, 0.0, 0.7)

func start(villager: Villager, world: Node) -> void:
	_completed = false
	_smelt_timer = 0.0

	if villager.inventory.has_item("iron_ore", 1):
		_phase = Phase.WALKING_TO_SMELTER
		var smelter: Node = BuildingManager.get_nearest_building(villager.global_position, "smelter")
		if smelter:
			villager.navigate_to(smelter.global_position)
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
				BuildingManager.withdraw_items(villager, {"iron_ore": 1})
				if not villager.inventory.has_item("iron_ore", 1):
					_completed = true
					return
				_phase = Phase.WALKING_TO_SMELTER
				var smelter: Node = BuildingManager.get_nearest_building(villager.global_position, "smelter")
				if smelter:
					villager.navigate_to(smelter.global_position)
				else:
					_completed = true
		Phase.WALKING_TO_SMELTER:
			if villager.has_reached_target():
				if not villager.inventory.has_item("iron_ore", 1):
					_completed = true
					return
				_phase = Phase.SMELTING
				villager.needs.set_working(true)
		Phase.SMELTING:
			_smelt_timer += delta
			if _smelt_timer >= SMELT_TIME:
				villager.inventory.remove_item("iron_ore", 1)
				villager.inventory.add_item("iron_ingot", 1)
				villager.needs.set_working(false)
				_completed = true

func cancel(villager: Villager, world: Node) -> void:
	villager.needs.set_working(false)
	_completed = true
