extends Action

var _idle_timer: float = 0.0
var _wander_target: Vector2 = Vector2.ZERO
var _wandering: bool = false
const IDLE_DURATION := 3.0

func get_action_name() -> String:
	return "idle"

func can_execute(villager: Villager, world: Node) -> bool:
	return true

func calculate_utility(villager: Villager, world: Node) -> float:
	return 0.05

func start(villager: Villager, world: Node) -> void:
	_completed = false
	_idle_timer = 0.0
	_wandering = false
	var camp: Vector2 = BuildingManager.get_camp()
	var dist_to_camp: float = villager.global_position.distance_to(camp)
	if dist_to_camp > 80.0:
		_wander_target = camp + Vector2(randf_range(-32, 32), randf_range(-32, 32))
		villager.navigate_to(_wander_target)
		_wandering = true
	elif randf() > 0.5:
		var angle := randf() * TAU
		var dist := randf_range(16.0, 40.0)
		_wander_target = camp + Vector2(cos(angle), sin(angle)) * dist
		var tile: Vector2i = Vector2i(_wander_target / 16.0)
		if world.is_tile_walkable(tile):
			villager.navigate_to(_wander_target)
			_wandering = true

func tick(villager: Villager, world: Node, delta: float) -> void:
	_idle_timer += delta
	if _wandering and villager.has_reached_target():
		_wandering = false
	if _idle_timer >= IDLE_DURATION:
		_completed = true

func cancel(villager: Villager, world: Node) -> void:
	_completed = true
