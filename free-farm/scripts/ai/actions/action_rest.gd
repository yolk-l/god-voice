extends Action

var _rest_timer: float = 0.0
var _going_home: bool = false
const REST_DURATION := 5.0

func get_action_name() -> String:
	return "rest"

func can_execute(villager: Villager, world: Node) -> bool:
	return villager.needs.stamina < 70.0

func calculate_utility(villager: Villager, world: Node) -> float:
	var base: float = (1.0 - villager.needs.stamina / 100.0) * 1.1
	if GameManager.is_dusk():
		base += 0.3
	var camp: Vector2 = BuildingManager.get_camp()
	var dist_from_camp: float = villager.global_position.distance_to(camp)
	if dist_from_camp > 160.0:
		base += 0.3
	return clampf(base, 0.0, 1.0)

func start(villager: Villager, world: Node) -> void:
	_completed = false
	_rest_timer = 0.0
	_going_home = false
	if villager.home and is_instance_valid(villager.home):
		villager.navigate_to(villager.home.global_position)
		_going_home = true
	else:
		# no home yet, go back to camp
		var camp: Vector2 = BuildingManager.get_camp()
		if villager.global_position.distance_to(camp) > 32.0:
			villager.navigate_to(camp)
			_going_home = true
	villager.needs.set_working(false)

func tick(villager: Villager, world: Node, delta: float) -> void:
	if _going_home and not villager.has_reached_target():
		return
	var sheltered := villager.home != null and is_instance_valid(villager.home)
	if _going_home and sheltered:
		sheltered = villager.global_position.distance_to(villager.home.global_position) < 20.0
	villager.needs.set_resting(true, sheltered)
	_rest_timer += delta
	if _rest_timer >= REST_DURATION or villager.needs.stamina >= 95.0:
		villager.needs.set_resting(false)
		_completed = true

func cancel(villager: Villager, world: Node) -> void:
	villager.needs.set_resting(false)
	_completed = true
