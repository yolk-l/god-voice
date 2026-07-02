extends Action

enum Phase { WALKING_TO_RESOURCE, GATHERING, RETURNING }

var _target_tile: Variant = null  # Vector2i or null
var _gather_timer: float = 0.0
var _walk_timer: float = 0.0
var _phase: int = Phase.WALKING_TO_RESOURCE
const MAX_WALK_TIME := 30.0
const MAX_GATHER_RANGE := 200.0

func get_action_name() -> String:
	return "gather_food"

func can_execute(villager: Villager, world: Node) -> bool:
	if villager.inventory.is_full():
		return false
	var nearest = ResourceManager.find_nearest_in_area(
		villager.global_position, "food", MAX_GATHER_RANGE, villager.known_area, true
	)
	return nearest != null

func calculate_utility(villager: Villager, world: Node) -> float:
	var hunger_factor: float = villager.needs.hunger / 100.0
	var total_food: int = villager.inventory.get_food_count() + BuildingManager.get_storage_food_count(villager)
	var food_urgency: float = 0.7 if total_food == 0 else 0.3
	var base: float = hunger_factor * food_urgency

	var nearest = ResourceManager.find_nearest_in_area(
		villager.global_position, "food", MAX_GATHER_RANGE, villager.known_area, true
	)
	if nearest == null:
		return 0.0
	var nearest_world_pos: Vector2 = ResourceManager.tile_to_world_pos(nearest)
	var camp: Vector2 = BuildingManager.get_camp()
	var camp_dist: float = nearest_world_pos.distance_to(camp)
	var camp_factor: float = 1.0 - clampf(camp_dist / 400.0, 0.0, 0.5)
	var distance_factor: float = 1.0 - clampf(villager.global_position.distance_to(nearest_world_pos) / MAX_GATHER_RANGE, 0.0, 0.8)
	return clampf(base * distance_factor * camp_factor, 0.0, 1.0)

func start(villager: Villager, world: Node) -> void:
	_completed = false
	_phase = Phase.WALKING_TO_RESOURCE
	_gather_timer = 0.0
	_walk_timer = 0.0
	_target_tile = ResourceManager.find_nearest_in_area(
		villager.global_position, "food", MAX_GATHER_RANGE, villager.known_area, true
	)
	if _target_tile != null:
		ResourceManager.reserve(_target_tile, villager)
		villager.navigate_to(ResourceManager.tile_to_world_pos(_target_tile))
	else:
		_completed = true

func tick(villager: Villager, world: Node, delta: float) -> void:
	match _phase:
		Phase.WALKING_TO_RESOURCE:
			if _target_tile == null or world.is_tile_depleted(_target_tile):
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
			if _target_tile == null or world.is_tile_depleted(_target_tile):
				villager.needs.set_working(false)
				_start_returning(villager)
				return
			var resource_type: String = world.get_tile_resource_type(_target_tile)
			var efficiency: float = villager.get_gather_efficiency(resource_type)
			_gather_timer += delta * efficiency
			if _gather_timer >= world.get_tile_gather_time(_target_tile):
				var result: Dictionary = world.gather_tile(_target_tile)
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
	if _target_tile != null:
		ResourceManager.release(_target_tile)
	_target_tile = null

func _release_and_complete(villager: Villager) -> void:
	_release_resource()
	_completed = true
