class_name WorldGenerator
extends RefCounted

const TILE_SIZE := 16

var world_seed: int = 0

var _height_noise: FastNoiseLite
var _moisture_noise: FastNoiseLite

enum Terrain { DEEP_WATER, SHALLOW_WATER, SAND, GRASS, FOREST, ROCK, MOUNTAIN }

func generate(width: int, height: int) -> Array:
	_setup_noise()
	var terrain: Array = _generate_height_map(width, height)
	_apply_moisture(terrain, width, height)
	_force_border_mountains(terrain, width, height)
	if not _validate_connectivity(terrain, width, height):
		world_seed += 1
		return generate(width, height)
	return terrain

func _setup_noise() -> void:
	_height_noise = FastNoiseLite.new()
	_height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_height_noise.seed = world_seed
	_height_noise.frequency = 0.04

	_moisture_noise = FastNoiseLite.new()
	_moisture_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_moisture_noise.seed = world_seed + 1000
	_moisture_noise.frequency = 0.06

func _generate_height_map(width: int, height: int) -> Array:
	var terrain: Array = []
	terrain.resize(width)
	for x in range(width):
		terrain[x] = []
		terrain[x].resize(height)
		for y in range(height):
			var noise_val: float = _height_noise.get_noise_2d(x, y)
			terrain[x][y] = _noise_to_terrain(noise_val)
	return terrain

func _noise_to_terrain(val: float) -> int:
	if val < -0.3:
		return Terrain.DEEP_WATER
	elif val < -0.1:
		return Terrain.SHALLOW_WATER
	elif val < 0.0:
		return Terrain.SAND
	elif val < 0.3:
		return Terrain.GRASS
	elif val < 0.6:
		return Terrain.FOREST
	elif val < 0.8:
		return Terrain.ROCK
	else:
		return Terrain.MOUNTAIN

func _apply_moisture(terrain: Array, width: int, height: int) -> void:
	for x in range(width):
		for y in range(height):
			if terrain[x][y] == Terrain.GRASS or terrain[x][y] == Terrain.FOREST:
				var moisture: float = _moisture_noise.get_noise_2d(x, y)
				if terrain[x][y] == Terrain.GRASS and moisture > 0.3:
					terrain[x][y] = Terrain.FOREST
				elif terrain[x][y] == Terrain.FOREST and moisture < -0.3:
					terrain[x][y] = Terrain.GRASS

func _force_border_mountains(terrain: Array, width: int, height: int) -> void:
	var border: int = 2
	for x in range(width):
		for y in range(height):
			if x < border or x >= width - border or y < border or y >= height - border:
				terrain[x][y] = Terrain.MOUNTAIN

func _validate_connectivity(terrain: Array, width: int, height: int) -> bool:
	var start: Vector2i = find_village_center(terrain, width, height)
	if start == Vector2i(-1, -1):
		return false
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	visited[start] = true
	var walkable_total: int = 0
	for x in range(width):
		for y in range(height):
			if _is_walkable(terrain[x][y]):
				walkable_total += 1
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var neighbor: Vector2i = current + dir
			if neighbor.x < 0 or neighbor.x >= width or neighbor.y < 0 or neighbor.y >= height:
				continue
			if visited.has(neighbor):
				continue
			if _is_walkable(terrain[neighbor.x][neighbor.y]):
				visited[neighbor] = true
				queue.append(neighbor)
	var reachable: int = visited.size()
	return reachable >= walkable_total * 0.4

func _is_walkable(terrain_type: int) -> bool:
	return terrain_type != Terrain.DEEP_WATER and terrain_type != Terrain.SHALLOW_WATER and terrain_type != Terrain.MOUNTAIN

func find_village_center(terrain: Array, width: int, height: int) -> Vector2i:
	var center: Vector2i = Vector2i(width / 2, height / 2)
	var best: Vector2i = Vector2i(-1, -1)
	var best_dist: float = INF
	for x in range(width):
		for y in range(height):
			if terrain[x][y] == Terrain.GRASS:
				var dist: float = Vector2(x - center.x, y - center.y).length()
				if dist < best_dist:
					var grass_count: int = _count_nearby_grass(terrain, x, y, width, height)
					if grass_count >= 20:
						best_dist = dist
						best = Vector2i(x, y)
	if best == Vector2i(-1, -1):
		for x in range(width):
			for y in range(height):
				if terrain[x][y] == Terrain.GRASS:
					return Vector2i(x, y)
	return best

func _count_nearby_grass(terrain: Array, cx: int, cy: int, width: int, height: int) -> int:
	var count: int = 0
	for dx in range(-3, 4):
		for dy in range(-3, 4):
			var x: int = cx + dx
			var y: int = cy + dy
			if x >= 0 and x < width and y >= 0 and y < height:
				if terrain[x][y] == Terrain.GRASS:
					count += 1
	return count

func spawn_resources(terrain: Array, container: Node2D) -> void:
	var width: int = terrain.size()
	var height: int = terrain[0].size()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = world_seed + 500
	var village_pos: Vector2i = find_village_center(terrain, width, height)
	var guaranteed_berries: int = 0
	var guaranteed_trees: int = 0

	for x in range(width):
		for y in range(height):
			var terrain_type: int = terrain[x][y]
			var pos: Vector2 = Vector2(x * TILE_SIZE + TILE_SIZE / 2.0, y * TILE_SIZE + TILE_SIZE / 2.0)
			var near_village: bool = Vector2i(x, y).distance_to(village_pos) < 8

			match terrain_type:
				Terrain.GRASS:
					if rng.randf() < 0.06:
						_place_resource(container, pos, "berry", "food", 5, 2.0, 1, true, 0.5, 30.0)
						if near_village:
							guaranteed_berries += 1
					elif rng.randf() < 0.08:
						_place_resource(container, pos, "fiber", "material", 8, 1.5, 2, true, 1.0, 20.0)
				Terrain.FOREST:
					if rng.randf() < 0.12:
						_place_resource(container, pos, "wood", "material", 8, 4.0, 1, true, 0.2, 60.0)
						if near_village:
							guaranteed_trees += 1
					elif rng.randf() < 0.05:
						_place_resource(container, pos, "mushroom", "food", 3, 1.5, 1, true, 0.3, 40.0)
				Terrain.ROCK:
					if rng.randf() < 0.10:
						_place_resource(container, pos, "stone", "material", 10, 5.0, 1, false, 0.0, 0.0)
					elif rng.randf() < 0.06:
						_place_resource(container, pos, "iron_ore", "material", 6, 6.0, 1, false, 0.0, 0.0)

	_ensure_minimum_resources(terrain, container, village_pos, guaranteed_berries, guaranteed_trees, rng)

func _ensure_minimum_resources(terrain: Array, container: Node2D, village_pos: Vector2i, berries: int, trees: int, rng: RandomNumberGenerator) -> void:
	var width: int = terrain.size()
	var height: int = terrain[0].size()
	while berries < 3:
		var offset: Vector2i = Vector2i(rng.randi_range(-6, 6), rng.randi_range(-6, 6))
		var pos_tile: Vector2i = village_pos + offset
		if pos_tile.x >= 0 and pos_tile.x < width and pos_tile.y >= 0 and pos_tile.y < height:
			if terrain[pos_tile.x][pos_tile.y] == Terrain.GRASS:
				var pos: Vector2 = Vector2(pos_tile.x * TILE_SIZE + TILE_SIZE / 2.0, pos_tile.y * TILE_SIZE + TILE_SIZE / 2.0)
				_place_resource(container, pos, "berry", "food", 5, 2.0, 1, true, 0.5, 30.0)
				berries += 1
	while trees < 5:
		var offset: Vector2i = Vector2i(rng.randi_range(-8, 8), rng.randi_range(-8, 8))
		var pos_tile: Vector2i = village_pos + offset
		if pos_tile.x >= 0 and pos_tile.x < width and pos_tile.y >= 0 and pos_tile.y < height:
			if terrain[pos_tile.x][pos_tile.y] == Terrain.GRASS or terrain[pos_tile.x][pos_tile.y] == Terrain.FOREST:
				var pos: Vector2 = Vector2(pos_tile.x * TILE_SIZE + TILE_SIZE / 2.0, pos_tile.y * TILE_SIZE + TILE_SIZE / 2.0)
				_place_resource(container, pos, "wood", "material", 8, 4.0, 1, true, 0.2, 60.0)
				trees += 1

func _place_resource(container: Node2D, pos: Vector2, type: String, category: String, max_amount: int, gather_time: float, gather_amount: int, regenerate: bool, regen_rate: float, regen_delay: float) -> void:
	var resource_node: Node = preload("res://scenes/world/resource_node.tscn").instantiate()
	resource_node.global_position = pos
	resource_node.resource_type = type
	resource_node.resource_category = category
	resource_node.max_amount = max_amount
	resource_node.current_amount = max_amount
	resource_node.gather_time = gather_time
	resource_node.gather_amount = gather_amount
	resource_node.regenerate = regenerate
	resource_node.regen_rate = regen_rate
	resource_node.regen_delay = regen_delay
	container.add_child(resource_node)
