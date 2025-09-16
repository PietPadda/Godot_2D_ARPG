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
@onready var character_body: CharacterBody2D = get_parent()
@onready var stats_component: StatsComponent = character_body.get_node("StatsComponent")

# Pathfinding State
var move_path: PackedVector2Array = []
# This flag will act as our "lock" to prevent interruptions.
var is_moving: bool = false
# We'll store the active target here.
var current_target_pos: Vector2
# We'll set this back to a small, reasonable value for precise point-to-point movement.
const STOPPING_DISTANCE: float = 6.0
# We need a reference to the actual chase target, not just the waypoints.
# We'll add a variable to hold it.
var chase_target: Node2D

# We'll use this to track the character's current position on the grid.
var _current_tile: Vector2i

func _ready() -> void:
	# We must wait a frame for the multiplayer authority to be assigned.
	await owner.tree_entered
	
	# Only the machine that controls this character should send its initial position.
	if owner.is_multiplayer_authority():
		# Initial position update when the character first enters the scene.
		_current_tile = Grid.world_to_map(owner.global_position)
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
	
	# check if the first point is our current tile.
	if not move_path.is_empty():
		var first_point_tile = Grid.world_to_map(move_path[0])
		var current_pos_tile = Grid.world_to_map(character_body.global_position)
		if first_point_tile == current_pos_tile:
			move_path.remove_at(0) # If so, discard it.
	
	_set_next_target()

# Stops all current movement immediately.
func stop() -> void:
	move_path.clear() # clear the current path
	is_moving = false # set to no longer moving
	character_body.velocity = Vector2.ZERO # Ensure physics velocity is also stopped
	
# Internal Logic
# Sets the next tile in the path as the active target.
func _set_next_target() -> bool:
	# if move path is finished
	if move_path.is_empty():
		is_moving = false
		character_body.velocity = Vector2.ZERO
		return false # and end (bool allows func call)

	# otherwise
	is_moving = true # still moving
	current_target_pos = move_path[0] # set new target
	move_path.remove_at(0) # remove it
	
	return true # continue moving (bool allows func call)
	
func _physics_process(_delta: float) -> void:
	if not is_moving:
		return
	
	#  We add a new, higher-priority check.
	# If we have a chase_target and are within its attack range, our job is done.
	if is_instance_valid(chase_target):
		var attack_range = stats_component.get_total_stat("range")
		if character_body.global_position.distance_to(chase_target.global_position) <= attack_range:
			stop() # Stop moving.
			emit_signal("path_finished") # Announce that we are finished.
			return
		
	# Check if we've arrived at the current waypoint.
	if character_body.global_position.distance_to(current_target_pos) < STOPPING_DISTANCE:
		# We emit the signal BEFORE getting the next waypoint.
		# This lets any listener (like a state machine) react to the progress.
		emit_signal("waypoint_reached")
		
		# If we've arrived, try to get the next waypoint.
		if not _set_next_target():
			# If there are no more waypoints, the path is finished.
			emit_signal("path_finished")
		return

	# If we haven't arrived, calculate velocity and move.
	var direction = character_body.global_position.direction_to(current_target_pos)
	var move_speed = stats_component.get_total_stat("move_speed")
	character_body.velocity = direction * move_speed
	character_body.move_and_slide()
	
	# After movement, we check if the character has moved to a new tile.
	var new_tile: Vector2i = Grid.world_to_map(owner.global_position)
	if new_tile != _current_tile:
		_current_tile = new_tile
		
		# If they have, we notify the GridManager of their new position.
		# Only the authority for this character sends the update to the server.
		if owner.is_multiplayer_authority():
			Grid.update_character_position.rpc_id(1, owner.get_path(), new_tile)
	
