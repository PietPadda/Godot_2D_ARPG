# scripts/core/grid_manager.gd
class_name GridManager
extends Node

# Our debug tile scene
@export var debug_tile_scene: PackedScene

# This will hold a reference to the main level's TileMapLayer.
var tile_map_layer: TileMapLayer

# Pathfinding
# The AStar2D object that will handle path calculations.
var astar_graph := AStar2D.new()

# These are our "address books" to translate between tile coordinates and A* IDs.
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

	# We get the bounding box of all painted tiles, so we know the area we need to search.
	var map_rect = tile_map_layer.get_used_rect()
	var walkable_cells: Array[Vector2i] = []

	# We visit every single tile within that boundary, one by one.
	for x in range(map_rect.position.x, map_rect.end.x): # loop x cells
		for y in range(map_rect.position.y, map_rect.end.y): # loop y cells
			var cell = Vector2i(x, y) # cell at x:y
			
			# THE NEW, ROBUST LOGIC:
			var tile_data = tile_map_layer.get_cell_tile_data(cell)
			
			# A cell is walkable if it's empty (no tile data)
			# OR if it has a tile, and that tile's "is_walkable" custom data is true.
			var is_walkable = false
			if not tile_data:
				is_walkable = true # Empty space is walkable
			else:
				is_walkable = tile_data.get_custom_data("is_walkable") # Check the tile's property
			if is_walkable:
				walkable_cells.append(cell)
				
	# Debug Walkable Tiles Visualisation
	if debug_tile_scene:
		var main_scene = get_tree().current_scene
		for cell in walkable_cells:
			var tile_instance = debug_tile_scene.instantiate()
			main_scene.add_child(tile_instance)
			# Center the debug tile over the grid cell
			# Note: Convert the Vector2i to a Vector2 before subtracting
			tile_instance.global_position = map_to_world(cell) - (Vector2(tile_map_layer.tile_set.tile_size) / 2)
	
	# We go through our list of walkable roads...
	# First pass: Add all walkable tiles as points to the graph.
	for cell in walkable_cells:
		 # Create a new, unique ID (0, then 1, then 2, etc.)
		var point_id = id_to_map_coords.size() # get tilemap coords
		
		# Update our address books.
		id_to_map_coords.append(cell) # add to cell, ID 50 -> (8, 6)
		map_coords_to_id[cell] = point_id # A* dict for quick lookup, (8, 6) -> ID 50
		
		# Add the "intersection" to the A* graph's map.
		astar_graph.add_point(point_id, cell) # add A* point to graph
	
	# We visit every walkable tile again.
	# Second pass: Connect adjacent points.
	for cell in walkable_cells:
		var current_point_id = map_coords_to_id[cell]
		# Get the real-world pixel position of the current tile's center.
		var current_world_pos = map_to_world(cell)
		
		# We check all 8 of its immediate neighbors (including diagonals)
		for x in range(-1, 2):
			for y in range(-1, 2):
				if x == 0 and y == 0: # Skip the center tile itself
					continue # Don't check against self
				
				var neighbor = cell + Vector2i(x, y)
				# We ask: "Is this neighbor a valid, walkable intersection we've already mapped?"
				if map_coords_to_id.has(neighbor):
					var is_diagonal = (x != 0 and y != 0)
					
					# If it's a diagonal move, check for walls.
					if is_diagonal:
						# Check if the two adjacent neighbors are also walkable.
						var neighbor_x = cell + Vector2i(x, 0)
						var neighbor_y = cell + Vector2i(0, y)
						if not map_coords_to_id.has(neighbor_x) or not map_coords_to_id.has(neighbor_y):
							continue # One of the corners is a wall, so this diagonal is invalid.
					
					# If we reach here, the connection is valid.
					var neighbor_point_id = map_coords_to_id[neighbor]
					# Get the real-world pixel position of the neighbor tile's center.
					var neighbor_world_pos = map_to_world(neighbor)
					# The weight is now the actual distance in pixels.
					var weight = current_world_pos.distance_to(neighbor_world_pos)
					# Connect the points with the correct weight.
					astar_graph.connect_points(current_point_id, neighbor_point_id, weight)

# Finds the shortest path between two points on the grid.
func find_path(start_coord: Vector2i, end_coord: Vector2i) -> PackedVector2Array:
	# First, a safety check: are the start and end points valid locations on our map?
	if not map_coords_to_id.has(start_coord) or not map_coords_to_id.has(end_coord):
		# If not, return an empty path.
		return [] # Return empty path if start/end is not a valid walkable tile

	# Use our "address book" to look up the simple IDs for our start and end tiles.
	var start_id = map_coords_to_id[start_coord]
	var end_id = map_coords_to_id[end_coord]
	
	# Get the path of MAP coordinates from the A* graph.
	var map_path = astar_graph.get_id_path(start_id, end_id)
	
	# This is the new, critical step: Convert the path of IDs to world positions.
	var world_path: PackedVector2Array = []
	for point_id in map_path:
		var map_coord = astar_graph.get_point_position(point_id)
		world_path.append(map_to_world(map_coord))
		
	return world_path

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
