extends Node

var _utility_ai: UtilityAI
var _villager: Villager
var _world: Node

func _ready() -> void:
	_villager = get_parent() as Villager
	_world = get_tree().current_scene.get_node("World")
	_villager._ai = self

	_utility_ai = UtilityAI.new()
	_utility_ai.register_action(preload("res://scripts/ai/actions/action_eat.gd").new())
	_utility_ai.register_action(preload("res://scripts/ai/actions/action_gather_food.gd").new())
	_utility_ai.register_action(preload("res://scripts/ai/actions/action_gather_mat.gd").new())
	_utility_ai.register_action(preload("res://scripts/ai/actions/action_rest.gd").new())
	_utility_ai.register_action(preload("res://scripts/ai/actions/action_explore.gd").new())
	_utility_ai.register_action(preload("res://scripts/ai/actions/action_build.gd").new())
	_utility_ai.register_action(preload("res://scripts/ai/actions/action_craft.gd").new())
	_utility_ai.register_action(preload("res://scripts/ai/actions/action_deposit.gd").new())
	_utility_ai.register_action(preload("res://scripts/ai/actions/action_pickup.gd").new())
	_utility_ai.register_action(preload("res://scripts/ai/actions/action_research.gd").new())
	_utility_ai.register_action(preload("res://scripts/ai/actions/action_cook.gd").new())
	_utility_ai.register_action(preload("res://scripts/ai/actions/action_farm.gd").new())
	_utility_ai.register_action(preload("res://scripts/ai/actions/action_smelt.gd").new())
	_utility_ai.register_action(preload("res://scripts/ai/actions/action_weave.gd").new())
	_utility_ai.register_action(preload("res://scripts/ai/actions/action_idle.gd").new())

	$DecisionTimer.timeout.connect(_on_decision_timer)

func _process(delta: float) -> void:
	if GameManager.game_speed == 0.0:
		return
	if _utility_ai.current_action:
		_utility_ai.current_action.tick(_villager, _world, delta * GameManager.game_speed)
		if _utility_ai.current_action.is_completed():
			_utility_ai.current_action = null
			_evaluate()

func _on_decision_timer() -> void:
	_evaluate()

func _evaluate() -> void:
	var best_action = _utility_ai.select_action(_villager, _world)
	if best_action == null:
		return
	if best_action != _utility_ai.current_action:
		if _utility_ai.current_action:
			_utility_ai.current_action.cancel(_villager, _world)
		_utility_ai.current_action = best_action
		best_action.start(_villager, _world)
		_villager.current_action_name = best_action.get_action_name()

func force_reevaluate() -> void:
	_evaluate()

func get_scores() -> Dictionary:
	return _utility_ai.get_all_scores(_villager, _world)
