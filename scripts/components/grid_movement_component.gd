# grid_movement_component.gd
# A component that moves its parent CharacterBody2D to a SINGLE target position.
class_name GridMovementComponent
extends Node

# Emitted when the character has arrived at its target.
signal path_finished
# This signal will be emitted each time the component reaches a waypoint in its path.
signal waypoint_reached
# This signal will trigger that a path is blocked.
signal path_blocked

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
	
	# THE FIX: We no longer need to manage tile releases when stopping.
	# The server already knows our last occupied position. When we request a new
	# path, the GridManager's `occupy_tile` will handle releasing it.
	# if owner.is_multiplayer_authority():
	# 	Grid.release_all_but_current_tile.rpc_id(1, owner.get_path(), _current_tile) # <-- DELETE THIS
		
	move_path.clear() # clear the current path
	is_moving = false # set to no longer moving
	owner.velocity = Vector2.ZERO # Ensure physics velocity is also stopped
	
# Internal Logic
# This function creates and starts the Tween for one step of the path.
# It now requests permission instead of moving directly.
func _start_next_move_step() -> bool:
	# Movement logic, especially creating tweens, should ONLY run on
	# the machine that has authority over this character. Puppets should not move themselves.
	if not owner.is_multiplayer_authority():
		# On puppets, we simply wait for the synchronizer to update our position.
		# We must still return false to stop the movement loop.
		return false
		
	# Kill the previous tween before starting a new one.
	if is_instance_valid(_active_tween):
		_active_tween.kill()
	
	# if move path is finished
	if move_path.is_empty():
		is_moving = false
		return false # and end (bool allows func call)
	
	# NOTE: We are assuming the occupation will succeed. The server is the authority.
	is_moving = true # still moving
	
	# THE FIX: Instead of creating a tween, we find the next tile...
	var next_world_pos = move_path[0]
	var next_tile = Grid.world_to_map(next_world_pos)
	
	# ...and send an RPC to the server asking for permission to move there.
	Grid.server_player_request_tile.rpc_id(1, owner.get_path(), next_tile)

	# We return 'true' to signify a move is in progress, but the actual
	# tweening will now be started by an RPC call from the server.
	return true # continue moving (bool allows func call)

# This is our new "arrival" function. It's called when the tween is done.
func _on_move_step_finished():
	# We only update our logical tiles AFTER the move is complete.
	# Our "previous" tile is now the tile we were just on.
	_previous_tile = _current_tile
	# Our "current" tile is now the one we just arrived at.
	_current_tile = Grid.world_to_map(owner.global_position)
	
	# THE FIX: Remove this RPC call. The server's `occupy_tile` function
	# already handles releasing the previous tile atomically. This call is
	# redundant and dangerous.
	# if owner.is_multiplayer_authority():
	# 	Grid.server_release_tile.rpc_id(1, _previous_tile) # <-- DELETE THIS

	emit_signal("waypoint_reached")
	
	if not _start_next_move_step():
		# If there are no more steps, the path is finished.
		emit_signal("path_finished")

# THE FIX: This function should not contain game logic. A character must
# always complete its move to a tile's center. We are removing this function
# to prevent movement from being interrupted mid-tween.
func _physics_process(_delta: float) -> void:
	pass
	
# --- RPC Handlers ---
# These functions are called by GridManager via RPC.

# Called by the server when our requested move is APPROVED ("Green Light").
func _execute_approved_move(confirmed_tile: Vector2i):
	# The tweening logic from the old _start_next_move_step now lives here.
	if move_path.is_empty(): 
		return

	# PackedVector2Array doesn't have pop_front().
	# We get the target at index 0, then remove it.
	# Remove the step we are about to take from our local path.
	move_path.remove_at(0)
	
	var target_world_pos = Grid.map_to_world(confirmed_tile)
	var move_speed = owner.get_total_stat(Stats.STAT_NAMES[Stats.STAT.MOVE_SPEED])
	var distance = owner.global_position.distance_to(target_world_pos)
	
	# Prevent division by zero.
	if move_speed <= 0: 
		return
	
	# Tween duration
	var duration = distance / move_speed
	
	# Assign the new tween to our reference variable.
	# We use simple linear interpolation
	_active_tween = create_tween().set_trans(Tween.TRANS_LINEAR)
	_active_tween.tween_property(owner, "global_position", target_world_pos, duration)
	_active_tween.tween_callback(_on_move_step_finished)

# Called by the server when our requested move is REJECTED ("Red Light").
func _handle_rejected_move():
	# Our path is blocked by another character. Stop moving.
	stop()
	# Announce that the path is blocked so the state machine can request a new one.
	emit_signal("path_blocked")
