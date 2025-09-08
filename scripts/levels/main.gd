# main.gd
extends Node2D

# scene nodes
@onready var tile_map_layer = $TileMapLayer
# player container used for spawning
@onready var player_container: Node2D = $PlayerContainer
# Add a reference to our new spawn points container.
@onready var spawn_points_container: Node2D = $PlayerSpawnPoints
# Add a reference to our bunch of enemies.
@onready var enemies_container: Node2D = $EnemyContainer
# Add a reference to our new spawn points container.
@onready var enemy_spawn_points_container: Node2D = $EnemySpawnPoints
# Add a reference to our new spawner.
@onready var enemy_spawner: MultiplayerSpawner = $EnemySpawner
const SKELETON_SCENE = preload("res://scenes/enemies/skeleton.tscn")

# Expose a slot in the Inspector for the music track.
@export var level_music: MusicTrackData

# Consts and vars
var player_spawn_points: Array = []
var current_player_spawn_index: int = 0

var enemy_spawn_points: Array = []
var current_enemy_spawn_index: int = 0

# The setup logic MUST be in _ready() to run once at the start.
func _ready():
	# Get all the spawn point children into an array when the level loads.
	player_spawn_points = spawn_points_container.get_children()
	
	# Get all the spawn point children into an array when the level loads.
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
	
	# Now that we're ready, ask the NetworkManager to spawn everyone
	# who has already connected (including ourselves if we are the host).
	NetworkManager.spawn_existing_players()
	
	# If we are the server, call a new function to spawn enemies for everyone.
	if multiplayer.is_server():
		_spawn_initial_enemies()

# This function can now be left empty or used for other inputs.
func _unhandled_input(event: InputEvent) -> void:
	pass

# -- Signal Handlers --
# This function will run when the signal is received.
# It contains the logic we moved from the NetworkManager.
func _on_player_spawn_requested(id: int):
	var player_instance = NetworkManager.PLAYER_SCENE.instantiate()
	player_instance.name = str(id)
	# REMOVE THIS LINE - The player now does this itself in _enter_tree.
	# player_instance.set_multiplayer_authority(id)
	
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
	
	# Call the RPC on the client who owns this new player.
	player_instance.set_initial_position.rpc_id(id, spawn_pos)

# This function is ONLY called by the server.
func _spawn_initial_enemies():
	# This debug print helps confirm the server is running this code.
	print("[HOST] Spawning initial enemies...")
	
	# We'll use the same spawn points you defined for players,
	# but you could create a separate group for enemies.
	for point in enemy_spawn_points:
		# Create a new instance of our skeleton scene.
		var skeleton = SKELETON_SCENE.instantiate()
		
		# Set its starting position based on the spawn point.
		skeleton.global_position = point.global_position
		
		# THIS IS THE MOST IMPORTANT STEP:
		# Add the new skeleton as a child of the MultiplayerSpawner.
		# The spawner will now automatically create this skeleton on all clients.
		enemies_container.add_child(skeleton)
