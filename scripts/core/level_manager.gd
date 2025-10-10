# scripts/core/level_manager.gd
# A service locator for providing global access to the active level.
extends Node

# REMOVE the current_level variable
# var current_level: Node = null

# Called by a level scene when it becomes ready.
func register_active_level(level: Node) -> void:
	# Add the level to the SceneManager's authoritative dictionary.
	if not Scene.active_levels.has(level.scene_file_path):
		Scene.active_levels[level.scene_file_path] = level

# Any script can call this to get a reference to a SPECIFIC loaded level.
func get_level(scene_path: String) -> Node:
	if not Scene.active_levels.has(scene_path):
		push_error("LevelManager: Attempted to get level '%s', but it is not loaded!" % scene_path)
		return null
	return Scene.active_levels[scene_path]
