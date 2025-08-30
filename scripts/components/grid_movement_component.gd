# grid_movement_component.gd
# A component that moves its parent CharacterBody2D to a SINGLE target position.
class_name GridMovementComponent
extends Node

# Emitted when the character has arrived at its target.
signal move_finished

# Component References
@onready var character_body: CharacterBody2D = get_parent()
@onready var stats_component: StatsComponent = character_body.get_node("StatsComponent")

# Pathfinding State
# This flag will act as our "lock" to prevent interruptions.
var is_moving: bool = false
const STOPPING_DISTANCE: float = 5.0

# Public API
# Moves the character to a single target position.
func move_to(target_pos: Vector2) -> void:
	if is_moving: return 
	is_moving = true
	
	var tween = create_tween().set_parallel(false) # our inbetween tile state
	var duration = character_body.global_position.distance_to(target_pos) / stats_component.get_total_stat("move_speed")
	
	tween.tween_property(character_body, "global_position", target_pos, duration)
	tween.tween_callback(_on_move_finished)

# Stops all current movement immediately.
func stop() -> void:
	# (We will implement this in a future step if needed for things like stuns)
	pass

# Internal Logic
func _on_move_finished() -> void:
	is_moving = false
	emit_signal("move_finished")
