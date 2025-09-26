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
	
	# Both host and client will report to the server when they are ready.
	if multiplayer.is_server():
		server_peer_ready(1) # The host is always ready for itself.
	else:
		server_peer_ready.rpc_id(1, multiplayer.get_unique_id()) # Clients send an RPC.
	
# This function contains the core spawning logic and is ONLY ever run on the server.
# This function now also makes the new player visible to everyone.
func _spawn_player(id: int):
	var container = get_node_or_null("PlayerContainer")
	var spawner = get_node_or_null("PlayerSpawner")
	if not is_instance_valid(container) or not is_instance_valid(spawner): 
		return

	if container.has_node(str(id)): 
		return
	
	var player = NetworkManager.PLAYER_SCENE.instantiate()
	player.name = str(id)

	container.add_child(player)
	
	# After spawning the new player, make its synchronizer visible to ALL peers.
	var sync = player.get_node_or_null("MultiplayerSynchronizer")
	if is_instance_valid(sync):
		for peer_id in multiplayer.get_peers():
			sync.set_visibility_for(peer_id, true)
		sync.set_visibility_for(1, true) # Also for the server
		
		
	# The server determines the position...
	var spawn_pos = Vector2.ZERO
	if not player_spawn_points.is_empty():
		spawn_pos = player_spawn_points[current_player_spawn_index].global_position
		current_player_spawn_index = (current_player_spawn_index + 1) % player_spawn_points.size()
	
	# Use call_deferred to wait for the node to be ready on the client
	# before telling it where to position itself via our new RPC.
	call_deferred("_set_player_initial_position", player.get_path(), id, spawn_pos)
	
# -- Signal Handlers --
# Add this new helper function to make the deferred call cleaner.
func _set_player_initial_position(player_path: NodePath, id: int, pos: Vector2):
	var player_node = get_node_or_null(player_path)
	if is_instance_valid(player_node):
		player_node.set_initial_position.rpc_id(id, pos)

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
	#_on_player_spawn_requested(client_id)
	
# This RPC is called by the client to signal it's ready.
@rpc("any_peer", "call_local")
func server_confirm_level_loaded():
	# This function only runs on the server.
	if not multiplayer.is_server(): 
		return
	
	# This will now always be a valid client ID.
	var client_id = multiplayer.get_remote_sender_id()
	print("[SERVER] Client %s confirmed level loaded. Moving player from limbo." % client_id)
	
	var world = get_tree().get_root().get_node("World")
	var limbo_container = world.get_node("PlayerLimboContainer")
	var player_node = limbo_container.get_node_or_null(str(client_id))
	
	if is_instance_valid(player_node):
		# Get a reference to the PlayerContainer from the active level.
		var level = LevelManager.get_current_level()
		if not is_instance_valid(level): 
			return
		
		var player_container = level.get_node_or_null("PlayerContainer")
		if not is_instance_valid(player_container): 
			return
		
		if is_instance_valid(player_container):
			player_node.reparent(player_container)
			print("[SERVER] Moved player %s to the active level." % client_id)
			
			# Restore the spawner's path for the next player.
			var player_spawner = level.get_node_or_null("PlayerSpawner")
			if is_instance_valid(player_spawner):
				player_spawner.spawn_path = player_container.get_path()
			else:
				push_error("Could not find PlayerContainer in the active level!")
	else:
		push_error("Could not find player %s in the limbo container!" % client_id)

# This RPC is called by the server to run on all clients (and the server itself).
# Its only job is to safely move a node from one parent to another.
@rpc("any_peer", "call_local", "reliable")
func _reparent_node(node_to_move_path: NodePath, new_parent_path: NodePath) -> void:
	var node_to_move = get_node_or_null(node_to_move_path)
	var new_parent = get_node_or_null(new_parent_path)
	
	# These safety checks are critical. It's possible for this command to arrive
	# on a laggy client a moment before the node has finished spawning in Limbo.
	# If that happens, we simply do nothing, and the system will catch up.
	if not is_instance_valid(node_to_move) or not is_instance_valid(new_parent):
		return
		
	# This is the core of the operation.
	node_to_move.reparent(new_parent)

# This RPC is called BY a client and runs ON the server.
@rpc("any_peer", "call_local", "reliable")
func server_request_spawn():
	var client_id = multiplayer.get_remote_sender_id()
	_spawn_player(client_id)

# This is our new spawner. It runs on the server AND all clients.
@rpc("any_peer", "call_local", "reliable")
func client_spawn_player(id: int):
	var player_container = get_node("PlayerContainer")
	
	# A guard to prevent creating the same player twice if messages get crossed.
	if player_container.has_node(str(id)):
		return

	var player = NetworkManager.PLAYER_SCENE.instantiate()
	# We set the name BEFORE adding to the scene. This is critical.
	# The player's _enter_tree() function uses this name to set its own authority.
	player.name = str(id)
	
	player_container.add_child(player)
	# We set the position AFTER adding it to the scene tree.
	# We DO NOT set the position here. The synchronizer will do it.

# This RPC is the single entry point for making the world visible. Runs ONLY on the server.
@rpc("any_peer", "call_local", "reliable")
func server_peer_ready(id: int):
	if not multiplayer.is_server(): 
		return

	print("[SERVER] Peer %s confirmed level is loaded. Revealing world..." % id)
	
	# Make all existing players and enemies visible to the new peer.
	for node in get_tree().get_nodes_in_group("characters"):
		var sync = node.get_node_or_null("MultiplayerSynchronizer")
		if is_instance_valid(sync):
			sync.set_visibility_for(id, true)
			
	# Finally, spawn the player character FOR the peer that just reported ready.
	_spawn_player(id)
