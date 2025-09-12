# main.gd
extends Node2D

# preloads
const SKELETON_SCENE = preload("res://scenes/enemies/skeleton.tscn")

# scene nodes
@onready var tile_map_layer = $TileMapLayer
# player container used for spawning
@onready var player_container: Node2D = $PlayerContainer
# Add a reference to our new spawn points container.
@onready var spawn_points_container: Node2D = $PlayerSpawnPoints
# Add a reference to our player spawner.
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
# Add a reference to our bunch of enemies.
@onready var enemies_container: Node2D = $EnemyContainer
# Add a reference to our new spawn points container.
@onready var enemy_spawn_points_container: Node2D = $EnemySpawnPoints
# Add a reference to our enemy spawner.
@onready var enemy_spawner: MultiplayerSpawner = $EnemySpawner
# Add a reference to our loot spawner.
@onready var loot_spawner: MultiplayerSpawner = $LootSpawner
# Add a reference to our projectile spawner.
@onready var projectile_spawner: MultiplayerSpawner = $ProjectileSpawner

# Expose a slot in the Inspector for the music track.
@export var level_music: MusicTrackData

# Consts and vars
var player_spawn_points: Array = []
var current_player_spawn_index: int = 0
var enemy_spawn_points: Array = []

# The setup logic MUST be in _ready() to run once at the start.
func _ready():
	# CRITICAL: Give the server ownership of the spawners FIRST.
	player_spawner.set_multiplayer_authority(1)
	enemy_spawner.set_multiplayer_authority(1)
	loot_spawner.set_multiplayer_authority(1)
	projectile_spawner.set_multiplayer_authority(1)
	
	# Get all the spawn point children into an array when the level loads.
	player_spawn_points = spawn_points_container.get_children()
	enemy_spawn_points = enemy_spawn_points_container.get_children()
	
	# Play the music track that has been assigned in the Inspector.
	if level_music:
		Music.play_music(level_music)
		
	# Announce which level is setting the tilemap.
	print(self.scene_file_path, ": _ready() is setting Grid.tile_map_layer.")
	
	# Give the GridManager a direct reference to our level's TileMapLayer.
	# The GridManager will handle the rest automatically.
	Grid.tile_map_layer = tile_map_layer
	
	# Connect our listener FIRST, so we are ready to receive requests.
	NetworkManager.player_spawn_requested.connect(_on_player_spawn_requested)
	
	# If we are the server, call a new function to spawn enemies for everyone.
	if multiplayer.is_server():
		# The server is ready, so it spawns itself.
		_on_player_spawn_requested(1)
		_spawn_initial_enemies() # then enemies
		
	# The server will listen for any enemy dying in its world.
	EventBus.enemy_died.connect(_on_enemy_died)

# This function can now be left empty or used for other inputs.
func _unhandled_input(event: InputEvent) -> void:
	pass

# -- Signal Handlers --
# This function will run when the signal is received.
# It contains the logic we moved from the NetworkManager.
func _on_player_spawn_requested(id: int):
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

# This function is ONLY called by the server.
func _spawn_initial_enemies():
	# This debug print helps confirm the server is running this code.
	print("[HOST] Spawning initial enemies...")
	
	# We need a counter to create unique names.
	var enemy_counter = 0
	
	# Enemy spawn points
	for point in enemy_spawn_points:
		# Create a new instance of our skeleton scene.
		var skeleton = SKELETON_SCENE.instantiate()
		
		# Set its starting position based on the spawn point.
		skeleton.global_position = point.global_position
		
		# Give the node a unique name BEFORE adding it to the scene.
		skeleton.name = "Skeleton_" + str(enemy_counter)
		enemy_counter += 1
		
		# Manually set the server as the owner of this new enemy.
		skeleton.set_multiplayer_authority(multiplayer.get_unique_id())
		
		# Now, add the fully configured skeleton to the container.
		enemies_container.add_child(skeleton)
		
# handle the died signal and send the RPC
func _on_enemy_died(stats_data: CharacterStats, attacker_id: int):
	# DEBUG: See if the server is even hearing the event.
	print("[SERVER] _on_enemy_died triggered for attacker: ", attacker_id)
	
	# This function will only ever run on the server, where the signal is emitted.
	# First, check if the attacker is a valid player (not 0 or another enemy).
	if attacker_id == 0:
		return

	# Find the player node associated with the attacker's ID.
	var player_path = "PlayerContainer/" + str(attacker_id)
	var player_node = get_node_or_null("PlayerContainer/" + str(attacker_id))
	
	if is_instance_valid(player_node):
		# DEBUG: Confirm we found the player and are sending the RPC.
		print("[SERVER] Found player node at path: ", player_path, ". Sending XP RPC.")
		
		var xp_reward = stats_data.xp_reward
		# We found the player! Call the RPC on them to grant the XP award.
		player_node.award_xp_rpc.rpc_id(attacker_id, xp_reward)
	else:
		# DEBUG: This will tell us if the lookup is failing.
		print("[SERVER] FAILED to find player node at path: ", player_path)

# --- RPCs ---
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
		# We deal damage directly because this is all happening on the server. No RPC needed.
		stats.take_damage(projectile.damage)
	
	# The server authoritatively destroys the projectile after the hit is processed.
	projectile.queue_free()
