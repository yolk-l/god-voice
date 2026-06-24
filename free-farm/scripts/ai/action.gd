class_name Action
extends RefCounted

var _completed: bool = false

func get_action_name() -> String:
	return "base"

func can_execute(villager: Villager, world: Node) -> bool:
	return true

func calculate_utility(villager: Villager, world: Node) -> float:
	return 0.0

func start(villager: Villager, world: Node) -> void:
	_completed = false

func tick(villager: Villager, world: Node, delta: float) -> void:
	_completed = true

func cancel(villager: Villager, world: Node) -> void:
	_completed = true

func is_completed() -> bool:
	return _completed
