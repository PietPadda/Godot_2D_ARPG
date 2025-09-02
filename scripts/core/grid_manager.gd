# scripts/core/grid_manager.gd
class_name GridManager
extends Node

# Our debug tile scene
@export var debug_tile_scene: PackedScene

# This will hold a reference to the main level's TileMapLayer.
var tile_map_layer: TileMapLayer

# Pathfinding
# --- THE FIX: Use AStarGrid2D ---
var astar_grid := AStarGrid2D.new()

# Builds the A* pathfrom the level's TileMapLayer.
func build_level_graph():
	if not tile_map_layer:
		push_error("GridManager: TileMapLayer not set!")
		return

	# Set up the AStarGrid2D with our map's data
	var map_rect = tile_map_layer.get_used_rect()
	astar_grid.region = map_rect
	astar_grid.cell_size = Vector2(1, 1) # We use a 1-to-1 mapping
	
	# HEURISTIC_EUCLIDEAN is more accurate for 8-directional movement.
	astar_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	astar_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	astar_grid.update()
	
	# Now, tell the grid which cells are walls ("solid")
	for x in range(map_rect.position.x, map_rect.end.x): # loop x cells
		for y in range(map_rect.position.y, map_rect.end.y): # loop y cells
			var cell = Vector2i(x, y) # cell at x:y
			var tile_data = tile_map_layer.get_cell_tile_data(cell)
			
			# A cell is walkable if it's empty (no tile data)
			# OR if it has a tile, and that tile's "is_walkable" custom data is true.
			var is_walkable = false
			if not tile_data:
				is_walkable = true # Empty space is walkable
			else:
				is_walkable = tile_data.get_custom_data("is_walkable") # Check the tile's property
			# If a tile is NOT walkable, then it is a solid point.
			if not is_walkable:
				astar_grid.set_point_solid(cell)
				
	# Debug Walkable Tiles Visualisation
	if debug_tile_scene:
		var main_scene = get_tree().current_scene
		for x in range(map_rect.position.x, map_rect.end.x):
			for y in range(map_rect.position.y, map_rect.end.y):
				var cell = Vector2i(x, y)
				if not astar_grid.is_point_solid(cell):
					var tile_instance = debug_tile_scene.instantiate()
					main_scene.add_child(tile_instance)
					tile_instance.global_position = map_to_world(cell) - (Vector2(tile_map_layer.tile_set.tile_size) / 2)

# Finds the shortest path between two points on the grid.
func find_path(start_coord: Vector2i, end_coord: Vector2i) -> PackedVector2Array:
	# AStarGrid2D returns an array of map coordinates directly.
	var map_path: PackedVector2Array = astar_grid.get_point_path(start_coord, end_coord)
	
	# Convert the path of map coordinates to world positions.
	var world_path: PackedVector2Array = []
	for map_coord in map_path:
		world_path.append(map_to_world(map_coord as Vector2i))
		
	return world_path

# Converts a world position (like a mouse click) to a map grid coordinate.
func world_to_map(world_position: Vector2) -> Vector2i:
	if tile_map_layer:
		var local_pos = tile_map_layer.to_local(world_position)
		return tile_map_layer.local_to_map(local_pos)
	return Vector2i.ZERO # Return a default value if the tilemap isn't set

# Converts a map grid coordinate back to a world position (the center of the tile).
func map_to_world(map_position: Vector2i) -> Vector2:
	if tile_map_layer:
		var local_pos = tile_map_layer.map_to_local(map_position)
		return tile_map_layer.to_global(local_pos)
	return Vector2.ZERO # Return a default value if the tilemap isn't set
