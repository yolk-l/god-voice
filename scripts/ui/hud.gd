extends Control

@onready var day_label: Label = $TopBar/DayLabel
@onready var population_label: Label = $TopBar/PopulationLabel
@onready var tech_label: Label = $TopBar/TechLabel
@onready var speed_label: Label = $TopBar/SpeedLabel
@onready var time_bar: ProgressBar = $TimeBar
@onready var hints_label: Label = $HintsLabel

var _tech_panel: Control = null
var _storage_panel: Control = null
var _history_panel: Control = null

func _ready() -> void:
	GameManager.day_changed.connect(_on_day_changed)
	GameManager.game_speed_changed.connect(_on_speed_changed)
	_tech_panel = get_parent().get_node_or_null("TechPanel")
	_storage_panel = get_parent().get_node_or_null("StoragePanel")
	_history_panel = get_parent().get_node_or_null("HistoryPanel")
	_update_all()

func _process(_delta: float) -> void:
	if time_bar:
		time_bar.value = GameManager.time_of_day * 100.0
	_update_population()
	_update_tech()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_T:
				_toggle_panel("tech")
				get_viewport().set_input_as_handled()
			KEY_I:
				_toggle_panel("storage")
				get_viewport().set_input_as_handled()
			KEY_H:
				_toggle_panel("history")
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				_close_all_panels()
				get_viewport().set_input_as_handled()

func _toggle_panel(panel_name: String) -> void:
	var panels := {"tech": _tech_panel, "storage": _storage_panel, "history": _history_panel}
	var target: Control = panels.get(panel_name)
	if not target:
		return
	var opening := not target.visible
	target.toggle()
	if opening:
		for name in panels:
			if name != panel_name and panels[name] and panels[name].visible:
				panels[name].visible = false

func _close_all_panels() -> void:
	for panel in [_tech_panel, _storage_panel, _history_panel]:
		if panel and panel.visible:
			panel.visible = false

func _on_day_changed(day: int) -> void:
	if day_label:
		day_label.text = "Day %d" % day

func _on_speed_changed(speed: float) -> void:
	if speed_label:
		if speed == 0.0:
			speed_label.text = "||"
		else:
			speed_label.text = "%dx" % int(speed)

func _update_all() -> void:
	_on_day_changed(GameManager.current_day)
	_on_speed_changed(GameManager.game_speed)
	_update_population()
	_update_tech()

func _update_population() -> void:
	if not population_label:
		return
	var world: Node = get_tree().current_scene.get_node_or_null("World")
	if world:
		var count := world.get_node("Villagers").get_child_count()
		population_label.text = "Pop: %d" % count

func _update_tech() -> void:
	if tech_label:
		tech_label.text = "Tech: %d/%d" % [TechTree.get_unlocked_count(), TechTree.get_all_techs().size()]
