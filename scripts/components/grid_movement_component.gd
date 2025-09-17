# grid_movement_component.gd
# A component that moves its parent CharacterBody2D to a SINGLE target position.
class_name GridMovementComponent
extends Node

# Emitted when the character has arrived at its target.
signal path_finished
# This signal will be emitted each time the component reaches a waypoint in its path.
signal waypoint_reached

# Preload the Player script to make the "Player" type available for our type check.
const Player = preload("res://scripts/player/player.gd")

# Component References
@onready var stats_component: StatsComponent = owner.get_node("StatsComponent")

# Pathfinding State
var move_path: PackedVector2Array = []
# This flag will act as our "lock" to prevent interruptions.
var is_moving: bool = false
# We need a reference to the actual chase target, not just the waypoints.
# We'll add a variable to hold it.
var chase_target: Node2D

# We'll use this to track the character's current position on the grid.
var _current_tile: Vector2i
# We need to remember the tile we just left, so we can release it.
var _previous_tile: Vector2i
# We will keep a direct reference to our active tween.
var _active_tween: Tween

func _ready() -> void:
	# We must wait a frame for the multiplayer authority to be assigned.
	await owner.tree_entered
	
	# Only the machine that controls this character should send its initial position.
	if owner.is_multiplayer_authority():
		# Initial position update when the character first enters the scene.
		_current_tile = Grid.world_to_map(owner.global_position)
		_previous_tile = _current_tile
		# Send the initial position via RPC to the server (player ID 1).
		Grid.update_character_position.rpc_id(1, owner.get_path(), _current_tile)

# Public API
# Starts moving the character along a given path.
func move_along_path(path: PackedVector2Array, new_chase_target: Node2D = null) -> void:
	chase_target = new_chase_target
	# If the new path is empty, it's a command to stop.
	if path.is_empty():
		stop()
		emit_signal("path_finished")
		return
	
	# set new path
	move_path = path
	
	# Safety check to discard the first waypoint if we're already on it.
	if not move_path.is_empty():
		var first_point_tile = Grid.world_to_map(move_path[0])
		var current_pos_tile = Grid.world_to_map(owner.global_position)
		if first_point_tile == current_pos_tile:
			move_path.remove_at(0) # If so, discard it.
	
	# If there's still a path to follow, start the movement sequence.
	if not move_path.is_empty():
		_start_next_move_step()
	else:
		stop()
		emit_signal("path_finished")

# Stops all current movement immediately.
func stop() -> void:
	# When stopped, kill any active tween to prevent further movement.
	if is_instance_valid(_active_tween):
		_active_tween.kill()
	
	# When we stop, we should release all occupied tiles except our current one.
	if owner.is_multiplayer_authority():
		Grid.release_all_but_current_tile.rpc_id(1, owner.get_path(), _current_tile)
		
	move_path.clear() # clear the current path
	is_moving = false # set to no longer moving
	owner.velocity = Vector2.ZERO # Ensure physics velocity is also stopped
	
# Internal Logic
# This function now creates and starts the Tween for one step of the path.
func _start_next_move_step() -> bool:
	# Kill the previous tween before starting a new one.
	if is_instance_valid(_active_tween):
		_active_tween.kill()
	
	# if move path is finished
	if move_path.is_empty():
		is_moving = false
		return false # and end (bool allows func call)
	
	# "Peek" at the next waypoint's tile.
	var next_tile = Grid.world_to_map(move_path[0])
		
	# Proactively occupy the next tile. We send the request to the server.
	if owner.is_multiplayer_authority():
		# We will create this occupy_tile RPC in the GridManager next.
		Grid.occupy_tile.rpc_id(1, owner.get_path(), next_tile)
	
	# NOTE: We are assuming the occupation will succeed. The server is the authority.
	is_moving = true # still moving
	
	# PackedVector2Array doesn't have pop_front().
	# We get the target at index 0, then remove it.
	var target_world_pos = move_path[0]
	move_path.remove_at(0)
	
	var move_speed = stats_component.get_total_stat("move_speed")
	var distance = owner.global_position.distance_to(target_world_pos)
	
	# Prevent division by zero.
	if move_speed <= 0: 
		return false 
	var duration = distance / move_speed
	
	# Assign the new tween to our reference variable.
	_active_tween = create_tween().set_trans(Tween.TRANS_LINEAR)
	_active_tween.tween_property(owner, "global_position", target_world_pos, duration)
	# When the tween finishes, call our arrival function.
	_active_tween.tween_callback(_on_move_step_finished) # Call this function when done.
	return true # continue moving (bool allows func call)

# This is our new "arrival" function. It's called when the tween is done.
func _on_move_step_finished():
	# We only update our logical tiles AFTER the move is complete.
	# Our "previous" tile is now the tile we were just on.
	_previous_tile = _current_tile
	# Our "current" tile is now the one we just arrived at.
	_current_tile = Grid.world_to_map(owner.global_position)
	
	# NOW we can authoritatively release the actual previous tile.
	if owner.is_multiplayer_authority():
		Grid.release_occupied_tile.rpc_id(1, owner.get_path(), _previous_tile)

	emit_signal("waypoint_reached")
	
	if not _start_next_move_step():
		# If there are no more steps, the path is finished.
		emit_signal("path_finished")

func _physics_process(_delta: float) -> void:
	# This function is now only for checking game logic, not for movement.
	if not is_moving:
		return

	# This safety check is still crucial!
	if is_instance_valid(chase_target):
		var attack_range = stats_component.get_total_stat("range")
		if owner.global_position.distance_to(chase_target.global_position) <= attack_range:
			stop()
			emit_signal("path_finished")
			return
