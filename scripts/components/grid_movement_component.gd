# grid_movement_component.gd
# A component that moves its parent CharacterBody2D along a grid-based path.
class_name GridMovementComponent
extends Node

# Emitted when the character has finished traversing the entire path.
signal path_finished

# Component References
@onready var character_body: CharacterBody2D = get_parent()
@onready var stats_component: StatsComponent = character_body.get_node("StatsComponent")

# Pathfinding State
var move_path: PackedVector2Array = []
var current_target_pos: Vector2
var has_target: bool = false
const STOPPING_DISTANCE: float = 5.0

# Public API
# Starts moving the character along a given path of world coordinates.
func move_along_path(path: PackedVector2Array) -> void:
	# If the provided path is empty, treat it as a command to stop.
	if path.is_empty():
		move_path.clear()
		has_target = false
		character_body.velocity = Vector2.ZERO
		return # no path
	
	move_path = path
	_set_next_target()

# Internal Logic
func _physics_process(_delta: float) -> void:
	if not has_target:
		return

	if character_body.global_position.distance_to(current_target_pos) < STOPPING_DISTANCE:
		# Arrived at the current tile, try to get the next one.
		if not _set_next_target():
			# If there are no more targets, the path is complete.
			emit_signal("path_finished")
			return
	
	# If we haven't arrived yet, move towards the target tile.
	var direction = character_body.global_position.direction_to(current_target_pos) # dir
	var move_speed = stats_component.get_total_stat("move_speed") # speed
	character_body.velocity = direction * move_speed # dir * speed
	character_body.move_and_slide() # apply physics

# Sets the next tile in the path as the active target. Returns false if the path is empty.
func _set_next_target() -> bool:
	# path is empty
	if move_path.is_empty():
		has_target = false
		character_body.velocity = Vector2.ZERO # Stop all movement
		return false

	# path is not yet empty
	has_target = true
	self.current_target_pos = move_path[0]
	move_path.remove_at(0)
	return true
