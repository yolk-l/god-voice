extends Node

const TILE_SIZE := 16

var _resource_tiles: Dictionary = {}   # {Vector2i: {type: String, category: String}}
var _reservations: Dictionary = {}     # {Vector2i: villager_ref}

func register_tile(tile_pos: Vector2i, type: String, category: String) -> void:
	_resource_tiles[tile_pos] = {"type": type, "category": category}

func unregister_tile(tile_pos: Vector2i) -> void:
	_resource_tiles.erase(tile_pos)
	_reservations.erase(tile_pos)

func find_nearest(pos: Vector2, type: String, max_distance: float, exclude_reserved: bool = true) -> Variant:
	var best_tile: Variant = null
	var best_dist := max_distance
	for tile_pos in _resource_tiles:
		var info: Dictionary = _resource_tiles[tile_pos]
		if type != "" and info["type"] != type and info["category"] != type:
			continue
		if exclude_reserved and _reservations.has(tile_pos):
			continue
		var world_pos: Vector2 = Vector2(tile_pos) * TILE_SIZE + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
		var dist: float = pos.distance_to(world_pos)
		if dist < best_dist:
			best_dist = dist
			best_tile = tile_pos
	return best_tile

func find_nearest_in_area(pos: Vector2, type: String, max_distance: float, known_area: Dictionary, exclude_reserved: bool = true) -> Variant:
	var best_tile: Variant = null
	var best_dist := max_distance
	for tile_pos in _resource_tiles:
		if not known_area.has(tile_pos):
			continue
		var info: Dictionary = _resource_tiles[tile_pos]
		if type != "" and info["type"] != type and info["category"] != type:
			continue
		if exclude_reserved and _reservations.has(tile_pos):
			continue
		var world_pos: Vector2 = Vector2(tile_pos) * TILE_SIZE + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
		var dist: float = pos.distance_to(world_pos)
		if dist < best_dist:
			best_dist = dist
			best_tile = tile_pos
	return best_tile

func reserve(tile_pos: Vector2i, villager: Node) -> void:
	_reservations[tile_pos] = villager

func release(tile_pos: Vector2i) -> void:
	_reservations.erase(tile_pos)

func release_all_for(villager: Node) -> void:
	var to_remove: Array = []
	for key in _reservations:
		if _reservations[key] == villager:
			to_remove.append(key)
	for key in to_remove:
		_reservations.erase(key)

func is_reserved(tile_pos: Vector2i) -> bool:
	return _reservations.has(tile_pos)

func get_all_of_type(type: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for tile_pos in _resource_tiles:
		var info: Dictionary = _resource_tiles[tile_pos]
		if type == "" or info["type"] == type or info["category"] == type:
			result.append(tile_pos)
	return result

func tile_to_world_pos(tile_pos: Vector2i) -> Vector2:
	return Vector2(tile_pos) * TILE_SIZE + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
