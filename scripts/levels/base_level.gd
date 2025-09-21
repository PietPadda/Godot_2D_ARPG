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
# These nodes are now required by any scene using BaseLevel.
@onready var player_container: Node2D = $PlayerContainer
@onready var player_spawn_points_container: Node2D = $PlayerSpawnPoints
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner

var player_spawn_points: Array = []
var current_player_spawn_index: int = 0

func _ready() -> void:
	# CRITICAL: Give the server ownership of the spawners FIRST.
	player_spawner.set_multiplayer_authority(1)
	
	# When the level loads, tell the GridManager about our tilemaps.
	Grid.register_level_tilemaps(floor_tilemap, wall_tilemap)
	
	# Get all the spawn point children into an array when the level loads.
	player_spawn_points = player_spawn_points_container.get_children()
	
	# Play the music track that has been assigned in the Inspector.
	if level_music:
		Music.play_music(level_music)
	
	# Connect our listener FIRST, so we are ready to receive requests.
	NetworkManager.player_spawn_requested.connect(_on_player_spawn_requested)
	
	# If we are the server, we are ready, so spawn ourselves.
	if multiplayer.is_server():
		_on_player_spawn_requested(1)

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
