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
	
	# --- Guard Clauses for Editor Properties ---
	# Ensure TileMaps are assigned before trying to register them.
	if !is_instance_valid(floor_tilemap) or !is_instance_valid(wall_tilemap):
		push_error("A floor or wall TileMap has not been assigned to this level in the Inspector!")
		# We might want to gracefully handle this, but for now, stopping is safest.
		get_tree().quit() 
		return
	
	# When the level loads, tell the GridManager about our tilemaps.
	Grid.register_level_tilemaps(floor_tilemap, wall_tilemap)
	
	# Get all the spawn point children into an array when the level loads.
	player_spawn_points = player_spawn_points_container.get_children()
	
	# Play the music track that has been assigned in the Inspector.
	if level_music:
		Music.play_music(level_music)
	else:
		# This isn't a fatal error, but it's good to know if we forgot it.
		push_warning("No level_music has been assigned to this level in the Inspector.")

	# --- Network Readiness ---
	# Both host and client will report to the server when they are ready.
	if multiplayer.is_server():
		server_peer_ready(1) # The host is always ready for itself.
	else:
		server_peer_ready.rpc_id(1, multiplayer.get_unique_id()) # Clients send an RPC.
		
	# The server listens for loot drop requests from dying enemies and now from players.
	if multiplayer.is_server():
		EventBus.loot_drop_requested.connect(_on_loot_drop_requested)
		
# Contains the server-authoritative logic for spawning a player character.
func _spawn_player(id: int):
	# --- Pre-Spawn Validation ---
	# Guard Clause: Ensure the required spwaner nodesexist in the scene.
	var player_spawner = get_node_or_null("PlayerSpawner")
	if !is_instance_valid(player_spawner):
		push_error("BaseLevel: PlayerSpawner not found! Cannot spawn player.")
		return
	
	# Guard Clause: Ensure the required container nodes exist in the scene.
	# THE FIX: The 'container' is now the WorldYSort node itself.
	var container = get_node_or_null("WorldYSort")
	if !is_instance_valid(container):
		push_error("BaseLevel: WorldYSort  not found! Cannot spawn player.")
		return

	# Guard Clause: Prevent spawning the same player twice if they already exist.
	if container.has_node(str(id)):
		push_warning("BaseLevel: Attempted to spawn player ID %s, but they already exist." % id)
		return
	
	# Guard Clause: Ensure the PLAYER_SCENE constant is a valid PackedScene.
	if !NetworkManager.PLAYER_SCENE is PackedScene:
		push_error("NetworkManager.PLAYER_SCENE is not a valid PackedScene! Cannot spawn player.")
		return
	
	# --- Determine Spawn Position ---
	var spawn_position = Vector2.ZERO
	if !player_spawn_points.is_empty():
		spawn_position = player_spawn_points[current_player_spawn_index].global_position
		# Cycle through the available spawn points for each new player.
		current_player_spawn_index = (current_player_spawn_index + 1) % player_spawn_points.size()
	else:
		push_warning("No player spawn points found in this level! Player will spawn at (0,0).")
	
	# --- Instantiate and Configure ---
	var player = NetworkManager.PLAYER_SCENE.instantiate()
	
	# CRITICAL ORDER: The node's name and multiplayer authority MUST be set *before*
	# adding it to the scene tree to ensure the MultiplayerSpawner replicates it correctly.
	player.set_multiplayer_authority(id)
	player.name = str(id)
	
	# Set the position on the server's instance.
	player.global_position = spawn_position
	
	# Add the player to the WorldYSort container. The MultiplayerSpawner will now detect this
	# and automatically replicate the spawn event to all clients.
	container.add_child(player)
	
	# --- Post-Spawn Synchronization ---
	# Now that the player exists on all clients, we can send them their data.
	GameManager.send_transition_data_to_player(id)
	
	# We also call an RPC on the specific client to ensure their local position is set correctly on the first frame.
	player.set_initial_position.rpc_id(id, spawn_position)

# This is our new, robust handshake function.
func _perform_global_handshake():
	# THE FIX: Instead of finding containers, get all nodes in the "player" group.
	var players_in_this_scene = get_tree().get_nodes_in_group("player")
	
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
	# THE FIX: Get all nodes in the "enemies" group.
	var enemies_in_this_scene = get_tree().get_nodes_in_group("enemies")
		
	# For every player who is now in the scene...
	for player in players_in_this_scene:
		var player_id = int(player.name)
		# ...make every enemy visible to them.
		for enemy in enemies_in_this_scene:
			_rpc_force_visibility_update.rpc(enemy.get_path(), player_id, true)

# A reusable function to make a specific node visible to all current players.
# This will be used by projectiles and loot drops.
func make_node_visible_to_all(node_path: NodePath) -> void:
	# This function must only be called on the server.
	if not multiplayer.is_server(): return

	var all_peers = multiplayer.get_peers()
	all_peers.append(1) # Include the server itself

	for peer_id in all_peers:
		_rpc_force_visibility_update.rpc(node_path, peer_id, true)

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

	# THE FIX: Get all dynamic nodes by their group instead of searching in containers.
	var players = get_tree().get_nodes_in_group("player")
	var enemies = get_tree().get_nodes_in_group("enemies")
	var loot_drops = get_tree().get_nodes_in_group("loot")
	var projectiles = get_tree().get_nodes_in_group("projectile")
	var all_dynamic_nodes = players + enemies + loot_drops + projectiles
	
	# Hide all node Synchronisers, do prevent packet errors if still enabled
	for node in all_dynamic_nodes:
		# ...tell every peer (including the server) to stop seeing them.
		for peer_id in all_peers:
			_rpc_force_visibility_update.rpc(node.get_path(), peer_id, false)
			
		var sync = node.get_node_or_null("MultiplayerSynchronizer")
		if is_instance_valid(sync):
			# For the server itself (peer_id 1), update visibility LOCALLY and IMMEDIATELY.
			# This avoids the host sending an RPC to itself, fixing the race condition.
			sync.set_visibility_for(1, false)

# This is our new, reusable helper function for spawning a specific item.
func _spawn_single_item(item_to_drop: ItemData, position: Vector2, apply_cooldown: bool):
	if not is_instance_valid(item_to_drop) or item_to_drop.resource_path.is_empty():
		return

	var loot_instance = LootDropScene.instantiate()
	
	# Configure the loot drop.
	loot_instance.item_data_path = item_to_drop.resource_path
	loot_instance.global_position = position
	# NEW: We pass the cooldown flag to the loot instance.
	loot_instance.apply_pickup_delay = apply_cooldown 
	
	# THE FIX: Get the WorldYSort node, as it's the new container for all spawned items.
	var y_sort_container = get_node_or_null("WorldYSort")
	if not is_instance_valid(y_sort_container):
		push_error("Could not find 'WorldYSort' node in the current level!")
		loot_instance.queue_free()
		return
	
	y_sort_container.add_child(loot_instance, true)
	make_node_visible_to_all(loot_instance.get_path())

# -- Signal Handlers --
# Runs on the server when an enemy's death requests a loot drop via the EventBus.
func _on_loot_drop_requested(loot_table: LootTableData, position: Vector2) -> void:
	# Guard Clause: Do nothing if the loot table is invalid.
	if not is_instance_valid(loot_table): return
		
	var item_to_drop = loot_table.get_drop()
	# Enemy drops do NOT apply the pickup cooldown.
	_spawn_single_item(item_to_drop, position, false)

# We no longer need _on_item_drop_requested_by_player, it's replaced by the RPC.
# And we can remove the EventBus connection in _ready().

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

# This RPC is called by a client when they request to drop an item.
@rpc("any_peer", "call_local", "reliable")
func server_request_player_drop(item_path: String, position: Vector2):
	# Get the ID of the client who sent this request.
	var player_id = multiplayer.get_remote_sender_id()
	
	# Get the server's version of that player.
	var player = GameManager.get_player(player_id)
	if not is_instance_valid(player): return
		
	# Authoritatively remove the item from the server's version of the player's inventory.
	var inventory_component = player.get_node("InventoryComponent")
	var item_resource = ItemDatabase.get_item(item_path)
	if is_instance_valid(inventory_component) and is_instance_valid(item_resource):
		inventory_component.remove_item(item_resource)
	
	# Now, reuse our existing loot spawning logic to create the item in the world.
	# We'll call the function directly since we're already on the server.
	_spawn_single_item(item_resource, position, true)
