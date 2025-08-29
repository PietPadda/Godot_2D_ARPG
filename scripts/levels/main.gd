# main.gd
extends Node2D

# scene nodes
@onready var tile_map_layer = $TileMapLayer

func _unhandled_input(event: InputEvent) -> void:
	# Give the GridManager a direct reference to our level's TileMapLayer.
	Grid.tile_map_layer = tile_map_layer
