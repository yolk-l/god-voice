extends Action

var _eating_timer: float = 0.0
const EAT_DURATION := 1.5

func get_action_name() -> String:
	return "eat"

func can_execute(villager: Villager, world: Node) -> bool:
	if villager.needs.hunger <= 20.0:
		return false
	if villager.inventory.has_food():
		return true
	var chest: Node = BuildingManager.get_nearest_chest_with_space(villager.global_position)
	if chest and chest.get_food_count() > 0:
		return true
	return false

func calculate_utility(villager: Villager, world: Node) -> float:
	return villager.needs.hunger / 100.0 * 1.2

func start(villager: Villager, world: Node) -> void:
	_completed = false
	_eating_timer = 0.0
	if not villager.inventory.has_food():
		var chest: Node = BuildingManager.get_nearest_building(villager.global_position, "chest")
		if chest:
			villager.navigate_to(chest.global_position)

func tick(villager: Villager, world: Node, delta: float) -> void:
	if not villager.inventory.has_food():
		if not villager.has_reached_target():
			return
		var chest: Node = BuildingManager.get_nearest_building(villager.global_position, "chest")
		if chest and villager.global_position.distance_to(chest.global_position) < 20.0:
			var food_type: String = chest.take_food()
			if food_type != "":
				villager.inventory.add_item(food_type, 1)
		if not villager.inventory.has_food():
			_completed = true
			return

	_eating_timer += delta
	if _eating_timer >= EAT_DURATION:
		var foods: Array = villager.inventory.get_food_items()
		if foods.is_empty():
			_completed = true
			return
		var food_type: String = foods[0]["type"]
		villager.inventory.remove_item(food_type, 1)
		var nutrition: float = VillagerInventory.get_food_nutrition(food_type)
		villager.needs.eat(nutrition)
		if food_type == "mushroom" and randf() < 0.2:
			villager.needs.health = clampf(villager.needs.health - 15.0, 0.0, 100.0)
			villager.needs.hunger = clampf(villager.needs.hunger + 20.0, 0.0, 100.0)
		_completed = true

func cancel(villager: Villager, world: Node) -> void:
	_completed = true
