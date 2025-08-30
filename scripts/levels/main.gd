# main.gd
extends Node2D

# scene nodes
@onready var tile_map_layer = $TileMapLayer

# The setup logic MUST be in _ready() to run once at the start.
func _ready():
	# Give the GridManager a direct reference to our level's TileMapLayer.
	Grid.tile_map_layer = tile_map_layer
	# Now, tell it to build the pathfinding graph for the current level.
	Grid.build_level_graph()

# This function can now be left empty or used for other inputs.
func _unhandled_input(event: InputEvent) -> void:
	pass
