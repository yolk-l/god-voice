extends Action

enum Phase { FETCHING, WALKING_TO_WORKBENCH, CRAFTING }

var _recipe: String = ""
var _craft_timer: float = 0.0
var _phase: int = Phase.WALKING_TO_WORKBENCH
const CRAFT_TIME := 4.0

func get_action_name() -> String:
	return "craft"

func can_execute(villager: Villager, world: Node) -> bool:
	if not BuildingManager.has_building("workbench"):
		return false
	return _find_recipe(villager) != ""

func calculate_utility(villager: Villager, world: Node) -> float:
	var recipe: String = _find_recipe(villager)
	if recipe == "":
		return 0.0
	if recipe in ["stone_axe", "stone_pickaxe"]:
		return 0.7
	return 0.5

func start(villager: Villager, world: Node) -> void:
	_completed = false
	_craft_timer = 0.0
	_recipe = _find_recipe(villager)
	if _recipe == "":
		_completed = true
		return

	if villager.inventory.has_materials_for(_recipe):
		_phase = Phase.WALKING_TO_WORKBENCH
		var workbench: Node = BuildingManager.get_nearest_building(villager.global_position, "workbench")
		if workbench:
			villager.navigate_to(workbench.global_position)
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
				var cost: Dictionary = VillagerInventory.get_recipe_cost(_recipe)
				BuildingManager.withdraw_items(villager, cost)
				if not villager.inventory.has_materials_for(_recipe):
					_completed = true
					return
				_phase = Phase.WALKING_TO_WORKBENCH
				var workbench: Node = BuildingManager.get_nearest_building(villager.global_position, "workbench")
				if workbench:
					villager.navigate_to(workbench.global_position)
				else:
					_completed = true
		Phase.WALKING_TO_WORKBENCH:
			if villager.has_reached_target():
				if not villager.inventory.has_materials_for(_recipe):
					_completed = true
					return
				_phase = Phase.CRAFTING
				villager.needs.set_working(true)
		Phase.CRAFTING:
			_craft_timer += delta
			if _craft_timer >= CRAFT_TIME:
				villager.inventory.consume_materials(_recipe)
				if _recipe in ["stone_axe", "stone_pickaxe"]:
					villager.equip("tool", _recipe)
				else:
					villager.inventory.add_item(_recipe, 1)
				EventLog.add(villager.villager_name, "craft", "%s crafted %s" % [villager.villager_name, _recipe])
				villager.needs.set_working(false)
				_completed = true

func cancel(villager: Villager, world: Node) -> void:
	villager.needs.set_working(false)
	_completed = true

func _has_item_available(villager: Villager, type: String, amount: int) -> bool:
	var total: int = villager.inventory.get_amount(type) + BuildingManager.get_storage_items(type)
	return total >= amount

func _has_materials_available(villager: Villager, recipe: String) -> bool:
	if villager.inventory.has_materials_for(recipe):
		return true
	var cost: Dictionary = VillagerInventory.get_recipe_cost(recipe)
	return BuildingManager.has_items_available(villager, cost)

func _find_recipe(villager: Villager) -> String:
	if TechTree.is_unlocked("stone_axe") and not villager.owns_tool("stone_axe"):
		if _has_materials_available(villager, "stone_axe"):
			return "stone_axe"
	if TechTree.is_unlocked("stone_pickaxe") and not villager.owns_tool("stone_pickaxe"):
		if _has_materials_available(villager, "stone_pickaxe"):
			return "stone_pickaxe"
	if TechTree.is_unlocked("weaving") and _has_materials_available(villager, "rope"):
		return "rope"
	return ""
