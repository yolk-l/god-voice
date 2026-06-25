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
	var all_techs: Dictionary = TechTree.get_all_techs()
	var researchable: Array = TechTree.get_researchable_techs()
	var researchable_ids: Array = []
	for t in researchable:
		researchable_ids.append(t["id"])

	var sections: Array[String] = []

	var unlocked_lines: Array[String] = []
	for id in all_techs:
		if TechTree.is_unlocked(id):
			var tech: Dictionary = all_techs[id]
			unlocked_lines.append("[OK] %s\n      %s" % [tech["display_name"], tech["description"]])
	if not unlocked_lines.is_empty():
		sections.append("-- Unlocked --\n" + "\n".join(unlocked_lines))

	var available_lines: Array[String] = []
	for id in researchable_ids:
		var tech: Dictionary = all_techs[id]
		var cost_text := _format_cost(tech["research_cost"])
		available_lines.append("[>>] %s\n      %s\n      Cost: %s" % [tech["display_name"], tech["description"], cost_text])
	if not available_lines.is_empty():
		sections.append("-- Available --\n" + "\n".join(available_lines))

	var locked_lines: Array[String] = []
	for id in all_techs:
		if TechTree.is_unlocked(id) or id in researchable_ids:
			continue
		var tech: Dictionary = all_techs[id]
		var prereq_text := ""
		if not tech["prerequisites"].is_empty():
			var names: Array = []
			for p in tech["prerequisites"]:
				var p_data: Dictionary = TechTree.get_tech_data(p)
				names.append(p_data.get("display_name", p))
			prereq_text = "\n      Needs: %s" % ", ".join(names)
		var cost_text := _format_cost(tech["research_cost"])
		locked_lines.append("[--] %s\n      %s%s\n      Cost: %s" % [tech["display_name"], tech["description"], prereq_text, cost_text])
	if not locked_lines.is_empty():
		sections.append("-- Locked --\n" + "\n".join(locked_lines))

	content_label.text = "\n\n".join(sections) if not sections.is_empty() else "(no technologies)"

func _format_cost(cost: Dictionary) -> String:
	var parts: Array = []
	for type in cost:
		parts.append("%s x%d" % [_display_name(type), cost[type]])
	return ", ".join(parts)

func _display_name(type: String) -> String:
	match type:
		"wood": return "Wood"
		"stone": return "Stone"
		"fiber": return "Fiber"
		"iron_ore": return "Iron Ore"
		"iron_ingot": return "Iron Ingot"
		_: return type
