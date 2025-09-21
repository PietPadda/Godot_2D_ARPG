# scripts/levels/main.gd
extends BaseLevel

# preloads
const SKELETON_SCENE = preload("res://scenes/enemies/skeleton.tscn")

# scene nodes
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

# Consts and vars
var enemy_spawn_points: Array = []

# The setup logic MUST be in _ready() to run once at the start.
func _ready():
	super() # This runs all the logic from BaseLevel._ready()
	
	# CRITICAL: Give the server ownership of the spawners FIRST.
	enemy_spawner.set_multiplayer_authority(1)
	loot_spawner.set_multiplayer_authority(1)
	projectile_spawner.set_multiplayer_authority(1)
	
	# Get all the spawn point children into an array when the level loads.
	enemy_spawn_points = enemy_spawn_points_container.get_children()
	
	# If we are the server, call a new function to spawn enemies for everyone.
	if multiplayer.is_server():
		# The server is ready, so it spawns itself.
		_spawn_initial_enemies() # then enemies
		
	# The server will listen for any enemy dying in its world.
	EventBus.enemy_died.connect(_on_enemy_died)
	# THE FIX: Connect to our new debug signal.
	EventBus.debug_respawn_enemies_requested.connect(_on_debug_respawn_enemies)

# This function can now be left empty or used for other inputs.
func _unhandled_input(_event: InputEvent) -> void:
	pass

# -- Signal Handlers --
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
	# This function will only ever run on the server, where the signal is emitted.
	# First, check if the attacker is a valid player (not 0 or another enemy).
	if attacker_id == 0:
		return

	# Find the player node associated with the attacker's ID.
	var player_path = "PlayerContainer/" + str(attacker_id)
	var player_node = get_node_or_null(player_path)
	
	if is_instance_valid(player_node):
		var xp_reward = stats_data.xp_reward
		# We found the player! Call the RPC on them to grant the XP award.
		player_node.award_xp_rpc.rpc_id(attacker_id, xp_reward)
	else:
		pass

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
		# Get the attacker's ID from the projectile
		var attacker_id = projectile.owner_id
		# We deal damage directly because this is all happening on the server. No RPC needed.
		stats.take_damage(projectile.damage, attacker_id)
	
	# The server authoritatively destroys the projectile after the hit is processed.
	projectile.queue_free()
	
# This new function will handle the respawn request.
func _on_debug_respawn_enemies() -> void:
	print("DEBUG (Main): Received request to respawn enemies.")
	
	# Delete all existing enemies.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
		
	# Call our original spawning function to create new ones.
	# (Assuming your spawn function is named _spawn_initial_enemies)
	_spawn_initial_enemies()
