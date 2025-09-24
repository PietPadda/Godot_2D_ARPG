# scripts/levels/base_level.gd

# The foundational script for all game levels, containing common logic
# for player spawning, music, and network events.
class_name BaseLevel
extends Node2D # Both main.gd and town.gd extend Node2D

# --- Common Level Properties ---
@export var floor_tilemap: TileMapLayer
@export var wall_tilemap: TileMapLayer
@export var level_music: MusicTrackData

# --- Player Spawning Properties ---
# REMOVE the old @onready vars. They no longer exist in this scene.
# @onready var player_container: Node2D = $PlayerContainer 
# @onready var player_spawner: MultiplayerSpawner = $PlayerSpawner

# --- Player Spawning Properties ---
@onready var player_spawn_points_container: Node2D = $PlayerSpawnPoints

var player_spawn_points: Array = []
var current_player_spawn_index: int = 0

func _ready() -> void:
	# Announce to our new service that this is the active level.
	LevelManager.register_active_level(self)
	
	# When the level loads, tell the GridManager about our tilemaps.
	Grid.register_level_tilemaps(floor_tilemap, wall_tilemap)
	
	# Get all the spawn point children into an array when the level loads.
	player_spawn_points = player_spawn_points_container.get_children()
	
	# Play the music track that has been assigned in the Inspector.
	if level_music:
		Music.play_music(level_music)
	
	# REMOVE the connection to the old NetworkManager signal.
	# NetworkManager.player_spawn_requested.connect(_on_player_spawn_requested)
	
	# THE FIX: Implement the handshake.
	if multiplayer.is_server():
		# The server is ready, so it can spawn itself.
		_on_player_spawn_requested(1)
	else:
		# The client has loaded the level. Now, tell the server it's ready for content.
		server_confirm_level_loaded.rpc_id(1)
	
#	# Listen for the signal to start the cleanup process.
#	EventBus.server_requesting_transition.connect(_on_server_requesting_transition)

# -- Signal Handlers --
# This function will run when the signal is received.
# It contains the logic we moved from the NetworkManager.
func _on_player_spawn_requested(id: int):
	# THE FIX: Get the currently active level from our service locator.
	var level = LevelManager.get_current_level()
	if not is_instance_valid(level): return
	
	# Now, find the PlayerContainer WITHIN that active level.
	var player_container = level.get_node_or_null("PlayerContainer")
	
	# Add a safety check in case the container is missing from the scene.
	if not is_instance_valid(player_container):
		push_error("Could not find 'PlayerContainer' in the current level!")
		return
	
	#  Add a guard clause to prevent spawning duplicates.
	if player_container.has_node(str(id)):
		return # This player has already been spawned, so we do nothing.
	
	var player_instance = NetworkManager.PLAYER_SCENE.instantiate()
	player_instance.name = str(id)
	
	var spawn_pos = Vector2.ZERO # Default in case we have no spawn points
	# Check if we have any spawn points defined.
	if not player_spawn_points.is_empty():
		# Get the position of the next spawn point in the cycle.
		spawn_pos = player_spawn_points[current_player_spawn_index].global_position
		# Move to the next index, wrapping around if we reach the end.
		current_player_spawn_index = (current_player_spawn_index + 1) % player_spawn_points.size()
	
	# We still set the position on the server instance.
	player_instance.global_position = spawn_pos
	
	# Add the player to the container that the MultiplayerSpawner is watching.
	player_container.add_child(player_instance)
	
	# Re-add this line to tell the owning client their starting position.
	player_instance.set_initial_position.rpc_id(id, spawn_pos)
	
# This function only runs on the server's instance of the level.
# func _on_server_requesting_transition(scene_path: String) -> void:
#	print("[SERVER] Level is gracefully despawning all players.")
#	
#	# Use our spawner to gracefully despawn each player.
#	for player in player_container.get_children():
#		# The server calling queue_free() on a replicated node
#		# is the correct way to despawn it across all clients.
#		player.queue_free()
#	
#	# Wait for the next frame to allow the despawn network packets to be sent and processed.
#	await get_tree().process_frame
#	
#	# Now that the slate is clean, tell the SceneManager to proceed with the transition.
#	Scene.transition_to_scene.rpc(scene_path)

# -- RPCs --
@rpc("any_peer", "call_local", "reliable")
func server_process_projectile_hit(projectile_path: NodePath, target_path: NodePath):
	# This function runs only on the server.
	var projectile = get_node_or_null(projectile_path)
	var target = get_node_or_null(target_path)
	
	# This is the critical safety check. If either the projectile or the target
	# has already been destroyed by another event, we simply do nothing.
	if not is_instance_valid(projectile) or not is_instance_valid(target):
		return # do nothing to prevent RPC race condition

	# If both are valid, proceed with dealing damage.
	var stats: StatsComponent = target.get_node_or_null("StatsComponent")
	if stats:
		# Get the attacker's ID from the projectile
		var attacker_id = projectile.owner_id
		# We deal damage directly because this is all happening on the server. No RPC needed.
		stats.take_damage(projectile.damage, attacker_id)
	
	# The server authoritatively destroys the projectile after the hit is processed.
	projectile.queue_free()
	
# This function is called BY a client, but runs ON the server.
@rpc("any_peer", "call_local", "reliable")
func server_spawn_my_player():
	if not multiplayer.is_server(): return

	var client_id = multiplayer.get_remote_sender_id()
	print("[SERVER] Received spawn request from client %s." % client_id)
	_on_player_spawn_requested(client_id)
	
# NEW RPC for the client to call on the server.
@rpc("any_peer", "call_local")
func server_confirm_level_loaded():
	# This function only runs on the server.
	var client_id = multiplayer.get_remote_sender_id()
	print("[SERVER] Client %s confirmed level loaded. Spawning entities for them." % client_id)
	
	# Now it's safe to spawn the existing host player for the new client.
	_on_player_spawn_requested(1)
	
	# And now it's safe to spawn the new client's own player.
	_on_player_spawn_requested(client_id)
	
	# In the future, we'll also spawn existing enemies here.
