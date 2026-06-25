extends Action

enum Phase { FETCHING, WALKING_TO_SITE, BUILDING }

var _target_building_type: String = ""
var _build_position: Vector2 = Vector2.ZERO
var _build_timer: float = 0.0
var _build_time_required: float = 0.0
var _phase: int = Phase.WALKING_TO_SITE

const BUILD_TIMES := {
	"shelter": 8.0,
	"campfire": 4.0,
	"chest": 5.0,
	"workbench": 6.0,
	"research_table": 10.0,
	"farm": 8.0,
	"smelter": 10.0,
	"loom": 8.0,
}

func get_action_name() -> String:
	return "build"

func can_execute(villager: Villager, world: Node) -> bool:
	return _find_best_building(villager) != ""

func calculate_utility(villager: Villager, world: Node) -> float:
	var scores: Array[float] = []

	if not BuildingManager.has_building("shelter"):
		var night_factor: float = 0.65
		if GameManager.is_approaching_night():
			night_factor += 0.3
		if _has_materials(villager, "shelter"):
			scores.append(night_factor)

	if not BuildingManager.has_building("campfire"):
		if _has_materials(villager, "campfire"):
			scores.append(0.65)

	if not BuildingManager.has_building("chest"):
		if _has_materials(villager, "chest"):
			scores.append(0.65)

	if not BuildingManager.has_building("workbench"):
		if _has_materials(villager, "workbench"):
			scores.append(0.6)

	if BuildingManager.has_building("workbench") and not BuildingManager.has_building("research_table"):
		if _has_materials(villager, "research_table"):
			scores.append(0.6)

	if TechTree.is_building_unlocked("farm") and not BuildingManager.has_building("farm"):
		if _has_materials(villager, "farm"):
			scores.append(0.55)

	if TechTree.is_building_unlocked("smelter") and not BuildingManager.has_building("smelter"):
		if _has_materials(villager, "smelter"):
			scores.append(0.55)

	if TechTree.is_building_unlocked("loom") and not BuildingManager.has_building("loom"):
		if _has_materials(villager, "loom"):
			scores.append(0.55)

	if scores.is_empty():
		return 0.0
	return scores.max()

func start(villager: Villager, world: Node) -> void:
	_completed = false
	_build_timer = 0.0
	_target_building_type = _find_best_building(villager)
	if _target_building_type == "":
		_completed = true
		return
	_build_time_required = BUILD_TIMES.get(_target_building_type, 6.0)
	_build_position = BuildingManager.find_build_position(world)

	if villager.inventory.has_materials_for(_target_building_type):
		_phase = Phase.WALKING_TO_SITE
		villager.navigate_to(_build_position)
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
				var cost: Dictionary = VillagerInventory.get_recipe_cost(_target_building_type)
				BuildingManager.withdraw_items(villager, cost)
				if not villager.inventory.has_materials_for(_target_building_type):
					_completed = true
					return
				_phase = Phase.WALKING_TO_SITE
				villager.navigate_to(_build_position)
		Phase.WALKING_TO_SITE:
			if villager.has_reached_target():
				if not villager.inventory.has_materials_for(_target_building_type):
					_completed = true
					return
				villager.inventory.consume_materials(_target_building_type)
				_phase = Phase.BUILDING
				villager.needs.set_working(true)
		Phase.BUILDING:
			_build_timer += delta
			if _build_timer >= _build_time_required:
				_place_building(villager, world)
				villager.needs.set_working(false)
				_completed = true

func cancel(villager: Villager, world: Node) -> void:
	villager.needs.set_working(false)
	_completed = true

func _has_materials(villager: Villager, recipe: String) -> bool:
	if villager.inventory.has_materials_for(recipe):
		return true
	var cost: Dictionary = VillagerInventory.get_recipe_cost(recipe)
	return BuildingManager.has_items_available(villager, cost)

func _find_best_building(villager: Villager) -> String:
	if not BuildingManager.has_building("shelter") and _has_materials(villager, "shelter"):
		return "shelter"
	if not BuildingManager.has_building("campfire") and _has_materials(villager, "campfire"):
		return "campfire"
	if not BuildingManager.has_building("chest") and _has_materials(villager, "chest"):
		return "chest"
	if not BuildingManager.has_building("workbench") and _has_materials(villager, "workbench"):
		return "workbench"
	if BuildingManager.has_building("workbench") and not BuildingManager.has_building("research_table"):
		if _has_materials(villager, "research_table"):
			return "research_table"
	if TechTree.is_building_unlocked("farm") and not BuildingManager.has_building("farm"):
		if _has_materials(villager, "farm"):
			return "farm"
	if TechTree.is_building_unlocked("smelter") and not BuildingManager.has_building("smelter"):
		if _has_materials(villager, "smelter"):
			return "smelter"
	if TechTree.is_building_unlocked("loom") and not BuildingManager.has_building("loom"):
		if _has_materials(villager, "loom"):
			return "loom"
	return ""

func _place_building(villager: Villager, world: Node) -> void:
	var building_scene: PackedScene = preload("res://scenes/entities/building.tscn")
	var building: Node = building_scene.instantiate()
	building.building_type = _target_building_type
	building.global_position = _build_position
	building.is_completed = true
	world.get_node("Buildings").add_child(building)
	BuildingManager.register(building)
	EventLog.add(villager.villager_name, "build", "%s built %s" % [villager.villager_name, _target_building_type])
	if _target_building_type == "shelter" and villager.home == null:
		villager.home = building
