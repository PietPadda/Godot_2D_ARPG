# town.gd
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
	
	# Give the GridManager a direct reference to our level's TileMapLayer.
	Grid.tile_map_layer = tile_map_layer
	# Defer the graph building to ensure the physics server is ready.
	call_deferred("_build_pathfinding_graph")
	
# This function will now be called safely after the first frame.
func _build_pathfinding_graph():
	# Now, tell the GridManager to build the pathfinding graph for the current level.
	Grid.build_level_graph()

# This function can now be left empty or used for other inputs.
func _unhandled_input(event: InputEvent) -> void:
	pass
