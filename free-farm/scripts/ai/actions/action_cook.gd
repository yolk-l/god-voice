extends Action

var _cooking: bool = false
var _cook_timer: float = 0.0
const COOK_TIME := 3.0

func get_action_name() -> String:
	return "cook"

func can_execute(villager: Villager, world: Node) -> bool:
	if not TechTree.is_feature_unlocked("cooking"):
		return false
	if not BuildingManager.has_building("campfire"):
		return false
	return villager.inventory.has_item("raw_meat", 1)

func calculate_utility(villager: Villager, world: Node) -> float:
	if not can_execute(villager, world):
		return 0.0
	var meat_count: int = villager.inventory.get_amount("raw_meat")
	return clampf(0.45 + meat_count * 0.05, 0.0, 0.7)

func start(villager: Villager, world: Node) -> void:
	_completed = false
	_cooking = false
	_cook_timer = 0.0
	var campfire: Node = BuildingManager.get_nearest_building(villager.global_position, "campfire")
	if campfire:
		villager.navigate_to(campfire.global_position)
	else:
		_completed = true

func tick(villager: Villager, world: Node, delta: float) -> void:
	if not _cooking:
		if villager.has_reached_target():
			if not villager.inventory.has_item("raw_meat", 1):
				_completed = true
				return
			_cooking = true
			villager.needs.set_working(true)
	else:
		_cook_timer += delta
		if _cook_timer >= COOK_TIME:
			villager.inventory.remove_item("raw_meat", 1)
			villager.inventory.add_item("cooked_meat", 1)
			villager.needs.set_working(false)
			_completed = true

func cancel(villager: Villager, world: Node) -> void:
	villager.needs.set_working(false)
	_completed = true
