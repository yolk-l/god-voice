extends Action

var _target_item: Node = null

func get_action_name() -> String:
	return "pickup"

func can_execute(villager: Villager, world: Node) -> bool:
	if villager.inventory.is_full():
		return false
	return _find_ground_item(villager, world) != null

func calculate_utility(villager: Villager, world: Node) -> float:
	var item: Node = _find_ground_item(villager, world)
	if item == null:
		return 0.0
	var base := 0.55
	if item.item_type in ["berry", "mushroom", "cooked_meat"] and villager.needs.hunger > 40:
		base = 0.75
	return base

func start(villager: Villager, world: Node) -> void:
	_completed = false
	_target_item = _find_ground_item(villager, world)
	if _target_item:
		villager.navigate_to(_target_item.global_position)
	else:
		_completed = true

func tick(villager: Villager, world: Node, delta: float) -> void:
	if not is_instance_valid(_target_item):
		_completed = true
		return
	if villager.has_reached_target():
		if villager.global_position.distance_to(_target_item.global_position) < 20.0:
			var result: Dictionary = _target_item.pickup()
			if not result.is_empty():
				villager.inventory.add_item(result["type"], result["amount"])
		_completed = true

func cancel(villager: Villager, world: Node) -> void:
	_completed = true

func _find_ground_item(villager: Villager, world: Node) -> Node:
	var resource_container: Node = world.get_node_or_null("ResourceNodes")
	if not resource_container:
		return null
	var best: Node = null
	var best_dist := 300.0
	for child in resource_container.get_children():
		if not child.has_method("pickup"):
			continue
		if not is_instance_valid(child):
			continue
		var tile_pos: Vector2i = Vector2i(child.global_position / 16.0)
		if not villager.known_area.has(tile_pos):
			continue
		var dist: float = villager.global_position.distance_to(child.global_position)
		if dist < best_dist:
			best_dist = dist
			best = child
	return best
