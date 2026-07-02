class_name WorldGenerator
extends RefCounted

const TILE_SIZE := 16
const CHUNK_SIZE := 16

var world_seed: int = 0

var _height_noise: FastNoiseLite
var _moisture_noise: FastNoiseLite
var _rng: RandomNumberGenerator

enum Terrain { DEEP_WATER, SHALLOW_WATER, SAND, GRASS, FOREST, ROCK }

func _setup_noise() -> void:
	_height_noise = FastNoiseLite.new()
	_height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_height_noise.seed = world_seed
	_height_noise.frequency = 0.04

	_moisture_noise = FastNoiseLite.new()
	_moisture_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_moisture_noise.seed = world_seed + 1000
	_moisture_noise.frequency = 0.06

	_rng = RandomNumberGenerator.new()

func generate_chunk(chunk_pos: Vector2i) -> Dictionary:
	if _height_noise == null:
		_setup_noise()
	var origin := chunk_pos * CHUNK_SIZE
	_rng.seed = world_seed + chunk_pos.x * 73856093 + chunk_pos.y * 19349663
	var tiles: Dictionary = {}
	for lx in range(CHUNK_SIZE):
		for ly in range(CHUNK_SIZE):
			var gx: int = origin.x + lx
			var gy: int = origin.y + ly
			var tile_pos := Vector2i(gx, gy)
			var terrain: int = _get_terrain(gx, gy)
			var tile_data: Dictionary = _create_tile_data(terrain, tile_pos)
			tiles[tile_pos] = tile_data
	return tiles

func _get_terrain(x: int, y: int) -> int:
	var height: float = _height_noise.get_noise_2d(x, y)
	var terrain: int = _noise_to_terrain(height)
	if terrain == Terrain.GRASS or terrain == Terrain.FOREST:
		var moisture: float = _moisture_noise.get_noise_2d(x, y)
		if terrain == Terrain.GRASS and moisture > 0.3:
			terrain = Terrain.FOREST
		elif terrain == Terrain.FOREST and moisture < -0.3:
			terrain = Terrain.GRASS
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
	else:
		return Terrain.ROCK

func _create_tile_data(terrain: int, _tile_pos: Vector2i) -> Dictionary:
	var data: Dictionary = {
		"terrain": terrain,
		"resource_type": "",
		"resource_category": "",
		"resource_amount": 0,
		"resource_max": 0,
		"gather_time": 0.0,
		"gather_amount": 0,
		"regenerate": false,
		"regen_rate": 0.0,
		"regen_delay": 0.0,
		"regen_timer": 0.0,
		"regen_waiting": false,
	}
	_assign_resource(data, terrain)
	return data

func _assign_resource(data: Dictionary, terrain: int) -> void:
	match terrain:
		Terrain.GRASS:
			if _rng.randf() < 0.10:
				_set_resource(data, "berry", "food", 8, 1.5, 2, true, 0.8, 20.0)
			elif _rng.randf() < 0.08:
				_set_resource(data, "fiber", "material", 8, 1.5, 2, true, 1.0, 20.0)
		Terrain.FOREST:
			if _rng.randf() < 0.12:
				_set_resource(data, "wood", "material", 8, 3.0, 2, true, 0.3, 45.0)
			elif _rng.randf() < 0.08:
				_set_resource(data, "mushroom", "food", 5, 1.5, 2, true, 0.5, 30.0)
		Terrain.ROCK:
			if _rng.randf() < 0.10:
				_set_resource(data, "stone", "material", 10, 4.0, 2, true, 0.2, 60.0)
			elif _rng.randf() < 0.06:
				_set_resource(data, "iron_ore", "material", 6, 6.0, 1, false, 0.0, 0.0)

func _set_resource(data: Dictionary, type: String, category: String, max_amount: int, gather_time: float, gather_amount: int, regenerate: bool, regen_rate: float, regen_delay: float) -> void:
	data["resource_type"] = type
	data["resource_category"] = category
	data["resource_amount"] = max_amount
	data["resource_max"] = max_amount
	data["gather_time"] = gather_time
	data["gather_amount"] = gather_amount
	data["regenerate"] = regenerate
	data["regen_rate"] = regen_rate
	data["regen_delay"] = regen_delay

func find_village_center(terrain_data: Dictionary) -> Vector2i:
	var best := Vector2i(0, 0)
	var best_score: float = -1.0
	for tile_pos in terrain_data:
		if terrain_data[tile_pos]["terrain"] != Terrain.GRASS:
			continue
		var grass_count := 0
		for dx in range(-3, 4):
			for dy in range(-3, 4):
				var neighbor: Vector2i = Vector2i(tile_pos) + Vector2i(dx, dy)
				if terrain_data.has(neighbor) and terrain_data[neighbor]["terrain"] == Terrain.GRASS:
					grass_count += 1
		var dist: float = Vector2(tile_pos.x, tile_pos.y).length()
		var score: float = grass_count - dist * 0.1
		if score > best_score:
			best_score = score
			best = tile_pos
	return best

func ensure_minimum_resources(terrain_data: Dictionary, village_pos: Vector2i) -> void:
	var counts := {"berry": 0, "wood": 0, "stone": 0, "fiber": 0}
	var minimums := {"berry": 5, "wood": 5, "stone": 3, "fiber": 3}
	for tile_pos in terrain_data:
		if tile_pos.distance_to(village_pos) > 8:
			continue
		var res_type: String = terrain_data[tile_pos]["resource_type"]
		if counts.has(res_type):
			counts[res_type] += 1

	_rng.seed = world_seed + 999
	for res_type in minimums:
		while counts[res_type] < minimums[res_type]:
			var offset := Vector2i(_rng.randi_range(-6, 6), _rng.randi_range(-6, 6))
			var pos := village_pos + offset
			if not terrain_data.has(pos):
				continue
			var data: Dictionary = terrain_data[pos]
			if data["resource_type"] != "":
				continue
			var terrain: int = data["terrain"]
			match res_type:
				"berry":
					if terrain == Terrain.GRASS:
						_set_resource(data, "berry", "food", 8, 1.5, 2, true, 0.8, 20.0)
						counts["berry"] += 1
				"wood":
					if terrain == Terrain.GRASS or terrain == Terrain.FOREST:
						_set_resource(data, "wood", "material", 8, 3.0, 2, true, 0.3, 45.0)
						counts["wood"] += 1
				"stone":
					if terrain == Terrain.ROCK or terrain == Terrain.GRASS or terrain == Terrain.FOREST:
						_set_resource(data, "stone", "material", 10, 5.0, 1, true, 0.15, 90.0)
						counts["stone"] += 1
				"fiber":
					if terrain == Terrain.GRASS:
						_set_resource(data, "fiber", "material", 8, 1.5, 2, true, 1.0, 20.0)
						counts["fiber"] += 1

static func is_walkable(terrain: int) -> bool:
	return terrain != Terrain.DEEP_WATER and terrain != Terrain.SHALLOW_WATER
