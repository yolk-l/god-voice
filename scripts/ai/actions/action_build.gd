extends Action

var _target_building_type: String = ""
var _build_position: Vector2 = Vector2.ZERO
var _building: bool = false
var _build_timer: float = 0.0
var _build_time_required: float = 0.0

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
		var night_factor: float = 0.4
		if GameManager.is_approaching_night():
			night_factor += 0.4
		if villager.inventory.has_materials_for("shelter"):
			scores.append(night_factor)

	if not BuildingManager.has_building("campfire"):
		if villager.inventory.has_materials_for("campfire"):
			scores.append(0.45)

	if not BuildingManager.has_building("chest"):
		if villager.inventory.is_full() and villager.inventory.has_materials_for("chest"):
			scores.append(0.5)

	if not BuildingManager.has_building("workbench"):
		if villager.inventory.has_materials_for("workbench"):
			scores.append(0.4)

	if BuildingManager.has_building("workbench") and not BuildingManager.has_building("research_table"):
		if villager.inventory.has_materials_for("research_table"):
			scores.append(0.35)

	if TechTree.is_building_unlocked("farm") and not BuildingManager.has_building("farm"):
		if villager.inventory.has_materials_for("farm"):
			scores.append(0.4)

	if TechTree.is_building_unlocked("smelter") and not BuildingManager.has_building("smelter"):
		if villager.inventory.has_materials_for("smelter"):
			scores.append(0.4)

	if TechTree.is_building_unlocked("loom") and not BuildingManager.has_building("loom"):
		if villager.inventory.has_materials_for("loom"):
			scores.append(0.35)

	if scores.is_empty():
		return 0.0
	return scores.max()

func start(villager: Villager, world: Node) -> void:
	_completed = false
	_building = false
	_build_timer = 0.0
	_target_building_type = _find_best_building(villager)
	if _target_building_type == "":
		_completed = true
		return
	_build_time_required = BUILD_TIMES.get(_target_building_type, 6.0)
	_build_position = BuildingManager.find_build_position(world)
	villager.navigate_to(_build_position)

func tick(villager: Villager, world: Node, delta: float) -> void:
	if not _building:
		if villager.has_reached_target():
			if not villager.inventory.has_materials_for(_target_building_type):
				_completed = true
				return
			villager.inventory.consume_materials(_target_building_type)
			_building = true
			villager.needs.set_working(true)
	else:
		_build_timer += delta
		if _build_timer >= _build_time_required:
			_place_building(villager, world)
			villager.needs.set_working(false)
			_completed = true

func cancel(villager: Villager, world: Node) -> void:
	villager.needs.set_working(false)
	_completed = true

func _find_best_building(villager: Villager) -> String:
	if not BuildingManager.has_building("shelter") and villager.inventory.has_materials_for("shelter"):
		return "shelter"
	if not BuildingManager.has_building("campfire") and villager.inventory.has_materials_for("campfire"):
		return "campfire"
	if not BuildingManager.has_building("chest") and villager.inventory.has_materials_for("chest"):
		return "chest"
	if not BuildingManager.has_building("workbench") and villager.inventory.has_materials_for("workbench"):
		return "workbench"
	if BuildingManager.has_building("workbench") and not BuildingManager.has_building("research_table"):
		if villager.inventory.has_materials_for("research_table"):
			return "research_table"
	if TechTree.is_building_unlocked("farm") and not BuildingManager.has_building("farm"):
		if villager.inventory.has_materials_for("farm"):
			return "farm"
	if TechTree.is_building_unlocked("smelter") and not BuildingManager.has_building("smelter"):
		if villager.inventory.has_materials_for("smelter"):
			return "smelter"
	if TechTree.is_building_unlocked("loom") and not BuildingManager.has_building("loom"):
		if villager.inventory.has_materials_for("loom"):
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
	if _target_building_type == "shelter" and villager.home == null:
		villager.home = building
