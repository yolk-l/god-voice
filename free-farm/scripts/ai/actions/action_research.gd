extends Action

var _target_tech: String = ""
var _researching: bool = false
var _research_timer: float = 0.0
var _research_time_required: float = 0.0

func get_action_name() -> String:
	return "research"

func can_execute(villager: Villager, world: Node) -> bool:
	if not BuildingManager.has_building("research_table"):
		return false
	return _find_researchable_tech(villager) != ""

func calculate_utility(villager: Villager, world: Node) -> float:
	if _find_researchable_tech(villager) == "":
		return 0.0
	return 0.4

func start(villager: Villager, world: Node) -> void:
	_completed = false
	_researching = false
	_research_timer = 0.0
	_target_tech = _find_researchable_tech(villager)
	if _target_tech == "":
		_completed = true
		return
	_research_time_required = TechTree.get_research_time(_target_tech)
	var table: Node = BuildingManager.get_nearest_building(villager.global_position, "research_table")
	if table and not table.is_occupied():
		table.set_occupied(true)
		villager.navigate_to(table.global_position)
	else:
		_completed = true

func tick(villager: Villager, world: Node, delta: float) -> void:
	if not _researching:
		if villager.has_reached_target():
			var cost: Dictionary = TechTree.get_research_cost(_target_tech)
			for type in cost:
				if not villager.inventory.has_item(type, cost[type]):
					_release_table(villager)
					_completed = true
					return
			for type in cost:
				villager.inventory.remove_item(type, cost[type])
			_researching = true
			villager.needs.set_working(true)
	else:
		_research_timer += delta
		if _research_timer >= _research_time_required:
			TechTree.unlock_tech(_target_tech)
			villager.needs.set_working(false)
			_release_table(villager)
			_completed = true

func cancel(villager: Villager, world: Node) -> void:
	villager.needs.set_working(false)
	_release_table(villager)
	_completed = true

func _release_table(villager: Villager) -> void:
	var table: Node = BuildingManager.get_nearest_building(villager.global_position, "research_table")
	if table:
		table.set_occupied(false)

func _find_researchable_tech(villager: Villager) -> String:
	var techs: Array = TechTree.get_researchable_techs()
	for tech in techs:
		var cost: Dictionary = tech["research_cost"]
		var has_all := true
		for type in cost:
			if not villager.inventory.has_item(type, cost[type]):
				has_all = false
				break
		if has_all:
			return tech["id"]
	return ""
