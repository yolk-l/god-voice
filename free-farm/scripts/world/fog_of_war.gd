extends TileMapLayer

const MAP_WIDTH := 120
const MAP_HEIGHT := 120

var _revealed: Dictionary = {}  # {Vector2i: true}

func _ready() -> void:
	_init_fog()

func _init_fog() -> void:
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			set_cell(Vector2i(x, y), 0, Vector2i(0, 0))

func _process(_delta: float) -> void:
	_update_fog()

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
					_clear_fog_tile(tile)

func _clear_fog_tile(tile: Vector2i) -> void:
	if tile.x >= 0 and tile.x < MAP_WIDTH and tile.y >= 0 and tile.y < MAP_HEIGHT:
		erase_cell(tile)
