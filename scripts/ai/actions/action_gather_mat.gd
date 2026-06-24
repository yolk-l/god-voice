extends Action

var _target_resource: Node = null
var _gathering: bool = false
var _gather_timer: float = 0.0

func get_action_name() -> String:
	return "gather_mat"

const MAX_GATHER_RANGE := 200.0

func can_execute(villager: Villager, world: Node) -> bool:
	if villager.inventory.is_full():
		return false
	var nearest: Node = ResourceManager.find_nearest_in_area(
		villager.global_position, "material", MAX_GATHER_RANGE, villager.known_area, true
	)
	return nearest != null

func calculate_utility(villager: Villager, world: Node) -> float:
	var fullness: float = villager.inventory.get_occupied_slots() / float(VillagerInventory.MAX_SLOTS)
	var base: float = (1.0 - fullness) * 0.5
	var build_need: float = BuildingManager.get_unmet_material_urgency(villager)
	base += build_need * 0.3

	var nearest: Node = ResourceManager.find_nearest_in_area(
		villager.global_position, "material", MAX_GATHER_RANGE, villager.known_area, true
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
	_gathering = false
	_gather_timer = 0.0
	_target_resource = ResourceManager.find_nearest_in_area(
		villager.global_position, "material", MAX_GATHER_RANGE, villager.known_area, true
	)
	if _target_resource:
		ResourceManager.reserve(_target_resource, villager)
		villager.navigate_to(_target_resource.global_position)
	else:
		_completed = true

func tick(villager: Villager, world: Node, delta: float) -> void:
	if not is_instance_valid(_target_resource) or _target_resource.is_depleted:
		_release_and_complete(villager)
		return
	if not _gathering:
		if villager.has_reached_target():
			_gathering = true
			_gather_timer = 0.0
			villager.needs.set_working(true)
	else:
		var efficiency: float = villager.get_gather_efficiency(_target_resource.resource_type)
		_gather_timer += delta * efficiency
		if _gather_timer >= _target_resource.gather_time:
			var result: Dictionary = _target_resource.gather()
			if not result.is_empty():
				villager.inventory.add_item(result["type"], result["amount"])
			villager.needs.set_working(false)
			_release_and_complete(villager)

func cancel(villager: Villager, world: Node) -> void:
	villager.needs.set_working(false)
	_release_and_complete(villager)

func _release_and_complete(villager: Villager) -> void:
	if _target_resource and is_instance_valid(_target_resource):
		ResourceManager.release(_target_resource)
	_target_resource = null
	_completed = true
