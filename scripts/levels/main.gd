# scripts/levels/main.gd
extends BaseLevel

# preloads
const SKELETON_SCENE = preload("res://scenes/enemies/skeleton.tscn")

# scene nodes
# Onready vars for spawners and containers are now needed here.
@onready var player_spawner = $PlayerSpawner
@onready var enemy_spawner = $EnemySpawner
@onready var loot_spawner = $LootSpawner
@onready var projectile_spawner = $ProjectileSpawner
# THE FIX: We no longer need a direct reference to the enemies_container.
# We'll get the WorldYSort node when we need it.
# @onready var enemies_container: Node2D = $EnemyContainer
# We still need a reference to the spawn points, which are still in the level.
@onready var enemy_spawn_points_container: Node2D = $EnemySpawnPoints

# Consts and vars
var enemy_spawn_points: Array = []

# The setup logic MUST be in _ready() to run once at the start.
func _ready():
	super() # This runs all the logic from BaseLevel._ready()

	# Get all the spawn point children into an array when the level loads.
	enemy_spawn_points = enemy_spawn_points_container.get_children()
	
	if multiplayer.is_server():
		# The server will listen for any enemy dying in its world.
		EventBus.enemy_died.connect(_on_enemy_died)
		EventBus.debug_respawn_enemies_requested.connect(_on_debug_respawn_enemies)
		
		# THE FIX: Now that the base level has finished its setup,
		# if we are the server, we can safely spawn our enemies.
		if get_tree().get_nodes_in_group("enemies").is_empty():
			_spawn_initial_enemies()
		
# This function can now be left empty or used for other inputs.
func _unhandled_input(_event: InputEvent) -> void:
	pass

# -- Signal Handlers --
# This function is ONLY called by the server.
func _spawn_initial_enemies():
	# This debug print helps confirm the server is running this code.
	print("[HOST] Spawning initial enemies...")
	
	# THE FIX: Get a reference to the WorldYSort node.
	var y_sort_container = get_node_or_null("WorldYSort")
	if not is_instance_valid(y_sort_container):
		push_error("main.gd: WorldYSort node not found! Cannot spawn enemies.")
		return
	
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
		
		# Now, add the fully configured skeleton to the YSort container.
		y_sort_container.add_child(skeleton)
		
# handle the died signal and send the RPC
func _on_enemy_died(stats_data: CharacterStats, attacker_id: int):
	# This function will only ever run on the server, where the signal is emitted.
	# First, check if the attacker is a valid player (not 0 or another enemy).
	if attacker_id == 0:
		return

	# THE FIX: Instead of searching a container, get all nodes in the "player" group.
	# get_tree() searches the entire active scene, which for us IS the current level.
	var players = get_tree().get_nodes_in_group("player")
	for player_node in players:
		if int(player_node.name) == attacker_id:
			var xp_reward = stats_data.xp_reward
			# Call the RPC on them to grant the XP award.
			player_node.award_xp_rpc.rpc_id(attacker_id, xp_reward)
			# We found our player, so we can stop searching.
			break

# This new function will handle the respawn request.
func _on_debug_respawn_enemies() -> void:
	print("DEBUG (Main): Received request to respawn enemies.")
	
	# Delete all existing enemies.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
		
	# Call our original spawning function to create new ones.
	_spawn_initial_enemies()
