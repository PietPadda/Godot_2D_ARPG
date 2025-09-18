# scripts/core/grid_manager.gd
class_name GridManager
extends Node

# Preload the Player script so we can check an object's type against it.
const Player = preload("res://scripts/player/player.gd")

# Our debug tile scene
@export var debug_tile_scene: PackedScene

# We'll use a dictionary to keep track of which character is on which tile.
# The structure will be: { character_instance: tile_coordinate }
var _occupied_cells := {}
# We can now completely remove the reservation system.
# var _reserved_cells := {} # <-- DELETE THIS

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

# Finds the shortest path between two points on the grid, avoiding dynamic obstacles.
# We pass the character requesting the path so it doesn't consider its own tile an obstacle.
func find_path(start_coord: Vector2i, end_coord: Vector2i, pathing_character: Node = null) -> PackedVector2Array:
	# Temporarily mark occupied cells as solid for this calculation.
	var temporarily_solid_points: Array[Vector2i] = []
	
	# Mark OCCUPIED cells as temporary obstacles
	for character in _occupied_cells:
		# Make sure we don't mark the pathing character's own tile as an obstacle.
		if character != pathing_character:
			# Get the list of tiles this character occupies.
			# We cast the dictionary value to a generic Array.
			# Godot knows it's an array, but the type hint needs this for safety.
			var occupied_tiles: Array = _occupied_cells[character]
			for cell in occupied_tiles:
				if not astar_grid.is_point_solid(cell) and cell != end_coord:
					astar_grid.set_point_solid(cell, true)
					temporarily_solid_points.append(cell)
	
	# We no longer need to check _reserved_cells.
	# <-- DELETE the reservation loop that was here.
	
	# AStarGrid2D returns an array of map coordinates directly.
	var map_path: PackedVector2Array = astar_grid.get_point_path(start_coord, end_coord)
	
	# CRITICAL: Clean up by reverting the temporarily solid points back to walkable.
	for cell in temporarily_solid_points:
		astar_grid.set_point_solid(cell, false)
	
	# Convert the path of map coordinates to world positions.
	var world_path: PackedVector2Array = []
	for map_coord in map_path:
		world_path.append(map_to_world(map_coord as Vector2i))
		
	return world_path

# This new function handles the logic for both host and clients.
# This is the function that is called by the State Machine's _recalculate_path()
func request_path(start_coord: Vector2i, end_coord: Vector2i, character: Node) -> void:
	# This function now ONLY runs on the server.
	# If we're a client, we send the request and do nothing else locally.
	if not multiplayer.is_server():
		_find_path_on_server.rpc_id(1, start_coord, end_coord, character.get_path())
		return
		
	# --- The below ONLY run on the HOST ---
	# Generate a potential path.
	var path = find_path(start_coord, end_coord, character)
	
	# If a path was found, ATOMICALLY check and occupy the first step.
	if not path.is_empty():
		var next_tile = world_to_map(path[0])
		# We call occupy_tile LOCALLY, not as an RPC.
		var success = occupy_tile(character.get_path(), next_tile) 
		
		if not success:
			# The first step was already blocked! This path is invalid.
			# Clear the path so the character knows to wait and try again.
			path.clear()
	
	# Deliver the final, validated (or empty) path to the character.
	if character.is_multiplayer_authority(): # Is it the host's character?
		# If the character is controlled by me (the host's player or an enemy), apply the path directly.
		var movement_component = character.get_node_or_null("GridMovementComponent")
		if movement_component:
			movement_component.move_along_path(path)
	else: # It's a client's character.
		# If the character is controlled by a client, find their ID...
		var client_id = character.get_multiplayer_authority()
		# ...and send the path back to them via RPC.
		_receive_path_from_server.rpc_id(client_id, start_coord, end_coord, character.get_path())
	
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
	# This is a simplified check. In a real game, you'd want to have a more
	# robust system for tracking occupied tiles.
	for body in get_tree().get_nodes_in_group("characters"):
		if body.has_method("get_node_or_null") and is_instance_valid(body): # Safety check
			if Grid.world_to_map(body.global_position) == tile:
				return false
	return true
	
# A function for a character to announce it has been removed from the game (e.g., on death).
func remove_character(character: Node):
	if _occupied_cells.has(character):
		_occupied_cells.erase(character)

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

# --- Tile Reservation API ---
# We remove the entire Tile Reservation API section.
# func reserve_tile(...) # <-- DELETE
# func release_tile_reservation(...) # <-- DELETE

# --- Debug ---
# A debug function to print the contents of our occupied cells registry.
func print_occupied_cells() -> void:
	print("GridManager Knowledge Check (Players Only):")
	if _occupied_cells.is_empty():
		print("  - Occupied cells registry is EMPTY.")
		return
		
	var players_found = 0
	for character in _occupied_cells:
		# THE CHANGE IS HERE: We only print if the character is a Player.
		if character is Player:
			players_found += 1
			var tile = _occupied_cells[character]
			print("  - Player '%s' is at tile %s" % [character.name, tile])
	
	if players_found == 0:
		print("  - No players found in the registry.")

# --- RPCs ---
# This function is now much simpler. It just sets the initial occupied tile.
@rpc("any_peer", "call_local")
func update_character_position(character_path: NodePath, new_position: Vector2i):
	# On the server, we get the node using the path sent by the client.
	var character = get_node_or_null(character_path)
	if not is_instance_valid(character):
		return # If the character isn't found (e.g., just died), do nothing.
		
	# On initial spawn, a character occupies one tile.
	_occupied_cells[character] = [new_position]
	
# This function ONLY runs on the server, as requested by a client.
# We change the annotation to allow calls from ANY client.
@rpc("any_peer", "call_local")
func _find_path_on_server(start_coord: Vector2i, end_coord: Vector2i, character_path: NodePath) -> void:
	# Get the peer ID of the client who made the request.
	var client_id = multiplayer.get_remote_sender_id()
	
	var character = get_node_or_null(character_path)
	if not is_instance_valid(character):
		return

	# Calculate the path using the server's authoritative data.
	var path = find_path(start_coord, end_coord, character)

	# THE FIX: We send the character_path BACK along with the path.
	# This tells the client who this path is for.
	_receive_path_from_server.rpc_id(client_id, path, character_path)

# This function ONLY runs on a client, as a response from the server.
# It receives the final path from the server.
@rpc("authority")
func _receive_path_from_server(path: PackedVector2Array, character_path: NodePath) -> void:
	# THE FIX: We no longer just print. We find the character and give it the path.
	var character = get_node_or_null(character_path)
	if is_instance_valid(character):
		var movement_component = character.get_node_or_null("GridMovementComponent")
		if is_instance_valid(movement_component):
			# This is the final step. We tell the client's character to start moving.
			movement_component.move_along_path(path)
			
# This RPC completely removes a character from all grid tracking systems.
@rpc("any_peer", "call_local")
func clear_character_from_grid(character_path: NodePath) -> void:
	var character = get_node_or_null(character_path)

	if not is_instance_valid(character):
		# If the character is already gone, try to find it in the dictionaries by value.
		# This is a fallback for tricky timing situations.
		for key in _occupied_cells:
			if key.get_path() == character_path:
				_occupied_cells.erase(key)
				break
		return

	# If the character is valid, remove it the normal way.
	var old_position_keys = _occupied_cells.keys().filter(func(key): return key == character)
	for key in old_position_keys:
		_occupied_cells.erase(key)

# Tries to add a tile to a character's occupied list.
# We also need to fix our occupy_tile RPC to be callable locally by the server.
@rpc("any_peer", "call_local")
func occupy_tile(character_or_path, tile: Vector2i) -> bool:
	var character: Node
	if character_or_path is NodePath:
		character = get_node_or_null(character_or_path)
	else:
		character = character_or_path

	# Check if the desired tile is occupied by SOMEONE ELSE.
	for other_character in _occupied_cells:
		if other_character != character:
			if _occupied_cells[other_character].has(tile):
				return false # Tile is occupied by another character.

	# First, ensure this character has an entry in our dictionary.
	# If it doesn't, create an empty one.
	if not _occupied_cells.has(character):
		_occupied_cells[character] = []
	
	# Now it's safe to check
	# If the tile is free, add it to this character's list.
	if not _occupied_cells[character].has(tile):
		_occupied_cells[character].append(tile)
	return true

# Removes a specific tile from a character's occupied list.
@rpc("any_peer", "call_local")
func release_occupied_tile(character_path: NodePath, tile: Vector2i) -> void:
	var character = get_node_or_null(character_path)
	if not is_instance_valid(character): return
	
	if _occupied_cells.has(character):
		_occupied_cells[character].erase(tile)

# Wipes a character's occupied list and resets it to only their current tile.
@rpc("any_peer", "call_local")
func release_all_but_current_tile(character_path: NodePath, current_tile: Vector2i):
	var character = get_node_or_null(character_path)
	if is_instance_valid(character):
		# Simply overwrite their list with a new one containing only their current tile.
		_occupied_cells[character] = [current_tile]
