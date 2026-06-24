extends Node

var _resources: Array[Node] = []
var _reservations: Dictionary = {}  # {resource_node_id: villager_ref}

func register(resource_node: Node) -> void:
	if resource_node not in _resources:
		_resources.append(resource_node)

func unregister(resource_node: Node) -> void:
	_resources.erase(resource_node)
	release(resource_node)

func find_nearest(pos: Vector2, type: String, max_distance: float, exclude_reserved: bool = true) -> Node:
	var best: Node = null
	var best_dist := max_distance
	for res in _resources:
		if not is_instance_valid(res):
			continue
		if res.is_depleted:
			continue
		if type != "" and res.resource_type != type and res.resource_category != type:
			continue
		if exclude_reserved and is_reserved(res):
			continue
		var dist: float = pos.distance_to(res.global_position)
		if dist < best_dist:
			best_dist = dist
			best = res
	return best

func find_nearest_in_area(pos: Vector2, type: String, max_distance: float, known_area: Dictionary, exclude_reserved: bool = true) -> Node:
	var best: Node = null
	var best_dist := max_distance
	for res in _resources:
		if not is_instance_valid(res):
			continue
		if res.is_depleted:
			continue
		if type != "" and res.resource_type != type and res.resource_category != type:
			continue
		if exclude_reserved and is_reserved(res):
			continue
		var tile_pos: Vector2i = Vector2i(res.global_position / 16.0)
		if not known_area.has(tile_pos):
			continue
		var dist: float = pos.distance_to(res.global_position)
		if dist < best_dist:
			best_dist = dist
			best = res
	return best

func reserve(resource_node: Node, villager: Node) -> void:
	_reservations[resource_node.get_instance_id()] = villager

func release(resource_node: Node) -> void:
	_reservations.erase(resource_node.get_instance_id())

func release_all_for(villager: Node) -> void:
	var to_remove: Array = []
	for key in _reservations:
		if _reservations[key] == villager:
			to_remove.append(key)
	for key in to_remove:
		_reservations.erase(key)

func is_reserved(resource_node: Node) -> bool:
	return _reservations.has(resource_node.get_instance_id())

func get_all_of_type(type: String) -> Array[Node]:
	var result: Array[Node] = []
	for res in _resources:
		if not is_instance_valid(res):
			continue
		if type == "" or res.resource_type == type or res.resource_category == type:
			result.append(res)
	return result
