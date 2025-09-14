# scripts/core/grid_manager.gd
class_name GridManager
extends Node

# Our debug tile scene
@export var debug_tile_scene: PackedScene

# This will hold a reference to the current level's TileMapLayer.
# Convert the variable into a property with a setter.
var tile_map_layer: TileMapLayer:
	set(value):
		tile_map_layer = value
		# If the new value is valid, automatically rebuild the graph.
		if is_instance_valid(tile_map_layer):
			# We still defer to ensure the tilemap is fully ready in the scene tree.
			call_deferred("build_level_graph")
		else:
			# This helps us see if we're ever setting it to an invalid node.
			print("GridManager: WARNING - tile_map_layer was set to an invalid instance.")

# Pathfinding: Use AStarGrid2D
var astar_grid := AStarGrid2D.new()

# Builds the A* pathfrom the level's TileMapLayer.
func build_level_graph():
	if not is_instance_valid(tile_map_layer):
		push_error("GridManager: Attempted to build graph with an invalid TileMapLayer.")
		return
		
	# Clear all old points and connections from the previous level's graph.
	astar_grid.clear()

	# Set up the AStarGrid2D with our map's data
	var map_rect = tile_map_layer.get_used_rect()
	astar_grid.region = map_rect
	astar_grid.cell_size = Vector2(1, 1) # We use a 1-to-1 mapping
	
	# HEURISTIC_OCTILE is generally best for 8-directional grids.
	astar_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	
	# This is the key change to prevent zig-zagging on isometric "straight" lines.
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
	
# Returns an array of the four cardinal tiles adjacent to the given tile.
# Using 4 directions is more stable for grid pathfinding than 8.
func get_adjacent_tiles(tile: Vector2i) -> Array[Vector2i]:
	var adjacent_tiles: Array[Vector2i] = [] # init
	adjacent_tiles.append(tile + Vector2i.UP)
	adjacent_tiles.append(tile + Vector2i.DOWN)
	adjacent_tiles.append(tile + Vector2i.LEFT)
	adjacent_tiles.append(tile + Vector2i.RIGHT)
	return adjacent_tiles # returns all adjacent tiles

# Checks if a given tile is currently occupied by a character
func is_tile_vacant(tile: Vector2i) -> bool:
	print("[GridManager] ==> checking if tile is vacant")
	# This is a simplified check. In a real game, you'd want to have a more
	# robust system for tracking occupied tiles.
	for body in get_tree().get_nodes_in_group("characters"):
		if body.has_method("get_node_or_null") and is_instance_valid(body): # Safety check
			if Grid.world_to_map(body.global_position) == tile:
				print("[GridManager] ==> tile is NOT vacant")
				return false
	print("[GridManager] ==> tile is VACANT! :)")
	return true

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
