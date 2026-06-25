extends PanelContainer

@onready var content_label: Label = $Scroll/VBox/ContentLabel

func _ready() -> void:
	visible = false

func toggle() -> void:
	visible = not visible

func _process(_delta: float) -> void:
	if not visible:
		return
	_update_display()

func _update_display() -> void:
	var entries: Array[Dictionary] = EventLog.get_entries()
	if entries.is_empty():
		content_label.text = "(no events yet)"
		return

	var lines: Array[String] = []
	for i in range(entries.size() - 1, -1, -1):
		var e: Dictionary = entries[i]
		var time_str := _format_time(e["day"], e["time"])
		var icon := _get_icon(e["type"])
		lines.append("%s %s %s" % [time_str, icon, e["text"]])

	content_label.text = "\n".join(lines)

func _format_time(day: int, time: float) -> String:
	var hour: int = int(time * 24.0)
	return "[D%d %02d:00]" % [day, hour]

func _get_icon(event_type: String) -> String:
	match event_type:
		"build": return "#"
		"research": return "?"
		"craft": return "+"
		"death": return "X"
		"equip": return ">"
		_: return "-"
