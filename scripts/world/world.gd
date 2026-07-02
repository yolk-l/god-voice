extends Node2D

const TILE_SIZE := 16
const CHUNK_SIZE := 16

@onready var tile_map: TileMapLayer = $TileMap
@onready var buildings: Node2D = $Buildings
@onready var villagers: Node2D = $Villagers

var resource_layer: TileMapLayer
var world_generator: WorldGenerator
var terrain_data: Dictionary = {}       # {Vector2i: Dictionary}
var _generated_chunks: Dictionary = {}  # {Vector2i: true}
var _depleted_tiles: Array[Vector2i] = []
var _map_bounds: Rect2 = Rect2()

const POP_PER_SHELTER := 3
const POP_HARD_CAP := 15
const POP_CHECK_INTERVAL := 10.0
const POP_MIN_AVG_HUNGER := 40.0
var _pop_timer: float = 0.0

enum Terrain { DEEP_WATER, SHALLOW_WATER, SAND, GRASS, FOREST, ROCK }

func _ready() -> void:
	_setup_tileset()
	_setup_resource_layer()
	world_generator = WorldGenerator.new()
	generate_world()
	_spawn_initial_villagers()
	_setup_fog_tileset()
	GameManager.day_changed.connect(_on_day_changed)

func _setup_tileset() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var source := TileSetAtlasSource.new()
	var img := Image.create(TILE_SIZE * 6, TILE_SIZE, false, Image.FORMAT_RGBA8)
	var colors := [
		Color(0.1, 0.15, 0.4),   # deep water
		Color(0.2, 0.4, 0.7),    # shallow water
		Color(0.85, 0.8, 0.55),  # sand
		Color(0.3, 0.7, 0.2),    # grass
		Color(0.1, 0.4, 0.15),   # forest
		Color(0.5, 0.5, 0.5),    # rock
	]
	for i in range(6):
		for x in range(TILE_SIZE):
			for y in range(TILE_SIZE):
				img.set_pixel(i * TILE_SIZE + x, y, colors[i])
	var tex := ImageTexture.create_from_image(img)
	source.texture = tex
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for i in range(6):
		source.create_tile(Vector2i(i, 0))
	ts.add_source(source, 0)
	tile_map.tile_set = ts

func _setup_resource_layer() -> void:
	resource_layer = TileMapLayer.new()
	resource_layer.name = "ResourceLayer"
	resource_layer.z_index = 1
	add_child(resource_layer)
	move_child(resource_layer, tile_map.get_index() + 1)

	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var source := TileSetAtlasSource.new()
	var img := Image.create(TILE_SIZE * 6, TILE_SIZE, false, Image.FORMAT_RGBA8)
	_draw_resource_atlas(img)
	var tex := ImageTexture.create_from_image(img)
	source.texture = tex
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for i in range(6):
		source.create_tile(Vector2i(i, 0))
	ts.add_source(source, 0)
	resource_layer.tile_set = ts

func _draw_resource_atlas(img: Image) -> void:
	var px := func(x: int, y: int, c: Color) -> void:
		if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
			img.set_pixel(x, y, c)
	_draw_berry_tile(img, px, 0)
	_draw_tree_tile(img, px, 1)
	_draw_stone_tile(img, px, 2)
	_draw_fiber_tile(img, px, 3)
	_draw_mushroom_tile(img, px, 4)
	_draw_iron_ore_tile(img, px, 5)

func _draw_berry_tile(img: Image, px: Callable, index: int) -> void:
	var ox: int = index * TILE_SIZE + 2
	var g := Color(0.25, 0.55, 0.2)
	var r := Color(0.85, 0.15, 0.25)
	var dr := Color(0.6, 0.1, 0.2)
	for x in range(2, 10):
		for y in range(4, 10):
			px.call(ox + x, y + 2, g)
	for y in range(2, 5):
		for x in range(3, 9):
			px.call(ox + x, y + 2, g)
	px.call(ox + 3, 5, r); px.call(ox + 4, 5, r)
	px.call(ox + 6, 6, r); px.call(ox + 7, 6, r)
	px.call(ox + 4, 8, r); px.call(ox + 5, 8, r)
	px.call(ox + 7, 9, r); px.call(ox + 8, 9, r)
	px.call(ox + 3, 10, dr); px.call(ox + 6, 7, dr)

func _draw_tree_tile(img: Image, px: Callable, index: int) -> void:
	var ox: int = index * TILE_SIZE + 2
	var trunk := Color(0.45, 0.28, 0.12)
	var leaf := Color(0.2, 0.6, 0.15)
	var dl := Color(0.15, 0.45, 0.1)
	for y in range(10, 14):
		px.call(ox + 5, y, trunk); px.call(ox + 6, y, trunk)
	for x in range(2, 10):
		for y in range(3, 10):
			var dist: float = Vector2(x - 5.5, y - 6.0).length()
			if dist < 4.0:
				px.call(ox + x, y, leaf if (x + y) % 3 != 0 else dl)

func _draw_stone_tile(img: Image, px: Callable, index: int) -> void:
	var ox: int = index * TILE_SIZE + 2
	var c1 := Color(0.6, 0.6, 0.6)
	var hi := Color(0.75, 0.75, 0.75)
	var c2 := Color(0.5, 0.5, 0.52)
	for x in range(2, 10):
		for y in range(6, 12):
			px.call(ox + x, y, c1)
	for x in range(3, 9):
		px.call(ox + x, 5, c1)
	px.call(ox + 3, 6, hi); px.call(ox + 4, 6, hi); px.call(ox + 4, 7, hi)
	px.call(ox + 7, 8, c2); px.call(ox + 8, 9, c2)

func _draw_fiber_tile(img: Image, px: Callable, index: int) -> void:
	var ox: int = index * TILE_SIZE + 2
	var g1 := Color(0.5, 0.75, 0.25)
	var g2 := Color(0.4, 0.65, 0.2)
	var g3 := Color(0.55, 0.8, 0.3)
	for i in [2, 4, 6, 8]:
		for y in range(4, 13):
			var c: Color = g1 if i % 4 == 0 else g2
			if y < 6:
				c = g3
			px.call(ox + i, y, c)
			if y > 5:
				px.call(ox + i + 1, y, c)

func _draw_mushroom_tile(img: Image, px: Callable, index: int) -> void:
	var ox: int = index * TILE_SIZE + 2
	var cap := Color(0.7, 0.35, 0.2)
	var dc := Color(0.55, 0.25, 0.15)
	var stem := Color(0.9, 0.85, 0.75)
	var dot := Color(0.95, 0.9, 0.7)
	for x in range(2, 10):
		for y in range(4, 8):
			var dist: float = abs(x - 5.5)
			if dist < 4.5 - y * 0.3:
				px.call(ox + x, y, cap if (x + y) % 3 != 0 else dc)
	px.call(ox + 4, 5, dot); px.call(ox + 7, 6, dot)
	for y in range(8, 13):
		px.call(ox + 5, y, stem); px.call(ox + 6, y, stem)

func _draw_iron_ore_tile(img: Image, px: Callable, index: int) -> void:
	var ox: int = index * TILE_SIZE + 2
	var rock := Color(0.4, 0.38, 0.35)
	var dr := Color(0.33, 0.3, 0.28)
	var ore := Color(0.75, 0.5, 0.25)
	for x in range(2, 10):
		for y in range(5, 12):
			px.call(ox + x, y, rock)
	for x in range(3, 9):
		px.call(ox + x, 4, rock)
	px.call(ox + 3, 6, ore); px.call(ox + 4, 6, ore)
	px.call(ox + 7, 8, ore); px.call(ox + 6, 8, ore)
	px.call(ox + 4, 10, ore); px.call(ox + 5, 9, ore)
	px.call(ox + 8, 7, dr); px.call(ox + 5, 11, dr)

func _setup_fog_tileset() -> void:
	var fog: TileMapLayer = get_node_or_null("FogOfWar") as TileMapLayer
	if not fog:
		return
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var source := TileSetAtlasSource.new()
	var img := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 1))
	var tex := ImageTexture.create_from_image(img)
	source.texture = tex
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	source.create_tile(Vector2i(0, 0))
	ts.add_source(source, 0)
	fog.tile_set = ts

func generate_world(seed_value: int = -1) -> void:
	if seed_value < 0:
		seed_value = randi()
	world_generator.world_seed = seed_value
	world_generator._setup_noise()
	for cx in range(-1, 2):
		for cy in range(-1, 2):
			_generate_chunk(Vector2i(cx, cy))
	var village_tile: Vector2i = world_generator.find_village_center(terrain_data)
	world_generator.ensure_minimum_resources(terrain_data, village_tile)
	for cx in range(-1, 2):
		for cy in range(-1, 2):
			_refresh_resource_layer_for_chunk(Vector2i(cx, cy))
			_register_resources_for_chunk(Vector2i(cx, cy))
	GameManager.village_center = Vector2(village_tile) * TILE_SIZE + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
	BuildingManager.set_camp(GameManager.village_center)
	_place_camp_marker()
	_update_camera_bounds()

func _generate_chunk(chunk_pos: Vector2i) -> void:
	if _generated_chunks.has(chunk_pos):
		return
	_generated_chunks[chunk_pos] = true
	var chunk_tiles: Dictionary = world_generator.generate_chunk(chunk_pos)
	terrain_data.merge(chunk_tiles)
	_apply_chunk_to_tilemap(chunk_pos)
	_refresh_resource_layer_for_chunk(chunk_pos)
	_register_resources_for_chunk(chunk_pos)
	var fog: TileMapLayer = get_node_or_null("FogOfWar") as TileMapLayer
	if fog and fog.has_method("add_fog_for_chunk"):
		fog.add_fog_for_chunk(chunk_pos, CHUNK_SIZE)
	_update_camera_bounds()

func request_chunk_at(tile_pos: Vector2i) -> void:
	var chunk_pos := Vector2i(
		floori(float(tile_pos.x) / CHUNK_SIZE),
		floori(float(tile_pos.y) / CHUNK_SIZE)
	)
	if _generated_chunks.has(chunk_pos):
		return
	_generate_chunk(chunk_pos)

func is_chunk_generated(chunk_pos: Vector2i) -> bool:
	return _generated_chunks.has(chunk_pos)

func _apply_chunk_to_tilemap(chunk_pos: Vector2i) -> void:
	var origin := chunk_pos * CHUNK_SIZE
	for lx in range(CHUNK_SIZE):
		for ly in range(CHUNK_SIZE):
			var tile_pos := Vector2i(origin.x + lx, origin.y + ly)
			if terrain_data.has(tile_pos):
				var terrain: int = terrain_data[tile_pos]["terrain"]
				tile_map.set_cell(tile_pos, 0, Vector2i(terrain, 0))

func _refresh_resource_layer_for_chunk(chunk_pos: Vector2i) -> void:
	var origin := chunk_pos * CHUNK_SIZE
	for lx in range(CHUNK_SIZE):
		for ly in range(CHUNK_SIZE):
			var tile_pos := Vector2i(origin.x + lx, origin.y + ly)
			_update_resource_visual(tile_pos)

func _register_resources_for_chunk(chunk_pos: Vector2i) -> void:
	var origin := chunk_pos * CHUNK_SIZE
	for lx in range(CHUNK_SIZE):
		for ly in range(CHUNK_SIZE):
			var tile_pos := Vector2i(origin.x + lx, origin.y + ly)
			if terrain_data.has(tile_pos):
				var data: Dictionary = terrain_data[tile_pos]
				if data["resource_type"] != "" and data["resource_amount"] > 0:
					ResourceManager.register_tile(tile_pos, data["resource_type"], data["resource_category"])

func _update_resource_visual(tile_pos: Vector2i) -> void:
	if not terrain_data.has(tile_pos):
		return
	var data: Dictionary = terrain_data[tile_pos]
	if data["resource_type"] == "" or data["resource_amount"] <= 0:
		resource_layer.erase_cell(tile_pos)
		return
	var atlas_x: int = _get_resource_atlas_index(data["resource_type"])
	if atlas_x >= 0:
		resource_layer.set_cell(tile_pos, 0, Vector2i(atlas_x, 0))

func _get_resource_atlas_index(resource_type: String) -> int:
	match resource_type:
		"berry": return 0
		"wood": return 1
		"stone": return 2
		"fiber": return 3
		"mushroom": return 4
		"iron_ore": return 5
		_: return -1

func _place_camp_marker() -> void:
	var marker := Sprite2D.new()
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for x in range(16):
		for y in range(16):
			var dist: float = Vector2(x - 8, y - 8).length()
			if dist < 3.0:
				img.set_pixel(x, y, Color(1.0, 0.6, 0.1))
			elif dist < 5.0:
				img.set_pixel(x, y, Color(0.6, 0.3, 0.1))
			elif (x == 7 or x == 8) and y >= 8 and y <= 14:
				img.set_pixel(x, y, Color(0.4, 0.25, 0.1))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	marker.texture = ImageTexture.create_from_image(img)
	marker.global_position = GameManager.village_center
	marker.z_index = 5
	add_child(marker)

func _update_camera_bounds() -> void:
	var min_x := 0
	var min_y := 0
	var max_x := 0
	var max_y := 0
	var first := true
	for chunk_pos in _generated_chunks:
		var origin: Vector2i = Vector2i(chunk_pos) * CHUNK_SIZE
		var end: Vector2i = origin + Vector2i(CHUNK_SIZE, CHUNK_SIZE)
		if first:
			min_x = origin.x
			min_y = origin.y
			max_x = end.x
			max_y = end.y
			first = false
		else:
			min_x = mini(min_x, origin.x)
			min_y = mini(min_y, origin.y)
			max_x = maxi(max_x, end.x)
			max_y = maxi(max_y, end.y)
	_map_bounds = Rect2(
		min_x * TILE_SIZE, min_y * TILE_SIZE,
		(max_x - min_x) * TILE_SIZE, (max_y - min_y) * TILE_SIZE
	)
	var camera := get_parent().get_node_or_null("Camera2D") as Camera2D
	if camera and camera.has_method("set_map_bounds"):
		camera.set_map_bounds(_map_bounds)

func _process(delta: float) -> void:
	if GameManager.game_speed == 0.0:
		return
	var scaled_delta: float = delta * GameManager.game_speed
	_update_resource_regen(scaled_delta)
	_pop_timer += scaled_delta
	if _pop_timer >= POP_CHECK_INTERVAL:
		_pop_timer = 0.0
		_try_spawn_villager()

func _update_resource_regen(scaled_delta: float) -> void:
	var regenerated: Array[Vector2i] = []
	for tile_pos in _depleted_tiles:
		if not terrain_data.has(tile_pos):
			regenerated.append(tile_pos)
			continue
		var data: Dictionary = terrain_data[tile_pos]
		if not data["regenerate"]:
			regenerated.append(tile_pos)
			continue
		if data["regen_waiting"]:
			data["regen_timer"] -= scaled_delta
			if data["regen_timer"] <= 0.0:
				data["regen_waiting"] = false
		else:
			if not data.has("regen_accumulator"):
				data["regen_accumulator"] = 0.0
			data["regen_accumulator"] += data["regen_rate"] * scaled_delta
			var add: int = int(data["regen_accumulator"])
			if add > 0:
				data["regen_accumulator"] -= add
				data["resource_amount"] += add
			if data["resource_amount"] >= data["resource_max"]:
				data["resource_amount"] = data["resource_max"]
				regenerated.append(tile_pos)
				_update_resource_visual(tile_pos)
				ResourceManager.register_tile(tile_pos, data["resource_type"], data["resource_category"])
	for tile_pos in regenerated:
		_depleted_tiles.erase(tile_pos)

# --- Tile query API ---

func is_tile_walkable(tile_pos: Vector2i) -> bool:
	if not terrain_data.has(tile_pos):
		return false
	var terrain: int = terrain_data[tile_pos]["terrain"]
	return WorldGenerator.is_walkable(terrain)

func is_tile_buildable(tile_pos: Vector2i) -> bool:
	if not is_tile_walkable(tile_pos):
		return false
	var terrain: int = terrain_data[tile_pos]["terrain"]
	return terrain == Terrain.GRASS or terrain == Terrain.SAND

func get_terrain_at(tile_pos: Vector2i) -> int:
	if not terrain_data.has(tile_pos):
		return -1
	return terrain_data[tile_pos]["terrain"]

func is_adjacent_to_water(tile_pos: Vector2i) -> bool:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d in dirs:
		var neighbor: Vector2i = tile_pos + d
		if terrain_data.has(neighbor):
			var t: int = terrain_data[neighbor]["terrain"]
			if t == Terrain.DEEP_WATER or t == Terrain.SHALLOW_WATER:
				return true
	return false

func get_move_cost(tile_pos: Vector2i) -> float:
	var terrain: int = get_terrain_at(tile_pos)
	match terrain:
		Terrain.FOREST: return 2.0
		Terrain.ROCK: return 2.0
		Terrain.SAND: return 1.2
		_: return 1.0

# --- Tile resource API ---

func gather_tile(tile_pos: Vector2i) -> Dictionary:
	if not terrain_data.has(tile_pos):
		return {}
	var data: Dictionary = terrain_data[tile_pos]
	if data["resource_type"] == "" or data["resource_amount"] <= 0:
		return {}
	var amount: int = mini(data["gather_amount"], data["resource_amount"])
	data["resource_amount"] -= amount
	if data["resource_amount"] <= 0:
		data["resource_amount"] = 0
		data["regen_waiting"] = true
		data["regen_timer"] = data["regen_delay"]
		_depleted_tiles.append(tile_pos)
		_update_resource_visual(tile_pos)
		ResourceManager.unregister_tile(tile_pos)
	return {"type": data["resource_type"], "amount": amount}

func get_tile_resource(tile_pos: Vector2i) -> Dictionary:
	if not terrain_data.has(tile_pos):
		return {}
	var data: Dictionary = terrain_data[tile_pos]
	if data["resource_type"] == "":
		return {}
	return {
		"type": data["resource_type"],
		"category": data["resource_category"],
		"amount": data["resource_amount"],
		"max": data["resource_max"],
		"gather_time": data["gather_time"],
	}

func is_tile_depleted(tile_pos: Vector2i) -> bool:
	if not terrain_data.has(tile_pos):
		return true
	var data: Dictionary = terrain_data[tile_pos]
	return data["resource_type"] == "" or data["resource_amount"] <= 0

func get_tile_gather_time(tile_pos: Vector2i) -> float:
	if not terrain_data.has(tile_pos):
		return 2.0
	return terrain_data[tile_pos].get("gather_time", 2.0)

func get_tile_resource_type(tile_pos: Vector2i) -> String:
	if not terrain_data.has(tile_pos):
		return ""
	return terrain_data[tile_pos].get("resource_type", "")

# --- Population ---

func _get_population_cap() -> int:
	var shelters: Array[Node] = BuildingManager.get_buildings_of_type("shelter")
	return mini(shelters.size() * POP_PER_SHELTER, POP_HARD_CAP)

func _try_spawn_villager() -> void:
	var current_pop: int = villagers.get_child_count()
	var cap: int = _get_population_cap()
	if current_pop >= cap or cap == 0:
		return
	var avg_hunger := 0.0
	for child in villagers.get_children():
		if child is Villager:
			avg_hunger += child.needs.hunger
	avg_hunger /= maxf(current_pop, 1.0)
	if avg_hunger > POP_MIN_AVG_HUNGER:
		return
	var villager_scene := preload("res://scenes/entities/villager.tscn")
	var v: Node = villager_scene.instantiate()
	v.villager_name = Villager.generate_random_name()
	var camp: Vector2 = BuildingManager.get_camp()
	v.global_position = camp + Vector2(randf_range(-20, 20), randf_range(-20, 20))
	villagers.add_child(v)

func _spawn_initial_villagers() -> void:
	var villager_scene := preload("res://scenes/entities/villager.tscn")
	for i in range(3):
		var v: Node = villager_scene.instantiate()
		v.villager_name = Villager.generate_random_name()
		var offset := Vector2(randf_range(-20, 20), randf_range(-20, 20))
		v.global_position = GameManager.village_center + offset
		villagers.add_child(v)

func _on_day_changed(day: int) -> void:
	var summary := "Day %d:" % day
	var building_types: Array[String] = []
	for b in BuildingManager._buildings:
		if is_instance_valid(b) and b.is_completed:
			building_types.append(b.building_type)
	if building_types.is_empty():
		summary += " No buildings."
	else:
		summary += " Buildings: %s." % ", ".join(building_types)
	summary += " Tech: %d/%d." % [TechTree.get_unlocked_count(), TechTree.get_all_techs().size()]
	for v in villagers.get_children():
		if v is Villager:
			var inv_items: Array[String] = []
			var items: Dictionary = v.inventory.get_all_items()
			for type in items:
				inv_items.append("%s:%d" % [type, items[type]])
			var inv_str := "empty" if inv_items.is_empty() else ", ".join(inv_items)
			summary += " %s[%s inv:%s]" % [v.villager_name, v.current_action_name, inv_str]
	EventLog.add("Village", "status", summary)
