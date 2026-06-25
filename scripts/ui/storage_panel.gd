extends PanelContainer

@onready var content_label: Label = $VBox/ContentLabel

func _ready() -> void:
	visible = false

func toggle() -> void:
	visible = not visible

func _process(_delta: float) -> void:
	if not visible:
		return
	_update_display()

func _update_display() -> void:
	var all_items: Dictionary = {}

	var chest_count := 0
	var buildings: Array[Node] = BuildingManager.get_buildings_of_type("chest")
	for b in buildings:
		if not is_instance_valid(b):
			continue
		chest_count += 1
		var items: Dictionary = b.get_all_items()
		for type in items:
			if not all_items.has(type):
				all_items[type] = 0
			all_items[type] += items[type]

	var world: Node = get_tree().current_scene.get_node_or_null("World")
	var villager_count := 0
	if world:
		var villagers_node: Node = world.get_node_or_null("Villagers")
		if villagers_node:
			for v in villagers_node.get_children():
				if v is Villager:
					villager_count += 1
					var inv: Dictionary = v.inventory.get_all_items()
					for type in inv:
						if not all_items.has(type):
							all_items[type] = 0
						all_items[type] += inv[type]

	var text := "Villagers: %d    Chests: %d\n" % [villager_count, chest_count]

	if all_items.is_empty():
		text += "\n(empty)"
	else:
		var food_lines: Array[String] = []
		var mat_lines: Array[String] = []
		var other_lines: Array[String] = []
		for type in all_items:
			var entry := "  %s: %d" % [_display_name(type), all_items[type]]
			if type in ["berry", "mushroom", "raw_meat", "cooked_meat", "cooked_fish"]:
				food_lines.append(entry)
			elif type in ["wood", "stone", "fiber", "iron_ore"]:
				mat_lines.append(entry)
			else:
				other_lines.append(entry)

		if not food_lines.is_empty():
			text += "\n-- Food --\n" + "\n".join(food_lines)
		if not mat_lines.is_empty():
			text += "\n-- Materials --\n" + "\n".join(mat_lines)
		if not other_lines.is_empty():
			text += "\n-- Products --\n" + "\n".join(other_lines)

	content_label.text = text

func _display_name(type: String) -> String:
	match type:
		"berry": return "Berry"
		"mushroom": return "Mushroom"
		"raw_meat": return "Raw Meat"
		"cooked_meat": return "Cooked Meat"
		"cooked_fish": return "Cooked Fish"
		"wood": return "Wood"
		"stone": return "Stone"
		"fiber": return "Fiber"
		"iron_ore": return "Iron Ore"
		"iron_ingot": return "Iron Ingot"
		"rope": return "Rope"
		"cloth": return "Cloth"
		"stone_axe": return "Stone Axe"
		"stone_pickaxe": return "Stone Pickaxe"
		_: return type
