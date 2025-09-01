# main.gd
extends Node2D

# scene nodes
@onready var tile_map_layer = $TileMapLayer

# The setup logic MUST be in _ready() to run once at the start.
func _ready():
	# Tell the MusicManager to play our dungeon theme.
	Music.play_music(load("res://data/audio/dungeon_theme.tres"))
	
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
