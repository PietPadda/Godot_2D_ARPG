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

# Finds the path between two world positions.
func find_path(start_world_pos: Vector2, end_world_pos: Vector2) -> PackedVector2Array:
	# Find the closest valid graph points to our start and end positions.
	var start_vertex = _get_closest_valid_vertex(start_world_pos)
	var end_vertex = _get_closest_valid_vertex(end_world_pos)
	
	if not map_coords_to_id.has(start_vertex) or not map_coords_to_id.has(end_vertex):
		# If not, return an empty path.
		return [] # No valid start or end point found.

	# Use our "address book" to look up the simple IDs for our start and end tiles.
	var start_id = map_coords_to_id[start_vertex]
	var end_id = map_coords_to_id[end_vertex]
	
	# Get the path of MAP coordinates from the A* graph.
	var map_path = astar_graph.get_id_path(start_id, end_id)
	
	#  The A* graph now returns world positions directly.
	return astar_graph.get_point_path(start_id, end_id)
	
# Converts a world position to its closest map vertex coordinate.
func world_to_map_vertex(world_position: Vector2) -> Vector2i:
	if tile_map_layer:
		# First, find the tile the position is on.
		var tile_coord = tile_map_layer.local_to_map(tile_map_layer.to_local(world_position))
		# Then, find the closest of that tile's 4 vertices.
		var closest_vertex = Vector2i.ZERO
		var min_dist_sq = INF
		
		# Check the 4 vertices around a tile's center
		for x in range(2):
			for y in range(2):
				var vertex_coord = tile_coord + Vector2i(x, y)
				var vertex_world_pos = map_to_world(vertex_coord)
				var dist_sq = world_position.distance_squared_to(vertex_world_pos)
				if dist_sq < min_dist_sq:
					min_dist_sq = dist_sq
					closest_vertex = vertex_coord
		return closest_vertex
	return Vector2i.ZERO

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
		# Must convert from local to global space.
		return tile_map_layer.to_global(local_pos)
	return Vector2.ZERO # Return a default value if the tilemap isn't set
	
# Helper to find the nearest valid point on our graph to a given world position.
func _get_closest_valid_vertex(world_pos: Vector2) -> Vector2i:
	var closest_vertex = Vector2i.ZERO
	var min_dist_sq = INF
	
	# This is a simple brute-force search. For very large maps, this could be optimized.
	for vertex in map_coords_to_id:
		var vertex_world_pos = map_to_world(vertex)
		var dist_sq = world_pos.distance_squared_to(vertex_world_pos)
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			closest_vertex = vertex
	return closest_vertex
