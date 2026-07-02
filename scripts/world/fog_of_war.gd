extends TileMapLayer

var _revealed: Dictionary = {}  # {Vector2i: true}

func _process(_delta: float) -> void:
	_update_fog()

func add_fog_for_chunk(chunk_pos: Vector2i, chunk_size: int) -> void:
	var origin := chunk_pos * chunk_size
	for lx in range(chunk_size):
		for ly in range(chunk_size):
			var tile := Vector2i(origin.x + lx, origin.y + ly)
			if not _revealed.has(tile):
				set_cell(tile, 0, Vector2i(0, 0))

func _update_fog() -> void:
	var world: Node = get_parent()
	if not world:
		return
	var villagers_node: Node = world.get_node_or_null("Villagers")
	if not villagers_node:
		return
	for villager in villagers_node.get_children():
		if villager is Villager:
			for tile in villager.known_area:
				if not _revealed.has(tile):
					_revealed[tile] = true
					erase_cell(tile)
