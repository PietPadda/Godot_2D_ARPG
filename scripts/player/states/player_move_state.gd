# player_move_state.gd
# The state for when the player is actively moving towards a target.
class_name PlayerMoveState
extends State

@onready var player: CharacterBody2D = get_owner()
@onready var movement_component: MovementComponent = player.get_node("MovementComponent")
@onready var animation_component: AnimationComponent = player.get_node("AnimationComponent")

func enter() -> void:
	# For debugging, let's see when we enter this state.
	print("Entering Move State")
	animation_component.play_animation("Move") # play Move anim

func exit() -> void:
	# For debugging, let's see when we exit.
	print("Exiting Move State")

func process_input(event: InputEvent) -> void:
	# If the player clicks a new destination while already moving,
	# we update the target without changing state.
	if event.is_action_pressed("move_click"):
		var target_position = player.get_global_mouse_position()
		movement_component.set_movement_target(target_position)

func process_physics(_delta: float) -> void:
	# In the physics update, we check if we've reached our destination.
	var distance_to_target = player.global_position.distance_to(movement_component.target_position)
	if distance_to_target < 5.0:
		# If we have, we transition back to the "Idle" state.
		state_machine.change_state("Idle")
