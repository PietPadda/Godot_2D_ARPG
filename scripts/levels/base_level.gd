# scripts/levels/base_level.gd

# The foundational script for all game levels, containing common logic
# for player spawning, music, and network events.
class_name BaseLevel
extends Node2D # Both main.gd and town.gd extend Node2D

# Preload the LootDrop scene at the top of the script
const LootDropScene = preload("res://scenes/items/loot_drop.tscn")

# --- Common Level Properties ---
@export var floor_tilemap: TileMapLayer
@export var wall_tilemap: TileMapLayer
@export var level_music: MusicTrackData

# --- Player Spawning Properties ---
@onready var player_spawn_points_container: Node2D = $PlayerSpawnPoints

var player_spawn_points: Array = []
var current_player_spawn_index: int = 0

var _peers_ready_in_level := []

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
		
	# The level will listen for loot drop requests. This only needs to happen on the server.
	if multiplayer.is_server():
		EventBus.loot_drop_requested.connect(_on_loot_drop_requested)
	
# This function contains the core spawning logic and is ONLY ever run on the server.
# It now uses the Auto Spawn List feature by manually instancing and adding as a child.
# This function now also makes the new player visible to everyone.
func _spawn_player(id: int):
	# DEBUG: Trace the start of the spawning process on the HOST.
	print("[HOST] _spawn_player: Spawning character for ID: %s" % id)
	
	# Find the spawner and container nodes.
	var player_spawner = get_node_or_null("PlayerSpawner")
	var container = get_node_or_null("PlayerContainer")
	if not is_instance_valid(player_spawner) or not is_instance_valid(container):
		push_error("BaseLevel: PlayerSpawner or PlayerContainer not found!")
		return

	# Prevent spawning the same player twice (a safeguard).
	if container.has_node(str(id)): 
		return
	
	# Determine the spawn position and store it.
	var spawn_position = Vector2.ZERO
	if not player_spawn_points.is_empty():
		spawn_position = player_spawn_points[current_player_spawn_index].global_position
		current_player_spawn_index = (current_player_spawn_index + 1) % player_spawn_points.size()
	
	# FIX: Switch back to manual instantiation + add_child() for Auto Spawn List feature.
	var player = NetworkManager.PLAYER_SCENE.instantiate()
	
	# CRITICAL: We set the authority BEFORE adding it to the scene tree.
	# This prevents conflicts with the MultiplayerSynchronizer.
	player.set_multiplayer_authority(id)
	
	# CRITICAL: We rename the local server's copy. The GameManager relies on the name 
	# being the player's ID for its registration logic.
	player.name = str(id)
	
	# Set the position on the server's instance.
	player.global_position = spawn_position
	
	# Add the player to the Spawn Path (PlayerContainer).
	# The MultiplayerSpawner detects this and replicates the spawn event to all clients.
	container.add_child(player)
	
	# THE FIX: Immediately after spawning the player on the server,
	# tell the GameManager to send them their transition data.
	GameManager.send_transition_data_to_player(id)
	
	# The spawned node's position is synchronized via the MultiplayerSynchronizer/RPC.
	# We call the RPC on the client to ensure its local position is set correctly.
	player.set_initial_position.rpc_id(id, spawn_position)
	
	# REMOVED: We no longer call the handshake from here. This prevents the race condition.
	# call_deferred("_perform_handshake_for_player", id)
	
# This is our new, robust handshake function.
func _perform_global_handshake():
	var container = get_node_or_null("PlayerContainer")
	if not is_instance_valid(container): return
	
	var players_in_this_scene = container.get_children()
	
	# For every combination of players in THIS scene, make them visible to each other.
	for player1 in players_in_this_scene:
		for player2 in players_in_this_scene:
			var p1_id = int(player1.name)
			var p2_id = int(player2.name)
			
			# Tell player2's client that it can now see player1
			_rpc_force_visibility_update.rpc(player1.get_path(), p2_id, true)
			# Tell player1's client that it can now see player2.
			_rpc_force_visibility_update.rpc(player2.get_path(), p1_id, true)
			
	# Enemy-to-Player Handshake
	var enemy_container = get_node_or_null("EnemyContainer")
	if is_instance_valid(enemy_container):
		var enemies_in_this_scene = enemy_container.get_children()
		
		# For every player who is now in the scene...
		for player in players_in_this_scene:
			var player_id = int(player.name)
			# ...make every enemy visible to them.
			for enemy in enemies_in_this_scene:
				_rpc_force_visibility_update.rpc(enemy.get_path(), player_id, true)
	
func _perform_handshake_for_player(new_player_id: int) -> void:
	var container = get_node_or_null("PlayerContainer")
	if not container: return
	
	var new_player = container.get_node_or_null(str(new_player_id))
	if not is_instance_valid(new_player): return

	# --- COMMAND-BASED VISIBILITY HANDSHAKE ---
	# Handle Player-to-Player visibility
	for existing_player in container.get_children():
		if existing_player == new_player:
			continue
		
		var existing_player_id = int(existing_player.name)
		# Command everyone to make the existing player visible to the new player
		_rpc_force_visibility_update.rpc(existing_player.get_path(), new_player_id, true)
		# Make the new player visible to all existing players
		_rpc_force_visibility_update.rpc(new_player.get_path(), int(existing_player_id), true)

	# Make the new player visible to themself
	_rpc_force_visibility_update.rpc(new_player.get_path(), new_player_id, true)
	
	# Make all EXISTING enemies visible to the NEW player.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		_rpc_force_visibility_update.rpc(enemy.get_path(), new_player_id, true)

# A reusable function to make a specific node visible to all current players.
# This will be used by projectiles and loot drops.
func make_node_visible_to_all(node_path: NodePath) -> void:
	# This function must only be called on the server.
	if not multiplayer.is_server(): return

	var all_peers = multiplayer.get_peers()
	all_peers.append(1) # Include the server itself

	for peer_id in all_peers:
		_rpc_force_visibility_update.rpc(node_path, peer_id, true)
		
# -- Signal Handlers --
		
# This function runs on the server when an enemy requests a loot drop.
# We've moved the logic from LootComponent here, to a safe location.
func _on_loot_drop_requested(loot_table: LootTableData, position: Vector2) -> void:
	if not loot_table:
		return
		
	var item_to_drop = loot_table.get_drop()

	if item_to_drop and not item_to_drop.resource_path.is_empty():
		var loot_instance = LootDropScene.instantiate()
		
		# Configure the node's synced properties BEFORE adding it to the scene.
		loot_instance.item_data_path = item_to_drop.resource_path
		loot_instance.global_position = position
		# Keep collision disabled initially.
		loot_instance.get_node("CollisionShape2D").disabled = true
		
		var loot_container = get_node_or_null("LootContainer")
		if not loot_container: 
			return # Safety check
		
		# Add the node. The spawner now replicates it with the correct data path.
		loot_container.add_child(loot_instance, true)
		
		# The RPC is no longer needed and should be removed.
		# loot_instance.initialize.rpc(...)

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
	
# This RPC is the single entry point for making the world visible.
# This RPC is now our gatekeeper for the handshake.
@rpc("any_peer", "call_local", "reliable")
func server_peer_ready(id: int):
	if not multiplayer.is_server(): 
		return
	
	# Spawn the player as soon as they report ready.
	_spawn_player(id)
		
	# Add the player to our headcount for this level.
	if not id in _peers_ready_in_level:
		_peers_ready_in_level.append(id)
	
	print("[SERVER] Peers ready in this level: ", _peers_ready_in_level)
	
	# Check if everyone has arrived.
	if _peers_ready_in_level.size() == multiplayer.get_peers().size() + 1: # +1 for the server
		print("[SERVER] All peers have loaded the level. Performing global handshake.")
		# Use call_deferred to ensure the last player has a frame to fully spawn.
		call_deferred("_perform_global_handshake")
	
# This RPC is a COMMAND from the server to a client telling it
# to update the visibility of a specific node's synchronizer.
@rpc("any_peer", "call_local", "reliable")
func _rpc_force_visibility_update(node_path: NodePath, for_peer_id: int, is_visible: bool) -> void:
	var node = get_node_or_null(node_path)
	if not is_instance_valid(node):
		return
	
	var sync = node.get_node_or_null("MultiplayerSynchronizer")
	if is_instance_valid(sync):
		sync.set_visibility_for(for_peer_id, is_visible)

# This function is called by the SceneManager right before a transition.
# It tells all clients to make all synchronizers invisible to prevent
# errors during the scene change.
func shutdown_network_sync_for_transition():
	# This must only be run on the server.
	if not multiplayer.is_server():
		return
		
	print("[SERVER] Hiding all player synchronizers for scene transition...")

	var all_peers = multiplayer.get_peers()
	all_peers.append(1) # Include the server itself

	var player_container = get_node_or_null("PlayerContainer")
	if is_instance_valid(player_container):
		# Hide all players from everyone
		for player in player_container.get_children():
			# ...tell every peer (including the server) to stop seeing them.
			for peer_id in all_peers:
				_rpc_force_visibility_update.rpc(player.get_path(), peer_id, false)
				
			var sync = player.get_node_or_null("MultiplayerSynchronizer")
			if is_instance_valid(sync):
				# For the server itself (peer_id 1), update visibility LOCALLY and IMMEDIATELY.
				# This avoids the host sending an RPC to itself, fixing the race condition.
				sync.set_visibility_for(1, false)

	# THE FIX: Also hide all enemies from everyone.
	# This prevents the "ERR_UNAUTHORIZED" spam on despawn.
	var enemy_container = get_node_or_null("EnemyContainer")
	if is_instance_valid(enemy_container):
		for enemy in enemy_container.get_children():
			for peer_id in all_peers:
				_rpc_force_visibility_update.rpc(enemy.get_path(), peer_id, false)
				
			var sync = enemy.get_node_or_null("MultiplayerSynchronizer")
			if is_instance_valid(sync):
				# For the server itself (peer_id 1), update visibility LOCALLY and IMMEDIATELY.
				# This avoids the host sending an RPC to itself, fixing the race condition.
				sync.set_visibility_for(1, false)
				
	# Hide all projectiles
	var projectile_container = get_node_or_null("ProjectileContainer")
	if is_instance_valid(projectile_container):
		for projectile in projectile_container.get_children():
			for peer_id in all_peers:
				_rpc_force_visibility_update.rpc(projectile.get_path(), peer_id, false)
				
			var sync = projectile.get_node_or_null("MultiplayerSynchronizer")
			if is_instance_valid(sync):
				# For the server itself (peer_id 1), update visibility LOCALLY and IMMEDIATELY.
				# This avoids the host sending an RPC to itself, fixing the race condition.
				sync.set_visibility_for(1, false)
				
	# Hide all loot
	var loot_container = get_node_or_null("LootContainer")
	if is_instance_valid(loot_container):
		for loot in loot_container.get_children():
			for peer_id in all_peers:
				_rpc_force_visibility_update.rpc(loot.get_path(), peer_id, false)
				
			var sync = loot.get_node_or_null("MultiplayerSynchronizer")
			if is_instance_valid(sync):
				# For the server itself (peer_id 1), update visibility LOCALLY and IMMEDIATELY.
				# This avoids the host sending an RPC to itself, fixing the race condition.
				sync.set_visibility_for(1, false)
