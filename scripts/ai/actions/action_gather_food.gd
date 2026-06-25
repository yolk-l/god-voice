extends Action

enum Phase { WALKING_TO_RESOURCE, GATHERING, RETURNING }

var _target_resource: Node = null
var _gather_timer: float = 0.0
var _walk_timer: float = 0.0
var _phase: int = Phase.WALKING_TO_RESOURCE
const MAX_WALK_TIME := 30.0

func get_action_name() -> String:
	return "gather_food"

const MAX_GATHER_RANGE := 200.0

func can_execute(villager: Villager, world: Node) -> bool:
	if villager.inventory.is_full():
		return false
	var nearest: Node = ResourceManager.find_nearest_in_area(
		villager.global_position, "food", MAX_GATHER_RANGE, villager.known_area, true
	)
	return nearest != null

func calculate_utility(villager: Villager, world: Node) -> float:
	var hunger_factor: float = villager.needs.hunger / 100.0
	var total_food: int = villager.inventory.get_food_count() + BuildingManager.get_storage_food_count(villager)
	var food_urgency: float = 0.7 if total_food == 0 else 0.3
	var base: float = hunger_factor * food_urgency

	var nearest: Node = ResourceManager.find_nearest_in_area(
		villager.global_position, "food", MAX_GATHER_RANGE, villager.known_area, true
	)
	if nearest == null:
		return 0.0
	var camp: Vector2 = BuildingManager.get_camp()
	var camp_dist: float = nearest.global_position.distance_to(camp)
	var camp_penalty: float = clampf(camp_dist / 300.0, 0.0, 0.5)
	var distance_factor: float = 1.0 - clampf(villager.global_position.distance_to(nearest.global_position) / MAX_GATHER_RANGE, 0.0, 0.8)
	return clampf((base * distance_factor) - camp_penalty, 0.0, 1.0)

func start(villager: Villager, world: Node) -> void:
	_completed = false
	_phase = Phase.WALKING_TO_RESOURCE
	_gather_timer = 0.0
	_walk_timer = 0.0
	_target_resource = ResourceManager.find_nearest_in_area(
		villager.global_position, "food", MAX_GATHER_RANGE, villager.known_area, true
	)
	if _target_resource:
		ResourceManager.reserve(_target_resource, villager)
		villager.navigate_to(_target_resource.global_position)
	else:
		_completed = true

func tick(villager: Villager, world: Node, delta: float) -> void:
	match _phase:
		Phase.WALKING_TO_RESOURCE:
			if not is_instance_valid(_target_resource) or _target_resource.is_depleted:
				_release_and_complete(villager)
				return
			_walk_timer += delta
			if _walk_timer >= MAX_WALK_TIME:
				_release_and_complete(villager)
				return
			if villager.has_reached_target():
				_phase = Phase.GATHERING
				_gather_timer = 0.0
				villager.needs.set_working(true)
		Phase.GATHERING:
			if not is_instance_valid(_target_resource) or _target_resource.is_depleted:
				villager.needs.set_working(false)
				_start_returning(villager)
				return
			var efficiency: float = villager.get_gather_efficiency(_target_resource.resource_type)
			_gather_timer += delta * efficiency
			if _gather_timer >= _target_resource.gather_time:
				var result: Dictionary = _target_resource.gather()
				if not result.is_empty():
					villager.inventory.add_item(result["type"], result["amount"])
				villager.needs.set_working(false)
				_release_resource()
				_start_returning(villager)
		Phase.RETURNING:
			if villager.has_reached_target():
				_deposit_at_camp(villager)
				_completed = true

func cancel(villager: Villager, world: Node) -> void:
	villager.needs.set_working(false)
	_release_resource()
	_completed = true

func _start_returning(villager: Villager) -> void:
	_phase = Phase.RETURNING
	var chest: Node = BuildingManager.get_nearest_chest_with_space(villager.global_position)
	if chest:
		villager.navigate_to(chest.global_position)
	else:
		villager.navigate_to(BuildingManager.get_camp())

func _deposit_at_camp(villager: Villager) -> void:
	var chest: Node = BuildingManager.get_nearest_chest_with_space(villager.global_position)
	if chest and villager.global_position.distance_to(chest.global_position) < 20.0:
		var items: Dictionary = villager.inventory.get_all_items()
		for type in items:
			if type in ["stone_axe", "stone_pickaxe"]:
				continue
			var amount: int = items[type]
			var deposited: int = chest.add_item(type, amount)
			villager.inventory.remove_item(type, deposited)

func _release_resource() -> void:
	if _target_resource and is_instance_valid(_target_resource):
		ResourceManager.release(_target_resource)
	_target_resource = null

func _release_and_complete(villager: Villager) -> void:
	_release_resource()
	_completed = true
