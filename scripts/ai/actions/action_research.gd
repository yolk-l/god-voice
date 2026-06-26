extends Action

enum Phase { FETCHING, WALKING_TO_TABLE, RESEARCHING }

var _target_tech: String = ""
var _research_timer: float = 0.0
var _research_time_required: float = 0.0
var _research_cost: Dictionary = {}
var _phase: int = Phase.WALKING_TO_TABLE

func get_action_name() -> String:
	return "research"

func can_execute(villager: Villager, world: Node) -> bool:
	if not _completed and _phase == Phase.RESEARCHING:
		return true
	if not BuildingManager.has_building("research_table"):
		return false
	return _find_researchable_tech(villager) != ""

func calculate_utility(villager: Villager, world: Node) -> float:
	if not _completed and _phase == Phase.RESEARCHING:
		return 0.95
	if _find_researchable_tech(villager) == "":
		return 0.0
	return 0.55

func start(villager: Villager, world: Node) -> void:
	_completed = false
	_research_timer = 0.0
	_target_tech = _find_researchable_tech(villager)
	if _target_tech == "":
		_completed = true
		return
	_research_time_required = TechTree.get_research_time(_target_tech)
	_research_cost = TechTree.get_research_cost(_target_tech)

	if _has_cost_in_inventory(villager):
		_phase = Phase.WALKING_TO_TABLE
		var table: Node = BuildingManager.get_nearest_building(villager.global_position, "research_table")
		if table and not table.is_occupied():
			table.set_occupied(true)
			villager.navigate_to(table.global_position)
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
				BuildingManager.withdraw_items(villager, _research_cost)
				if not _has_cost_in_inventory(villager):
					_completed = true
					return
				_phase = Phase.WALKING_TO_TABLE
				var table: Node = BuildingManager.get_nearest_building(villager.global_position, "research_table")
				if table and not table.is_occupied():
					table.set_occupied(true)
					villager.navigate_to(table.global_position)
				else:
					_completed = true
		Phase.WALKING_TO_TABLE:
			if villager.has_reached_target():
				if not _has_cost_in_inventory(villager):
					_release_table(villager)
					_completed = true
					return
				for type in _research_cost:
					villager.inventory.remove_item(type, _research_cost[type])
				_phase = Phase.RESEARCHING
				villager.needs.set_working(true)
		Phase.RESEARCHING:
			_research_timer += delta
			if _research_timer >= _research_time_required:
				TechTree.unlock_tech(_target_tech)
				var tech_data: Dictionary = TechTree.get_tech_data(_target_tech)
				var tech_name: String = tech_data.get("display_name", _target_tech)
				EventLog.add(villager.villager_name, "research", "%s researched %s" % [villager.villager_name, tech_name])
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

func _has_cost_in_inventory(villager: Villager) -> bool:
	for type in _research_cost:
		if not villager.inventory.has_item(type, _research_cost[type]):
			return false
	return true

func _find_researchable_tech(villager: Villager) -> String:
	var techs: Array = TechTree.get_researchable_techs()
	for tech in techs:
		var cost: Dictionary = tech["research_cost"]
		if BuildingManager.has_items_available(villager, cost):
			return tech["id"]
	return ""
