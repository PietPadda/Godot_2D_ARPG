# scripts/core/scene_manager.gd
# A global singleton for managing scene transitions.
class_name SceneManager
extends Node

# This will hold references to all currently instanced level nodes.
var active_levels: Dictionary = {} # Format: { scene_path: level_node }

# REMOVE the old variable:
# var current_level: Node = null

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
	
	# Ensure Destination is Loaded
	if not active_levels.has(scene_path):
		# Tell all clients (and run locally on the server) to load the new scene.
		transition_to_scene.rpc(scene_path)
		# We still need to wait for the scene to physically load before we can act on it.
		# This is the only 'await' needed, to wait for the local scene tree.
		await get_tree().process_frame

	# Store Data & Despawn Player ---
	# Clear any old data from a previous transition.
	GameManager.all_players_transition_data.clear()
	
	# Store the CORRECT data that the client just sent us.
	GameManager.all_players_transition_data[player_id] = player_data
	
	# Get the player's OLD level path from our authoritative tracker.
	var old_level_path = GameManager.player_locations.get(player_id)
	if old_level_path and active_levels.has(old_level_path):
		var old_level = active_levels.get(old_level_path)
		var player_node = old_level.get_node_or_null("WorldYSort/" + str(player_id))
		
		if is_instance_valid(player_node):
			# SHUTDOWN SYNC for the specific player.
			old_level.hide_node_for_transition(player_node.get_path())
			# Wait one frame to ensure visibility RPCs are sent before despawning.
			await get_tree().process_frame
			
			# This is replicated to all clients automatically by the MultiplayerSpawner.
			player_node.queue_free()
			
	# Authoritatively update the player's location.
	GameManager.player_locations[player_id] = scene_path
	GameManager.client_update_player_locations.rpc(GameManager.player_locations)

	# NOTE: We no longer call _spawn_player here. The newly spawned player's client
	# will load the level, and its _ready() function will call server_peer_ready,
	# which will then correctly spawn the player via the handshake.

	# The newly spawned player's _ready() function will automatically
	# call server_peer_ready, which triggers our existing multi-scene aware
	# _perform_global_handshake to re-enable visibility. The handshake is now complete.
		
# This RPC is called BY the server ON all clients to execute the change.
@rpc("any_peer", "call_local", "reliable")
func transition_to_scene(scene_path: String) -> void:
	# Additive Load: If the level is already loaded on this client, do nothing.
	if active_levels.has(scene_path):
		return

	# Load the new level scene resource from the provided path.
	var new_level_scene = load(scene_path)
	if not new_level_scene:
		push_error("Failed to load scene: %s" % scene_path)
		return

	# Create an instance of the new level.
	var level_instance = new_level_scene.instantiate()

	# Find our persistent container and add the new level there.
	var container = get_tree().get_first_node_in_group("level_container")
	if container:
		# The level's own _ready() function will handle registering
		# itself with LevelManager, which updates Scene.active_levels
		container.add_child(level_instance)
	else:
		# This should never happen if the World scene is set up correctly.
		push_error("SceneManager could not find a 'level_container' node!")
