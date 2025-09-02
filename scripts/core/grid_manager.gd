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
	# Phase 0: Clear old data
	astar_graph.clear()
	map_coords_to_id.clear()
	id_to_map_coords.clear()

	if not tile_map_layer:
		push_error("GridManager: TileMapLayer not set!")
		return

	# We get the bounding box of all painted tiles, so we know the area we need to search.
	var map_rect = tile_map_layer.get_used_rect()
	var valid_vertices: Dictionary = {}
	
	# Phase 1: Find all valid vertices
	# A vertex is valid if all 4 surrounding tiles are walkable.
	for x in range(map_rect.position.x, map_rect.end.x + 1): # loop x cells
		for y in range(map_rect.position.y, map_rect.end.y + 1): # loop y cells
			var vertex  = Vector2i(x, y) # cell at x:y
			
			# Check the four tiles that meet at this vertex.
			var top_left = tile_map_layer.get_cell_tile_data(vertex + Vector2i(-1, -1))
			var top_right = tile_map_layer.get_cell_tile_data(vertex + Vector2i(0, -1))
			var bot_left = tile_map_layer.get_cell_tile_data(vertex + Vector2i(-1, 0))
			var bot_right = tile_map_layer.get_cell_tile_data(vertex + Vector2i(0, 0))
			
			var tl_walkable = (not top_left) or top_left.get_custom_data("is_walkable")
			var tr_walkable = (not top_right) or top_right.get_custom_data("is_walkable")
			var bl_walkable = (not bot_left) or bot_left.get_custom_data("is_walkable")
			var br_walkable = (not bot_right) or bot_right.get_custom_data("is_walkable")
			
			if tl_walkable and tr_walkable and bl_walkable and br_walkable:
				var point_id = id_to_map_coords.size()
				id_to_map_coords.append(vertex)
				map_coords_to_id[vertex] = point_id
				astar_graph.add_point(point_id, map_to_world(vertex))
				valid_vertices[vertex] = point_id
				
	# Debug Walkable Tiles Visualisation
	if debug_tile_scene:
		var main_scene = get_tree().current_scene
		for cell in valid_vertices:
			var tile_instance = debug_tile_scene.instantiate()
			main_scene.add_child(tile_instance)
			# Center the debug tile over the grid cell
			# Note: Convert the Vector2i to a Vector2 before subtracting
			tile_instance.global_position = map_to_world(cell) - (Vector2(tile_map_layer.tile_set.tile_size) / 2)

	# Phase 2: Connect adjacent valid vertices
	for vertex in valid_vertices:
		var current_point_id = valid_vertices[vertex]
		var current_world_pos = map_to_world(vertex)
		
		# Check the 4 cardinal neighbors (up, down, left, right on the vertex grid).
		var neighbors = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		for offset in neighbors:
			var neighbor = vertex + offset
			if valid_vertices.has(neighbor):
				var neighbor_point_id = valid_vertices[neighbor]
				var neighbor_world_pos = map_to_world(neighbor)
				
				# The weight is the actual world distance between vertices.
				var weight = current_world_pos.distance_to(neighbor_world_pos)
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

# Converts a map grid coordinate back to a world position (the corner of the tile)
func map_to_world(map_position: Vector2i) -> Vector2:
	if tile_map_layer:
		# Use map_to_local, which for isometric maps points to the corner.
		var local_pos = tile_map_layer.map_to_local(map_position)
		return tile_map_layer.to_global(local_pos)
	return Vector2.ZERO # Return a default value if the tilemap isn't set
