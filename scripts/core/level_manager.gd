# scripts/core/level_manager.gd
# A service locator for providing global access to the active level.
extends Node

var current_level: Node = null

# Called by a level scene when it becomes ready.
func register_active_level(level: Node) -> void:
	current_level = level

# Any script can call this to get a safe reference to the current level.
func get_current_level() -> Node:
	if not is_instance_valid(current_level):
		push_error("LevelManager: Attempted to get the level, but none is registered!")
	return current_level
