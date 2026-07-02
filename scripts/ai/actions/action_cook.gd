extends Action

enum Phase { FETCHING, WALKING_TO_CAMPFIRE, COOKING }

var _cook_timer: float = 0.0
var _phase: int = Phase.WALKING_TO_CAMPFIRE
var _cooking_item: String = ""
const COOK_TIME := 3.0

const COOKABLE := {
	"raw_meat": "cooked_meat",
	"fish": "cooked_fish",
}

func get_action_name() -> String:
	return "cook"

func can_execute(villager: Villager, world: Node) -> bool:
	if not TechTree.is_feature_unlocked("cooking"):
		return false
	if not BuildingManager.has_building("campfire"):
		return false
	return _get_cookable_count(villager) >= 1

func calculate_utility(villager: Villager, world: Node) -> float:
	if not can_execute(villager, world):
		return 0.0
	var count: int = _get_cookable_count(villager)
	return clampf(0.45 + count * 0.05, 0.0, 0.7)

func start(villager: Villager, world: Node) -> void:
	_completed = false
	_cook_timer = 0.0
	_cooking_item = _find_cookable_in_inventory(villager)

	if _cooking_item != "":
		_phase = Phase.WALKING_TO_CAMPFIRE
		var campfire: Node = BuildingManager.get_nearest_building(villager.global_position, "campfire")
		if campfire:
			villager.navigate_to(campfire.global_position)
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
				_cooking_item = _withdraw_cookable(villager)
				if _cooking_item == "":
					_completed = true
					return
				_phase = Phase.WALKING_TO_CAMPFIRE
				var campfire: Node = BuildingManager.get_nearest_building(villager.global_position, "campfire")
				if campfire:
					villager.navigate_to(campfire.global_position)
				else:
					_completed = true
		Phase.WALKING_TO_CAMPFIRE:
			if villager.has_reached_target():
				if _cooking_item == "" or not villager.inventory.has_item(_cooking_item, 1):
					_completed = true
					return
				_phase = Phase.COOKING
				villager.needs.set_working(true)
		Phase.COOKING:
			_cook_timer += delta
			if _cook_timer >= COOK_TIME:
				villager.inventory.remove_item(_cooking_item, 1)
				villager.inventory.add_item(COOKABLE[_cooking_item], 1)
				villager.needs.set_working(false)
				_completed = true

func cancel(villager: Villager, world: Node) -> void:
	villager.needs.set_working(false)
	_completed = true

func _get_cookable_count(villager: Villager) -> int:
	var total := 0
	for raw_type in COOKABLE:
		total += villager.inventory.get_amount(raw_type) + BuildingManager.get_storage_items(raw_type)
	return total

func _find_cookable_in_inventory(villager: Villager) -> String:
	for raw_type in COOKABLE:
		if villager.inventory.has_item(raw_type, 1):
			return raw_type
	return ""

func _withdraw_cookable(villager: Villager) -> String:
	for raw_type in COOKABLE:
		var cost := {raw_type: 1}
		if BuildingManager.has_items_available(villager, cost):
			BuildingManager.withdraw_items(villager, cost)
			if villager.inventory.has_item(raw_type, 1):
				return raw_type
	return ""
