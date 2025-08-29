# scripts/core/grid_manager.gd
class_name GridManager
extends Node

# This will hold a reference to the main level's TileMapLayer.
var tile_map_layer: TileMapLayer

# Pathfinding
# The AStar2D object that will handle path calculations.
var astar_graph := AStar2D.new()
# A dictionary to quickly look up a tile's unique ID for the A* graph.
var map_coords_to_id: Dictionary = {}
# An array to convert a point ID from the A* graph back to a tile coordinate.
var id_to_map_coords: Array = []

# Builds the A* point graph from the level's TileMapLayer.
func build_level_graph():
	# Clear any old data
	astar_graph.clear()
	map_coords_to_id.clear()
	id_to_map_coords.clear()

	if not tile_map_layer:
		push_error("GridManager: TileMapLayer not set!")
		return
		
	# This is the physics space we will query against.
	var space_state = tile_map_layer.get_world_2d().direct_space_state
	# We need to configure the query parameters. We only want to check against the 'world' layer.
	var query_params = PhysicsPointQueryParameters2D.new()
	query_params.collision_mask = 1 # Physics Layer 1 is our "world" layer for walls.

	# checks every tile within the map's bounds.
	var map_rect = tile_map_layer.get_used_rect()
	var walkable_cells: Array[Vector2i] = []

	# Iterate over every cell within the map's boundaries.
	for x in range(map_rect.position.x, map_rect.end.x): # loop x cells
		for y in range(map_rect.position.y, map_rect.end.y): # loop y cells
			var cell = Vector2i(x, y) # cell at x:y
			# Set the query's position to the center of the current tile.
			query_params.position = map_to_world(cell)
			# Perform the physics query.
			var result = space_state.intersect_point(query_params)
			# If the result is empty, it means no colliders were found. The tile is walkable!
			if result.is_empty():
				walkable_cells.append(cell)
				
	# First pass: Add all walkable tiles as points to the graph.
	for cell in walkable_cells:
		var point_id = id_to_map_coords.size() # get tilemap coords
		id_to_map_coords.append(cell) # add to cell
		map_coords_to_id[cell] = point_id # A* dict for quick lookup
		astar_graph.add_point(point_id, cell) # add A* point to graph
	
	# Second pass: Connect adjacent points.
	for cell in walkable_cells:
		var current_point_id = map_coords_to_id[cell]
		# Check all 8 neighbors (including diagonals)
		for x in range(-1, 2):
			for y in range(-1, 2):
				if x == 0 and y == 0:
					continue # Don't check against self
				
				var neighbor = cell + Vector2i(x, y)
				if map_coords_to_id.has(neighbor):
					var neighbor_point_id = map_coords_to_id[neighbor]
					# Connect the points so the graph knows they are neighbors.
					astar_graph.connect_points(current_point_id, neighbor_point_id)

# Finds the shortest path between two points on the grid.
func find_path(start_coord: Vector2i, end_coord: Vector2i) -> PackedVector2Array:
	if not map_coords_to_id.has(start_coord) or not map_coords_to_id.has(end_coord):
		return [] # Return empty path if start/end is not a valid walkable tile

	var start_id = map_coords_to_id[start_coord]
	var end_id = map_coords_to_id[end_coord]
	
	# This returns an array of world positions, which is what we need for movement.
	return astar_graph.get_point_path(start_id, end_id)

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
