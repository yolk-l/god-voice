extends Control

@onready var day_label: Label = $DayLabel
@onready var population_label: Label = $PopulationLabel
@onready var tech_label: Label = $TechLabel
@onready var speed_label: Label = $SpeedLabel
@onready var time_bar: ProgressBar = $TimeBar

func _ready() -> void:
	GameManager.day_changed.connect(_on_day_changed)
	GameManager.game_speed_changed.connect(_on_speed_changed)
	_update_all()

func _process(_delta: float) -> void:
	if time_bar:
		time_bar.value = GameManager.time_of_day * 100.0
	_update_population()

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
		tech_label.text = "Tech: %d" % TechTree.get_unlocked_count()
