# main.gd
extends Node2D

# scene nodes
@onready var tile_map_layer = $TileMapLayer

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

# This function can now be left empty or used for other inputs.
func _unhandled_input(event: InputEvent) -> void:
	pass
