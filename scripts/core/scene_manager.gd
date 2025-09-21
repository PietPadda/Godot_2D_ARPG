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

# --- RPCs ---
# This function can be called by any client, but will only run on the server (peer 1).
@rpc("any_peer", "call_local")
func request_scene_transition(scene_path: String, player_id: int) -> void:
	# This is a guard clause. If a non-server peer somehow tries to run this, stop.
	if not multiplayer.is_server():
		return

	# Server Log
	print("[SERVER] Received request from player %s to transition to scene: %s" % [player_id, scene_path])
	print("[SERVER] Initiating transition...")
	
	# Persist the data for ALL players before we leave the scene.
	# We need to find the portal's target spawn point for the requesting player.
	var portal = get_tree().get_first_node_in_group("Portal") # A simple way to find the portal
	if portal:
		GameManager.target_spawn_position = portal.spawn_point.global_position
		GameManager.requesting_player_id = player_id
	GameManager.carry_player_data_for_all()

	# Command all clients to transition.
	transition_to_scene.rpc(scene_path)
	
# This RPC is called BY the server ON all clients to execute the change.
@rpc("any_peer", "call_local", "reliable")
func transition_to_scene(scene_path: String) -> void:
	# Each client (and the server) will run this code locally.
	# We can add fade-out/fade-in logic here later.
	get_tree().change_scene_to_file(scene_path)
