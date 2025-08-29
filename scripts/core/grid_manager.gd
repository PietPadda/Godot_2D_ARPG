# scripts/core/grid_manager.gd
class_name GridManager
extends Node

# This will hold a reference to the main level's TileMapLayer.
var tile_map_layer: TileMapLayer

# Converts a world position (like a mouse click) to a map grid coordinate.
func world_to_map(world_position: Vector2) -> Vector2i:
	if tile_map_layer:
		return tile_map_layer.local_to_map(world_position)
	return Vector2i.ZERO # Return a default value if the tilemap isn't set

# Converts a map grid coordinate back to a world position (the center of the tile).
func map_to_world(map_position: Vector2i) -> Vector2:
	if tile_map_layer:
		return tile_map_layer.map_to_local(map_position)
	return Vector2.ZERO # Return a default value if the tilemap isn't set
