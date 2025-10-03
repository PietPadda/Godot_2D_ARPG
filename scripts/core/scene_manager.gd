# scripts/core/scene_manager.gd
# A global singleton for managing scene transitions.
class_name SceneManager
extends Node

# This will hold a reference to the currently instanced level node.
var current_level: Node = null

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
	
# --- Private Functions ---


# --- RPCs ---
# This function can be called by any client, but will only run on the server (peer 1).
@rpc("any_peer", "call_local")
func request_scene_transition(scene_path: String, player_id: int, player_data: Dictionary) -> void:
	# This is a guard clause. If a non-server peer somehow tries to run this, stop.
	if not multiplayer.is_server():
		return
		
	# Server Log
	print("[SERVER] Received request from player %s to transition to scene: %s" % [player_id, scene_path])
	
	# Clear any old data from a previous transition.
	GameManager.all_players_transition_data.clear()
	
	# Store the CORRECT data that the client just sent us.
	GameManager.all_players_transition_data[player_id] = player_data
	
	# For all OTHER players, REQUEST their data.
	for p_id in GameManager.active_players:
		# Skip the player who already sent their data.
		if p_id == player_id:
			continue
		
		var other_player_node = GameManager.get_player(p_id)
		if is_instance_valid(other_player_node):
			# Send an RPC asking this player to send their data back.
			other_player_node.client_gather_and_send_data.rpc_id(p_id)
	
	# Wait a moment for the data RPCs to arrive before continuing.
	# This is a simple and reliable way to handle the network delay.
	await get_tree().create_timer(0.2).timeout
	
	print("[SERVER] All data gathered. Initiating transition for all players...")
	
	# Change Scene: Use call_deferred to give the shutdown a frame to complete
	# before broadcasting the command to load the new scene.
	transition_to_scene.rpc.call_deferred(scene_path)
	
# This RPC is called BY the server ON all clients to execute the change.
@rpc("any_peer", "call_local", "reliable")
func transition_to_scene(scene_path: String) -> void:
	# If there's an old level instance, free it.
	if is_instance_valid(current_level):
		current_level.queue_free()

	# Load the new level scene resource from the provided path.
	var new_level_scene = load(scene_path)
	if not new_level_scene:
		push_error("Failed to load scene: %s" % scene_path)
		return

	# Create an instance of the new level.
	current_level = new_level_scene.instantiate()

	# Find our persistent container and add the new level there.
	var container = get_tree().get_first_node_in_group("level_container")
	if container:
		container.add_child(current_level)
	else:
		# This should never happen if the World scene is set up correctly.
		push_error("SceneManager could not find a 'level_container' node!")
