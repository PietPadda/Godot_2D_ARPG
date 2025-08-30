# grid_movement_component.gd
# A component that moves its parent CharacterBody2D to a SINGLE target position.
class_name GridMovementComponent
extends Node

# Emitted when the character has arrived at its target.
signal path_finished

# Component References
@onready var character_body: CharacterBody2D = get_parent()
@onready var stats_component: StatsComponent = character_body.get_node("StatsComponent")

# Pathfinding State
var move_path: PackedVector2Array = []
# This flag will act as our "lock" to prevent interruptions.
var is_moving: bool = false
# We'll store the active tween here.
var current_tween: Tween

# Public API
# The component now takes the entire path and manages it internally.
func move_along_path(path: PackedVector2Array) -> void:
	# Stop any previous movement.
	stop()
	
	# if no more path, stop
	if path.is_empty():
		emit_signal("path_finished")
		return
	
	# set new path
	move_path = path
	
	# The crucial fix: check if the first point is our current tile.
	var first_point_tile = Grid.world_to_map(move_path[0])
	var current_pos_tile = Grid.world_to_map(character_body.global_position)
	if first_point_tile == current_pos_tile:
		move_path.remove_at(0) # If so, discard it.
	
	print("Component received new path: ", move_path)
	_move_to_next_tile()

# Stops all current movement immediately.
func stop() -> void:
	if current_tween: # if there is an invetween tile move
		current_tween.kill() # kill it
	move_path.clear() # clear the current path
	is_moving = false # set to no longer moving
	character_body.velocity = Vector2.ZERO # Ensure physics velocity is also stopped

# Internal Logic
func _move_to_next_tile() -> void:
	# if move path is finished
	if move_path.is_empty():
		print("Component finished path.")
		emit_signal("path_finished") # comm it
		return # and end

	# other wise
	is_moving = true # still moving
	var target_pos = move_path[0] # set new target
	move_path.remove_at(0) # remove it
	print("Component moving to: ", target_pos)

	# update the tween
	current_tween = create_tween().set_parallel(false)
	var duration = character_body.global_position.distance_to(target_pos) / stats_component.get_total_stat("move_speed")
	current_tween.tween_property(character_body, "global_position", target_pos, duration)
	current_tween.tween_callback(_on_tile_move_finished)

func _on_tile_move_finished() -> void:
	is_moving = false # no longer moving
	current_tween = null # tween reached destination
	# When one tile is done, immediately try the next one.
	_move_to_next_tile()
