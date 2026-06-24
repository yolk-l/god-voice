extends Node

var _villager_panel: Control = null
var _tile_info_panel: Control = null
var _camera: Camera2D = null
var _world: Node = null

func _ready() -> void:
	_villager_panel = get_tree().current_scene.get_node("UI/VillagerPanel")
	_tile_info_panel = get_tree().current_scene.get_node("UI/TileInfoPanel")
	_camera = get_tree().current_scene.get_node("Camera2D")
	_world = get_tree().current_scene.get_node("World")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var clicked_villager: Villager = _find_villager_at_mouse(event.position)
		if clicked_villager:
			_villager_panel.show_villager(clicked_villager)
			_tile_info_panel.hide_panel()
			_camera.follow_target(clicked_villager)
		else:
			_villager_panel.hide_panel()
			_camera.stop_following()
			var world_pos: Vector2 = _get_world_pos(event.position)
			var tile_pos: Vector2i = Vector2i(world_pos / 16.0)
			_tile_info_panel.show_tile(tile_pos, _world)

func _find_villager_at_mouse(screen_pos: Vector2) -> Villager:
	var world_pos: Vector2 = _get_world_pos(screen_pos)
	var world: Node = get_tree().current_scene.get_node("World")
	var villagers_node: Node = world.get_node("Villagers")
	var closest: Villager = null
	var closest_dist := 16.0
	for child in villagers_node.get_children():
		if child is Villager:
			var dist: float = world_pos.distance_to(child.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest = child
	return closest

func _get_world_pos(screen_pos: Vector2) -> Vector2:
	var viewport: Viewport = get_viewport()
	var canvas_transform: Transform2D = viewport.get_canvas_transform()
	return canvas_transform.affine_inverse() * screen_pos
