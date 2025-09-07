# main.gd
extends Node2D

# scene nodes
@onready var tile_map_layer = $TileMapLayer
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner # Add a reference to our spawner.

# Expose a slot in the Inspector for the music track.
@export var level_music: MusicTrackData

# The setup logic MUST be in _ready() to run once at the start.
func _ready():
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

# This function can now be left empty or used for other inputs.
func _unhandled_input(event: InputEvent) -> void:
	pass

# -- Signal Handlers --
# This function will run when the signal is received.
# It contains the logic we moved from the NetworkManager.
func _on_player_spawn_requested(id: int):
	var player_scene = preload("res://scenes/player/player.tscn")
	var player_instance = NetworkManager.PLAYER_SCENE.instantiate()
	player_instance.name = str(id)
	
	# Set the authority of the player scene to the peer that just connected.
	player_instance.set_multiplayer_authority(id)
	
	# Spawn the player in game
	player_spawner.add_child(player_instance)
	
	# TODO: Set player's starting position.
