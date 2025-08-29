# grid_movement_component.gd
class_name GridMovementComponent
extends Node

# This signal tells the FSM that the character has arrived at the target tile.
signal move_finished

# A reference to the character_body of this component (the Player).
@onready var character_body: CharacterBody2D = get_parent()
# A reference to the StatsComponent to get the character's move_speed.
@onready var stats_component: StatsComponent = character_body.get_node("StatsComponent")

# A flag to prevent starting a new move while one is already in progress.
var is_moving: bool = false

# The main public function for this component. It initiates a move to a target position.
func move_to(target_position: Vector2):
	# Guard clause: If we are already moving, don't start a new move.
	if is_moving:
		return

	# Set the flag to true to block subsequent calls until this move is done.
	is_moving = true

	# Calculate the duration of the move based on the distance and the character's speed.
	# This ensures that movement speed is still controlled by our data-driven stats.
	var distance = character_body.global_position.distance_to(target_position)
	var duration = distance / stats_component.get_total_stat("move_speed")

	# A Tween is a powerful Godot node for animating properties over time.
	# We create a new one here for this specific movement.
	var tween = create_tween()
	
	# We tell the tween to animate the 'global_position' property of our character_body...
	# ...from its current position to the 'target_position' over the calculated 'duration'.
	tween.tween_property(character_body, "global_position", target_position, duration)

	# We connect the tween's "finished" signal to our internal cleanup function.
	tween.finished.connect(_on_tween_finished)

# This private function is called automatically when the tween completes.
func _on_tween_finished():
	# Reset the flag so we can accept new moves.
	is_moving = false
	# Announce that the move is complete, so the FSM can take the next action.
	emit_signal("move_finished")
