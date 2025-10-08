# scripts/core/grid_manager.gd
class_name GridManager
extends Node

# Preload the Player script so we can check an object's type against it.
const Player = preload("res://scripts/player/player.gd")

# Our debug tile scene
@export var debug_tile_scene: PackedScene

# THE FIX: We now need references to both tilemaps.
var floor_tilemap: TileMapLayer
var wall_tilemap: TileMapLayer

# The level will call this to provide its tilemaps and trigger the graph build.
func register_level_tilemaps(new_floor_map: TileMapLayer, new_wall_map: TileMapLayer) -> void:
	floor_tilemap = new_floor_map
	wall_tilemap = new_wall_map
	build_level_graph()

# We can remove the old single tile_map_layer variable and its setter.
# var tile_map_layer: TileMapLayer: # <-- DELETE THIS ENTIRE BLOCK

# Pathfinding: Use AStarGrid2D
var astar_grid := AStarGrid2D.new()

# We now use TWO dictionaries to track occupation for high performance.
# The primary, authoritative source of truth.
var _occupied_cells := {} # { tile_coordinate: character_instance }
# A reverse-lookup dictionary for instant character location checks.
var _character_locations := {} # { character_instance: tile_coordinate }

# Builds the A* pathfinding graph from the floor and wall tilemaps.
func build_level_graph():
	if not is_instance_valid(floor_tilemap) or not is_instance_valid(wall_tilemap):
		push_error("GridManager: Tilemap references are not valid.")
		return
		
	# Clear all old points and connections from the previous level's graph.
	astar_grid.clear()

	# Set up the AStarGrid2D with our map's data
	# TGet the bounding box for both tilemaps.
	var floor_rect = floor_tilemap.get_used_rect()
	var wall_rect = wall_tilemap.get_used_rect()
	
	# Merge them into a single rectangle that covers the entire level.
	var map_rect = floor_rect.merge(wall_rect)
	
	astar_grid.region = map_rect
	astar_grid.cell_size = Vector2(1, 1) # We use a 1-to-1 mapping
	
	# HEURISTIC_OCTILE is generally best for 8-directional grids.
	astar_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	
	# This is the key change to prevent zig-zagging on isometric "straight" lines.
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	astar_grid.update()
	
	# Iterate over every cell in the map.
	for x in range(map_rect.position.x, map_rect.end.x): # loop x cells
		for y in range(map_rect.position.y, map_rect.end.y): # loop y cells
			var cell = Vector2i(x, y) # cell at x:y
			# A cell is walkable if it's empty (no tile data)
			# OR if it has a tile, and that tile's "is_walkable" custom data is true.
			var is_walkable = true # Assume the cell is walkable by default.
			
			# Rule 1: Is there a wall here? If so, it's not walkable.
			if wall_tilemap.get_cell_source_id(cell) != -1:
				is_walkable = false
			else:
				# Rule 2: No wall, so is there a floor?
				# We must specify the tilemap layer index, which is 0.
				var floor_tile_data = floor_tilemap.get_cell_tile_data(cell)
				if not floor_tile_data:
					# No floor tile. We'll treat this as walkable for now.
					is_walkable = true
				else:
					# Rule 3: There is a floor. Use its custom data property.
					is_walkable = floor_tile_data.get_custom_data("is_walkable")

			# If a tile is NOT walkable, then it is a solid point.
			if not is_walkable:
				astar_grid.set_point_solid(cell)
				
	# Update the debug visualization to use the floor_tilemap.
	if debug_tile_scene:
		# --- THE FIX ---
		# Get the actual active level from our SceneManager.
		var level = Scene.current_level
		if not is_instance_valid(level):
			push_error("GridManager: Cannot spawn debug tiles, Scene.current_level is invalid.")
			return
			
		for x in range(map_rect.position.x, map_rect.end.x):
			for y in range(map_rect.position.y, map_rect.end.y):
				var cell = Vector2i(x, y)
				if not astar_grid.is_point_solid(cell):
					var tile_instance = debug_tile_scene.instantiate()
					level.add_child(tile_instance)
					# Use the floor_tilemap for coordinate conversion.
					var tile_size = floor_tilemap.tile_set.tile_size
					tile_instance.global_position = map_to_world(cell) - (Vector2(tile_size) / 2)

# Finds the shortest path between two points on the grid, avoiding dynamic obstacles.
# We pass the character requesting the path so it doesn't consider its own tile an obstacle.
func find_path(start_coord: Vector2i, end_coord: Vector2i, pathing_character: Node = null) -> PackedVector2Array:
	# Temporarily mark occupied cells as solid for this calculation.
	var temporarily_solid_points: Array[Vector2i] = []
	
	# We now use different logic for the server vs. the client.
	if multiplayer.is_server():
		# SERVER LOGIC: The server is the authority and MUST use its internal
		# state (_occupied_cells) for all pathfinding. This is the source of truth.
		# Mark OCCUPIED cells as temporary obstacles
		for cell in _occupied_cells:
			var character = _occupied_cells[cell]
			# Make sure we don't mark the pathing character's own tile as an obstacle.
			if character != pathing_character:
				if not astar_grid.is_point_solid(cell) and cell != end_coord:
					astar_grid.set_point_solid(cell, true)
					temporarily_solid_points.append(cell)
	else:
		# CLIENT LOGIC: The client should pathfind around what it SEES.
		# It iterates through synchronized nodes for the most up-to-date visuals.
		for character in get_tree().get_nodes_in_group("characters"):
			if character != pathing_character:
				var cell = world_to_map(character.global_position)
				if not astar_grid.is_point_solid(cell) and cell != end_coord:
					astar_grid.set_point_solid(cell, true)
					temporarily_solid_points.append(cell)
	
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

# This function is called by a character's state machine when it needs a path.
func request_path(start_coord: Vector2i, end_coord: Vector2i, character: Node) -> void:
	# --- NEW LOGIC FOR PLAYERS ---
	if character is Player and character.is_multiplayer_authority():
		# This code runs for OUR player on our machine (client or host).
		# First, find a path locally. This will automatically avoid any synchronized enemies.
		var local_path = find_path(start_coord, end_coord, character)
		
		if not local_path.is_empty():
			# We have a valid local path. Now, send it to the server for the official "ticket".
			server_request_player_path.rpc_id(1, character.get_path(), local_path)
		return

	# --- EXISTING LOGIC FOR ENEMIES (SERVER-ONLY) ---
	# The server will still calculate paths for its enemies directly.
	if not multiplayer.is_server():
		# A client should never be trying to pathfind for an enemy.
		return
		
	# Generate a potential path.
	var final_path: PackedVector2Array = [] # This will be the path we actually send.
	
	# Generate a potential path.
	var full_path = find_path(start_coord, end_coord, character)
	
	# ENEMY LOGIC: Return a single, reserved step to prevent stacking.
	if full_path.size() > 1:
		# The first element (index 0) is our current tile.
		# The second element (index 1) is the first actual step we need to take.
		var first_step_world_pos = full_path[1]
		var next_tile = world_to_map(first_step_world_pos)
		# We call occupy_tile LOCALLY, not as an RPC.
		var success = occupy_tile(character, next_tile) 
		if success:
			# If we successfully reserved the tile, add that step to our path.
			final_path.append(first_step_world_pos)
	
	# Give the final path (just one step) to the enemy.
	var movement_component = character.get_node_or_null("GridMovementComponent")
	if movement_component:
		movement_component.move_along_path(final_path)
	
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
	if is_instance_valid(floor_tilemap):
		var local_pos = floor_tilemap.to_local(world_position)
		return floor_tilemap.local_to_map(local_pos)
	return Vector2i.ZERO # Return a default value if the tilemap isn't set

# Converts a map grid coordinate back to a world position (the center of the tile).
func map_to_world(map_position: Vector2i) -> Vector2:
	if is_instance_valid(floor_tilemap):
		var local_pos = floor_tilemap.map_to_local(map_position)
		return floor_tilemap.to_global(local_pos)
	return Vector2.ZERO # Return a default value if the tilemap isn't set
	
# This is now the ONLY way to claim a tile. It's atomic on the server.
# Now updates both dictionaries for atomic, high-speed operations.
func occupy_tile(character: Node, new_tile: Vector2i) -> bool:
	# Check if the new tile is occupied by SOMEONE ELSE.
	if _occupied_cells.has(new_tile) and _occupied_cells[new_tile] != character:
		return false # Failure: Tile is taken by another character.

	# Find and release the character's old tile using our fast lookup.
	if _character_locations.has(character):
		var old_tile = _character_locations[character]
		_occupied_cells.erase(old_tile)
		
	# Occupy the new tile in both dictionaries.
	_occupied_cells[new_tile] = character
	_character_locations[character] = new_tile
	return true # Success!
	
# A simple helper to free a tile when a character moves off it.
# Uses the fast lookup dictionary.
func release_tile(tile: Vector2i):
	if _occupied_cells.has(tile):
		var character = _occupied_cells[tile]
		_occupied_cells.erase(tile)
		_character_locations.erase(character)

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
	
# When a character spawns, they occupy their starting tile.
@rpc("any_peer", "call_local")
func update_character_position(character_path: NodePath, new_position: Vector2i):
	# On the server, we get the node using the path sent by the client.
	var character = get_node_or_null(character_path)
	if not is_instance_valid(character):
		return # If the character isn't found (e.g., just died), do nothing.
		
	# On spawn, just occupy the tile directly.
	occupy_tile(character, new_position)
	
# We can now REMOVE the old RPC functions for pathfinding, as our new
# "Ticket to Ride" RPCs have replaced them.

# DELETE the function _find_path_on_server
# DELETE the function _receive_path_from_server
			
# This RPC completely removes a character from all grid tracking systems.
@rpc("any_peer", "call_local")
func clear_character_from_grid(character_path: NodePath) -> void:
	var character = get_node_or_null(character_path)
	# It's possible the character is already gone, so we must check if it's valid.
	if not is_instance_valid(character):
		return # Do nothing if the character node is already deleted.
	
	# Use our new, high-speed lookup dictionary.
	if _character_locations.has(character):
		var tile_to_free = _character_locations[character]
		_occupied_cells.erase(tile_to_free)
		_character_locations.erase(character)

# NEW RPC: Called by a player's client to ask for permission for the next step.
@rpc("any_peer", "call_local")
func server_player_request_tile(character_path: NodePath, requested_tile: Vector2i) -> void:
	var character = get_node_or_null(character_path)
	if not is_instance_valid(character): return

	var client_id = multiplayer.get_remote_sender_id()

	# Our existing occupy_tile function is already atomic and perfect for this.
	var success = occupy_tile(character, requested_tile)

	if success:
		# Approved. Tell the client they can proceed.
		client_confirm_player_move.rpc_id(client_id, character_path, requested_tile)
	else:
		# Denied. Tell the client their path is blocked.
		client_reject_player_move.rpc_id(client_id, character_path)

# NEW RPC: Sent from the server to the client to confirm a move.
@rpc("authority")
func client_confirm_player_move(character_path: NodePath, confirmed_tile: Vector2i) -> void:
	var character = get_node_or_null(character_path)
	# Ensure this code only runs on the machine that controls the character.
	if is_instance_valid(character) and character.is_multiplayer_authority():
		var movement_component = character.get_node_or_null("GridMovementComponent")
		if movement_component:
			# We'll create this function in the next step.
			movement_component._execute_approved_move(confirmed_tile)

# NEW RPC: Sent from the server to the client to reject a move.
@rpc("authority")
func client_reject_player_move(character_path: NodePath) -> void:
	var character = get_node_or_null(character_path)
	# Ensure this code only runs on the machine that controls the character.
	if is_instance_valid(character) and character.is_multiplayer_authority():
		var movement_component = character.get_node_or_null("GridMovementComponent")
		if movement_component:
			# We'll create this function in the next step.
			movement_component._handle_rejected_move()

# RPC for a client to request validation for a complete path.
@rpc("any_peer", "call_local")
func server_request_player_path(character_path: NodePath, path_points: PackedVector2Array) -> void:
	var character = get_node_or_null(character_path)
	if not is_instance_valid(character): 
		return

	var client_id = multiplayer.get_remote_sender_id()
	
	# For now, we'll keep the validation simple. The main goal is preventing
	# players from stacking on the same destination tile.
	var final_path = path_points
	
	# If the client sends us an empty path, we just send it back. No validation needed.
	if final_path.is_empty():
		client_receive_approved_path.rpc_id(client_id, character_path, final_path)
		return

	# Get the last element using the correct index: array.size() - 1
	var destination_world_pos = final_path[final_path.size() - 1]
	var destination_tile = world_to_map(destination_world_pos)
	
	# We check if the destination is occupied by someone OTHER than the character requesting the move.
	if _occupied_cells.has(destination_tile) and _occupied_cells[destination_tile] != character:
		# If the destination is occupied, for now we'll just deny the move by returning an empty path.
		final_path.clear()
	else:
		# The destination is clear, so we "reserve" it by occupying it immediately.
		# This prevents a race condition where two players request the same destination.
		occupy_tile(character, destination_tile)

	# Send the approved (or empty) path back to the requesting client.
	# Check if the request came from the server itself (the host, ID 1).
	if client_id == 1:
		# It's the host. Call the movement function directly instead of via RPC.
		var movement_component = character.get_node_or_null("GridMovementComponent")
		if movement_component:
			# The logic from our 'client_receive_approved_path' RPC is now called directly.
			movement_component.move_along_path(final_path)
	else:
		# It's a remote client. Send the RPC as we were before.
		client_receive_approved_path.rpc_id(client_id, character_path, final_path)

# RPC for the server to send the validated path back to the client.
@rpc("authority")
func client_receive_approved_path(character_path: NodePath, approved_path: PackedVector2Array) -> void:
	var character = get_node_or_null(character_path)
	if is_instance_valid(character) and character.is_multiplayer_authority():
		var movement_component = character.get_node_or_null("GridMovementComponent")
		if movement_component:
			# This will kick off the smooth tween on the client. We'll implement the details next.
			movement_component.move_along_path(approved_path)


# RPC for the client to inform the server of its new tile position mid-path.
# This is "unreliable" - it's a fire-and-forget update.
@rpc("any_peer", "call_local", "unreliable")
func server_update_player_tile(character_path: NodePath, new_tile: Vector2i) -> void:
	var character = get_node_or_null(character_path)
	if is_instance_valid(character):
		# This is the core of our authority. The server updates its grid based on client info.
		occupy_tile(character, new_tile)
		
# This is our new, reliable function for the final tile update.
# It ensures the server ALWAYS receives the character's final position.
@rpc("any_peer", "call_local", "reliable")
func server_report_final_player_tile(character_path: NodePath, final_tile: Vector2i) -> void:
	var character = get_node_or_null(character_path)
	if is_instance_valid(character):
		# The logic is the same, but the delivery is guaranteed.
		occupy_tile(character, final_tile)
