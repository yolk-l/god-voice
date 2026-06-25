extends Node

signal tech_unlocked(tech_id: String)

var _techs: Dictionary = {}  # {id: TechData}
var _unlocked: Dictionary = {}  # {id: true}
var _researching: String = ""
var _research_progress: float = 0.0

func _ready() -> void:
	_init_techs()

func _init_techs() -> void:
	_register_tech("stone_axe", "石斧", "解锁制作石斧 (伐木+50%)", [], {"wood": 3, "stone": 2}, 15.0, "recipe", {"stone_axe": true})
	_register_tech("stone_pickaxe", "石镐", "解锁制作石镐 (采矿+50%)", [], {"wood": 3, "stone": 2}, 15.0, "recipe", {"stone_pickaxe": true})
	_register_tech("cooking", "烹饪", "篝火可烹饪肉类", [], {"wood": 3, "stone": 1}, 10.0, "unlock", {"cooking": true})
	_register_tech("farming", "农耕", "解锁建造农田", [], {"wood": 5, "fiber": 3}, 20.0, "building", {"farm": true})
	_register_tech("weaving", "编织", "解锁绳索配方和织布机", [], {"fiber": 5}, 12.0, "building", {"loom": true})
	_register_tech("smelting", "冶炼", "解锁冶铁台", ["stone_pickaxe"], {"stone": 5, "wood": 3}, 25.0, "building", {"smelter": true})
	_register_tech("improved_tools", "改良工具", "所有采集效率+100%", ["smelting"], {"iron_ingot": 2}, 30.0, "buff", {"gather_efficiency_all": 2.0})
	_register_tech("irrigation", "灌溉", "农田产出翻倍", ["farming"], {"wood": 5, "stone": 3}, 25.0, "buff", {"farm_output": 2.0})

func _register_tech(id: String, display_name: String, description: String, prerequisites: Array, cost: Dictionary, time: float, unlock_type: String, unlock_data: Dictionary) -> void:
	_techs[id] = {
		"id": id,
		"display_name": display_name,
		"description": description,
		"prerequisites": prerequisites,
		"research_cost": cost,
		"research_time": time,
		"unlock_type": unlock_type,
		"unlock_data": unlock_data
	}

func is_unlocked(tech_id: String) -> bool:
	return _unlocked.has(tech_id)

func can_research(tech_id: String) -> bool:
	if is_unlocked(tech_id):
		return false
	if not _techs.has(tech_id):
		return false
	var tech: Dictionary = _techs[tech_id]
	for prereq in tech["prerequisites"]:
		if not is_unlocked(prereq):
			return false
	return true

func get_researchable_techs() -> Array:
	var result: Array = []
	for id in _techs:
		if can_research(id):
			result.append(_techs[id])
	return result

func get_research_cost(tech_id: String) -> Dictionary:
	if _techs.has(tech_id):
		return _techs[tech_id]["research_cost"]
	return {}

func get_research_time(tech_id: String) -> float:
	if _techs.has(tech_id):
		return _techs[tech_id]["research_time"]
	return 0.0

func unlock_tech(tech_id: String) -> void:
	if not _techs.has(tech_id):
		return
	_unlocked[tech_id] = true
	tech_unlocked.emit(tech_id)

func get_tech_data(tech_id: String) -> Dictionary:
	if _techs.has(tech_id):
		return _techs[tech_id]
	return {}

func get_all_techs() -> Dictionary:
	return _techs

func get_unlocked_count() -> int:
	return _unlocked.size()

func get_buff(buff_key: String, default_value: float = 1.0) -> float:
	for id in _unlocked:
		var tech: Dictionary = _techs[id]
		if tech["unlock_type"] == "buff" and tech["unlock_data"].has(buff_key):
			return tech["unlock_data"][buff_key]
	return default_value

func has_recipe(recipe_name: String) -> bool:
	for id in _unlocked:
		var tech: Dictionary = _techs[id]
		if tech["unlock_type"] == "recipe" and tech["unlock_data"].has(recipe_name):
			return true
	return false

func is_building_unlocked(building_type: String) -> bool:
	for id in _unlocked:
		var tech: Dictionary = _techs[id]
		if tech["unlock_type"] == "building" and tech["unlock_data"].has(building_type):
			return true
	return false

func is_feature_unlocked(feature: String) -> bool:
	for id in _unlocked:
		var tech: Dictionary = _techs[id]
		if tech["unlock_type"] == "unlock" and tech["unlock_data"].has(feature):
			return true
	return false
