extends Node

const MAX_ENTRIES := 200

var _entries: Array[Dictionary] = []

func add(villager_name: String, event_type: String, text: String) -> void:
	_entries.append({
		"day": GameManager.current_day,
		"time": GameManager.time_of_day,
		"villager": villager_name,
		"type": event_type,
		"text": text,
	})
	if _entries.size() > MAX_ENTRIES:
		_entries.remove_at(0)

func get_entries() -> Array[Dictionary]:
	return _entries

func get_recent(count: int) -> Array[Dictionary]:
	var start: int = maxi(0, _entries.size() - count)
	return _entries.slice(start)
