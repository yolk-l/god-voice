extends CanvasModulate

const COLOR_DAY := Color(1.0, 1.0, 1.0)
const COLOR_DUSK := Color(0.9, 0.7, 0.5)
const COLOR_NIGHT := Color(0.3, 0.3, 0.5)

func _ready() -> void:
	GameManager.time_of_day_changed.connect(_on_time_changed)
	color = COLOR_DAY

func _on_time_changed(time: float) -> void:
	if time < 0.45:
		color = COLOR_DAY
	elif time < 0.5:
		var t := (time - 0.45) / 0.05
		color = COLOR_DAY.lerp(COLOR_DUSK, t)
	elif time < 0.67:
		var t := (time - 0.5) / 0.17
		color = COLOR_DUSK.lerp(COLOR_NIGHT, t)
	elif time < 0.95:
		color = COLOR_NIGHT
	else:
		var t := (time - 0.95) / 0.05
		color = COLOR_NIGHT.lerp(COLOR_DAY, t)
