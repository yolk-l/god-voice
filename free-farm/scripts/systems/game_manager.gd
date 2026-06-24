extends Node

signal time_of_day_changed(time: float)
signal day_changed(day: int)
signal time_phase_changed(phase: String)
signal game_speed_changed(speed: float)

enum TimePhase { DAY, DUSK, NIGHT }

const DAY_DURATION := 360.0  # 6 minutes real time per full cycle
const DAY_END := 0.5
const DUSK_END := 0.67
const SPEEDS := [0.0, 1.0, 2.0, 3.0]

var time_of_day := 0.0
var current_day := 1
var current_phase := TimePhase.DAY
var speed_index := 1
var game_speed := 1.0
var game_time := 0.0  # total elapsed game seconds
var village_center := Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if game_speed == 0.0:
		return
	var scaled_delta := delta * game_speed
	game_time += scaled_delta
	_advance_time(scaled_delta)

func _advance_time(delta: float) -> void:
	var prev_time := time_of_day
	time_of_day += delta / DAY_DURATION
	if time_of_day >= 1.0:
		time_of_day -= 1.0
		current_day += 1
		day_changed.emit(current_day)
	time_of_day_changed.emit(time_of_day)
	_check_phase_change()

func _check_phase_change() -> void:
	var new_phase: TimePhase
	if time_of_day < DAY_END:
		new_phase = TimePhase.DAY
	elif time_of_day < DUSK_END:
		new_phase = TimePhase.DUSK
	else:
		new_phase = TimePhase.NIGHT
	if new_phase != current_phase:
		current_phase = new_phase
		var phase_name := "day" if new_phase == TimePhase.DAY else ("dusk" if new_phase == TimePhase.DUSK else "night")
		time_phase_changed.emit(phase_name)

func is_night() -> bool:
	return current_phase == TimePhase.NIGHT

func is_dusk() -> bool:
	return current_phase == TimePhase.DUSK

func is_approaching_night() -> bool:
	return current_phase == TimePhase.DUSK or time_of_day > 0.45

func set_speed(index: int) -> void:
	speed_index = clampi(index, 0, SPEEDS.size() - 1)
	game_speed = SPEEDS[speed_index]
	game_speed_changed.emit(game_speed)

func toggle_pause() -> void:
	if game_speed == 0.0:
		set_speed(1)
	else:
		set_speed(0)

func speed_up() -> void:
	set_speed(speed_index + 1)

func speed_down() -> void:
	set_speed(speed_index - 1)

func get_game_minutes() -> float:
	return game_time / 60.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_pause"):
		toggle_pause()
	elif event.is_action_pressed("speed_up"):
		speed_up()
	elif event.is_action_pressed("speed_down"):
		speed_down()
