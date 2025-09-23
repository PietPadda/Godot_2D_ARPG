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
# This new function will be called by the server to clear old entities.
func _clear_persistent_containers():
	# Get the root World node.
	var world = get_tree().get_root().get_node("World")
	if not is_instance_valid(world): 
		return
	
	# Define the paths to our persistent containers.
	var containers_to_clear = [
		world.get_node("PlayerContainer"),
		world.get_node("EnemyContainer"),
		world.get_node("LootContainer"),
		world.get_node("ProjectileContainer")
	]
	
	# Loop through each container and delete all of its children.
	for container in containers_to_clear:
		if is_instance_valid(container):
			for child in container.get_children():
				child.queue_free()

# --- RPCs ---
# This function can be called by any client, but will only run on the server (peer 1).
@rpc("any_peer", "call_local")
func request_scene_transition(scene_path: String, player_id: int) -> void:
	# This is a guard clause. If a non-server peer somehow tries to run this, stop.
	if not multiplayer.is_server():
		return
		
	# THE FIX: Clean up the persistent containers before transitioning.
	# This RPC will run on the server and all clients simultaneously.
	_clear_persistent_containers()

	# Server Log
	print("[SERVER] Received request from player %s to transition to scene: %s" % [player_id, scene_path])
	print("[SERVER] Initiating transition...")
	
	# Persist player data (this is still necessary).
	GameManager.carry_player_data_for_all() # This should be updated slightly
	
	# Use call_deferred to give the queue_free calls a frame to process
	# before we broadcast the command to load the new scene.
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
