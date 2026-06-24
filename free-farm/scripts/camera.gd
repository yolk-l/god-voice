extends Camera2D

const MOVE_SPEED := 400.0
const ZOOM_STEP := 0.1
const ZOOM_MIN := 0.5
const ZOOM_MAX := 3.0
const EDGE_MARGIN := 32.0

var _dragging := false
var _drag_start := Vector2.ZERO
var _map_bounds := Rect2(0, 0, 1280, 1280)
var _following: Node = null

func _ready() -> void:
	zoom = Vector2(1.5, 1.5)

func set_map_bounds(bounds: Rect2) -> void:
	_map_bounds = bounds
	limit_left = int(bounds.position.x - EDGE_MARGIN)
	limit_top = int(bounds.position.y - EDGE_MARGIN)
	limit_right = int(bounds.end.x + EDGE_MARGIN)
	limit_bottom = int(bounds.end.y + EDGE_MARGIN)

func follow_target(target: Node) -> void:
	_following = target

func stop_following() -> void:
	_following = null

func center_on(pos: Vector2) -> void:
	_following = null
	global_position = pos

func _process(delta: float) -> void:
	if _following and is_instance_valid(_following):
		global_position = _following.global_position
		return

	var move_dir := Vector2.ZERO
	if Input.is_action_pressed("camera_up"):
		move_dir.y -= 1
	if Input.is_action_pressed("camera_down"):
		move_dir.y += 1
	if Input.is_action_pressed("camera_left"):
		move_dir.x -= 1
	if Input.is_action_pressed("camera_right"):
		move_dir.x += 1

	if move_dir != Vector2.ZERO:
		_following = null
		global_position += move_dir.normalized() * MOVE_SPEED * delta / zoom.x

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event.is_action_pressed("camera_center"):
		center_on(BuildingManager.get_village_center())

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed
			_drag_start = event.position
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_zoom_at(ZOOM_STEP, event.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_zoom_at(-ZOOM_STEP, event.position)

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _dragging:
		_following = null
		global_position -= event.relative / zoom

func _zoom_at(step: float, mouse_pos: Vector2) -> void:
	var old_zoom := zoom
	var new_zoom_val := clampf(zoom.x + step, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(new_zoom_val, new_zoom_val)
	var viewport_size := get_viewport_rect().size
	var mouse_offset := mouse_pos - viewport_size / 2.0
	global_position += mouse_offset * (1.0 / old_zoom.x - 1.0 / zoom.x)
