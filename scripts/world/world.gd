extends Node2D

const TILE_SIZE := 16
const MAP_WIDTH := 120
const MAP_HEIGHT := 120

@onready var tile_map: TileMapLayer = $TileMap
@onready var resource_nodes: Node2D = $ResourceNodes
@onready var buildings: Node2D = $Buildings
@onready var villagers: Node2D = $Villagers

var world_generator: WorldGenerator
var terrain_data: Array = []  # 2D array [x][y] of terrain type

const POP_PER_SHELTER := 3
const POP_HARD_CAP := 15
const POP_CHECK_INTERVAL := 10.0
const POP_MIN_AVG_HUNGER := 40.0
var _pop_timer: float = 0.0

enum Terrain { DEEP_WATER, SHALLOW_WATER, SAND, GRASS, FOREST, ROCK, MOUNTAIN }

func _ready() -> void:
	_setup_tileset()
	world_generator = WorldGenerator.new()
	generate_world()
	_spawn_initial_villagers()
	_setup_fog_tileset()
	GameManager.day_changed.connect(_on_day_changed)

func _setup_tileset() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var source := TileSetAtlasSource.new()
	var img := Image.create(TILE_SIZE * 7, TILE_SIZE, false, Image.FORMAT_RGBA8)
	var colors := [
		Color(0.1, 0.15, 0.4),   # deep water
		Color(0.2, 0.4, 0.7),    # shallow water
		Color(0.85, 0.8, 0.55),  # sand
		Color(0.3, 0.7, 0.2),    # grass
		Color(0.1, 0.4, 0.15),   # forest
		Color(0.5, 0.5, 0.5),    # rock
		Color(0.3, 0.3, 0.35),   # mountain
	]
	for i in range(7):
		for x in range(TILE_SIZE):
			for y in range(TILE_SIZE):
				img.set_pixel(i * TILE_SIZE + x, y, colors[i])
	var tex := ImageTexture.create_from_image(img)
	source.texture = tex
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for i in range(7):
		source.create_tile(Vector2i(i, 0))
	ts.add_source(source, 0)
	tile_map.tile_set = ts

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
	terrain_data = world_generator.generate(MAP_WIDTH, MAP_HEIGHT)
	_apply_terrain_to_tilemap()
	_spawn_resources()
	_find_village_center()
	_setup_camera_bounds()

func _apply_terrain_to_tilemap() -> void:
	tile_map.clear()
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			var terrain: int = terrain_data[x][y]
			tile_map.set_cell(Vector2i(x, y), 0, _get_tile_atlas_coords(terrain))

func _get_tile_atlas_coords(terrain: int) -> Vector2i:
	match terrain:
		Terrain.DEEP_WATER: return Vector2i(0, 0)
		Terrain.SHALLOW_WATER: return Vector2i(1, 0)
		Terrain.SAND: return Vector2i(2, 0)
		Terrain.GRASS: return Vector2i(3, 0)
		Terrain.FOREST: return Vector2i(4, 0)
		Terrain.ROCK: return Vector2i(5, 0)
		Terrain.MOUNTAIN: return Vector2i(6, 0)
		_: return Vector2i(3, 0)

func _spawn_resources() -> void:
	for child in resource_nodes.get_children():
		child.queue_free()
	world_generator.spawn_resources(terrain_data, resource_nodes)

func _find_village_center() -> void:
	var center: Vector2i = world_generator.find_village_center(terrain_data, MAP_WIDTH, MAP_HEIGHT)
	GameManager.village_center = Vector2(center) * TILE_SIZE + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
	BuildingManager.set_camp(GameManager.village_center)
	_place_camp_marker()

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

func _setup_camera_bounds() -> void:
	var bounds := Rect2(0, 0, MAP_WIDTH * TILE_SIZE, MAP_HEIGHT * TILE_SIZE)
	var camera := get_parent().get_node("Camera2D") as Camera2D
	if camera and camera.has_method("set_map_bounds"):
		camera.set_map_bounds(bounds)
	camera.global_position = GameManager.village_center

func _process(delta: float) -> void:
	if GameManager.game_speed == 0.0:
		return
	_pop_timer += delta * GameManager.game_speed
	if _pop_timer >= POP_CHECK_INTERVAL:
		_pop_timer = 0.0
		_try_spawn_villager()

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

func is_tile_walkable(tile_pos: Vector2i) -> bool:
	if tile_pos.x < 0 or tile_pos.x >= MAP_WIDTH or tile_pos.y < 0 or tile_pos.y >= MAP_HEIGHT:
		return false
	var terrain: int = terrain_data[tile_pos.x][tile_pos.y]
	return terrain != Terrain.DEEP_WATER and terrain != Terrain.SHALLOW_WATER and terrain != Terrain.MOUNTAIN

func is_tile_buildable(tile_pos: Vector2i) -> bool:
	if not is_tile_walkable(tile_pos):
		return false
	var terrain: int = terrain_data[tile_pos.x][tile_pos.y]
	return terrain == Terrain.GRASS or terrain == Terrain.SAND

func get_terrain_at(tile_pos: Vector2i) -> int:
	if tile_pos.x < 0 or tile_pos.x >= MAP_WIDTH or tile_pos.y < 0 or tile_pos.y >= MAP_HEIGHT:
		return Terrain.MOUNTAIN
	return terrain_data[tile_pos.x][tile_pos.y]

func get_move_cost(tile_pos: Vector2i) -> float:
	var terrain: int = get_terrain_at(tile_pos)
	match terrain:
		Terrain.FOREST: return 2.0
		Terrain.ROCK: return 2.0
		Terrain.SAND: return 1.2
		_: return 1.0
