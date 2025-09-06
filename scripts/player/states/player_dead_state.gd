# player_dead_state.gd
class_name PlayerDeadState
extends PlayerState

func enter() -> void:
	print("Player has entered the Dead state.")
	animation_component.play_animation("Dead")

	# Disable the player's collision so enemies can walk past the body.
	var collision_shape = player.get_node("CollisionShape2D")
	collision_shape.disabled = true

# By leaving process_input and process_physics empty,
# we prevent the player from doing anything while dead.
