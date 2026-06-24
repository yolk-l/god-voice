extends Action

var _recipe: String = ""
var _crafting: bool = false
var _craft_timer: float = 0.0
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
	_crafting = false
	_craft_timer = 0.0
	_recipe = _find_recipe(villager)
	if _recipe == "":
		_completed = true
		return
	var workbench: Node = BuildingManager.get_nearest_building(villager.global_position, "workbench")
	if workbench:
		villager.navigate_to(workbench.global_position)
	else:
		_completed = true

func tick(villager: Villager, world: Node, delta: float) -> void:
	if not _crafting:
		if villager.has_reached_target():
			if not villager.inventory.has_materials_for(_recipe):
				_completed = true
				return
			_crafting = true
			villager.needs.set_working(true)
	else:
		_craft_timer += delta
		if _craft_timer >= CRAFT_TIME:
			villager.inventory.consume_materials(_recipe)
			villager.inventory.add_item(_recipe, 1)
			villager.needs.set_working(false)
			_completed = true

func cancel(villager: Villager, world: Node) -> void:
	villager.needs.set_working(false)
	_completed = true

func _find_recipe(villager: Villager) -> String:
	if TechTree.is_unlocked("stone_axe") and not villager.inventory.has_item("stone_axe", 1):
		if villager.inventory.has_materials_for("stone_axe"):
			return "stone_axe"
	if TechTree.is_unlocked("stone_pickaxe") and not villager.inventory.has_item("stone_pickaxe", 1):
		if villager.inventory.has_materials_for("stone_pickaxe"):
			return "stone_pickaxe"
	if TechTree.is_unlocked("weaving") and villager.inventory.has_materials_for("rope"):
		return "rope"
	return ""
