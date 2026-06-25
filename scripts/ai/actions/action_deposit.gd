extends Action

var _depositing: bool = false

func get_action_name() -> String:
	return "deposit"

func can_execute(villager: Villager, world: Node) -> bool:
	if not villager.inventory.is_full():
		return false
	var chest: Node = BuildingManager.get_nearest_chest_with_space(villager.global_position)
	return chest != null

func calculate_utility(villager: Villager, world: Node) -> float:
	if villager.inventory.is_full():
		return 0.6
	return 0.0

func start(villager: Villager, world: Node) -> void:
	_completed = false
	_depositing = false
	var chest: Node = BuildingManager.get_nearest_chest_with_space(villager.global_position)
	if chest:
		villager.navigate_to(chest.global_position)
	else:
		_completed = true

func tick(villager: Villager, world: Node, delta: float) -> void:
	if villager.has_reached_target():
		var chest: Node = BuildingManager.get_nearest_chest_with_space(villager.global_position)
		if chest and villager.global_position.distance_to(chest.global_position) < 20.0:
			var items: Dictionary = villager.inventory.get_all_items()
			for type in items:
				if type in ["stone_axe", "stone_pickaxe"]:
					continue
				var amount: int = items[type]
				var deposited: int = chest.add_item(type, amount)
				villager.inventory.remove_item(type, deposited)
		_completed = true

func cancel(villager: Villager, world: Node) -> void:
	_completed = true
