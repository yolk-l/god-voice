extends PanelContainer

@onready var title_label: Label = $VBox/TitleLabel
@onready var terrain_label: Label = $VBox/TerrainLabel
@onready var content_label: Label = $VBox/ContentLabel

var _tile_pos: Vector2i = Vector2i(-1, -1)
var _world: Node = null

func _ready() -> void:
	visible = false

func show_tile(tile: Vector2i, world: Node) -> void:
	_tile_pos = tile
	_world = world
	visible = true
	_update_display()

func hide_panel() -> void:
	visible = false
	_tile_pos = Vector2i(-1, -1)

func _update_display() -> void:
	if not _world:
		return
	title_label.text = "Tile (%d, %d)" % [_tile_pos.x, _tile_pos.y]
	terrain_label.text = _get_terrain_name()
	content_label.text = _get_tile_contents()

func _get_terrain_name() -> String:
	var terrain: int = _world.get_terrain_at(_tile_pos)
	match terrain:
		0: return "Deep Water"
		1: return "Shallow Water"
		2: return "Sand"
		3: return "Grass"
		4: return "Forest"
		5: return "Rock"
		_: return "Unknown"

func _get_tile_contents() -> String:
	var lines: Array[String] = []

	var res_info: Dictionary = _world.get_tile_resource(_tile_pos)
	if not res_info.is_empty():
		var status: String
		if res_info["amount"] <= 0:
			status = " (depleted)"
		else:
			status = " [%d/%d]" % [res_info["amount"], res_info["max"]]
		lines.append(_get_resource_display(res_info["type"]) + status)

	var buildings_node: Node = _world.get_node("Buildings")
	for b in buildings_node.get_children():
		if not is_instance_valid(b):
			continue
		var b_tile: Vector2i = Vector2i(b.global_position / 16.0)
		if b_tile == _tile_pos:
			lines.append(_get_building_display(b))

	if lines.is_empty():
		return "(empty)"
	return "\n".join(lines)

func _get_resource_display(type: String) -> String:
	match type:
		"berry": return "Berry Bush"
		"wood": return "Tree"
		"stone": return "Stone"
		"fiber": return "Fiber"
		"mushroom": return "Mushroom"
		"iron_ore": return "Iron Ore"
		_: return type

func _get_building_display(b: Node) -> String:
	var name: String = ""
	match b.building_type:
		"shelter": name = "Shelter"
		"campfire": name = "Campfire"
		"chest": name = "Chest"
		"workbench": name = "Workbench"
		"research_table": name = "Research Table"
		"farm": name = "Farm"
		"smelter": name = "Smelter"
		"loom": name = "Loom"
		"lumber_camp": name = "Lumber Camp"
		"quarry": name = "Quarry"
		"fishing_dock": name = "Fishing Dock"
		_: name = b.building_type
	if b.building_type == "chest":
		var items: Dictionary = b.get_all_items()
		if not items.is_empty():
			var parts: Array[String] = []
			for type in items:
				parts.append("%s:%d" % [type, items[type]])
			name += "\n  " + ", ".join(parts)
	if b.has_harvest():
		name += " (harvest ready)"
	return name
