# scripts/core/scene_manager.gd
# A global singleton for managing scene transitions.
class_name SceneManager
extends Node

# ---Public API---
# Changes the active scene to the one at the given path.
# We now accept an optional target_spawn_position.
func change_scene(scene_path: String, target_spawn_position: Vector2 = Vector2.INF) -> void:
	if scene_path.is_empty():
		push_error("SceneManager: Attempted to change to an empty scene path.")
		return

	# This is Godot's built-in function to change scenes.
	# We've wrapped it in our manager so we can easily add fade-out/fade-in
	# transitions here later without changing any other code.
	
	# Tell the GameManager to grab the player's data before we leave.
	GameManager.carry_player_data()
	
	# If a spawn position was provided, store it in the GameManager.
	if target_spawn_position != Vector2.INF:
		GameManager.player_data_on_transition.target_spawn_position = target_spawn_position
		
	# defer the call to a safe time at the end of the current physics frame.
	get_tree().call_deferred("change_scene_to_file", scene_path)
