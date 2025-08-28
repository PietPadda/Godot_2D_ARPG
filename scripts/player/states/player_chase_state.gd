# player_chase_state.gd
# The state for moving towards a target to get within attack range.
class_name PlayerChaseState
extends State

var target: Node2D

@onready var player: CharacterBody2D = get_owner()
@onready var movement_component: PlayerMovementComponent = player.get_node("PlayerMovementComponent")
@onready var attack_component: AttackComponent = player.get_node("AttackComponent")
@onready var animation_component: AnimationComponent = player.get_node("AnimationComponent")

func enter() -> void:
	print("Entering Chase State")
	# On entering, immediately start moving towards the target.
	if not is_instance_valid(target):
		print("Exiting Chase State")
		state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE]) # just idle if invalid target
		return # early exit
	
	movement_component.set_movement_target(target.global_position) # update target position
	animation_component.play_animation("Move") # play Move Anim

func process_physics(delta: float) -> void:
	# First, check if our target still exists.
	if not is_instance_valid(target):
		print("Exiting Chase State")
		state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE]) # just idle if invalid target
		return # early exit

	# Continuously update the movement target in case the target moves.
	movement_component.set_movement_target(target.global_position)

	# Check the distance to the target.
	var distance_to_target = player.global_position.distance_to(target.global_position) 
	var attack_range = attack_component.attack_data.range # range calc

	if distance_to_target <= attack_range: # if we're in range
		# We are in range! Stop moving.
		movement_component.set_movement_target(player.global_position) # update target
		
		# Pass the target to the AttackState and transition.
		var attack_state = state_machine.states["attack"] # attackstate
		attack_state.target = target # pass the target to attack
		print("Exiting Chase State")
		state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.ATTACK]) # and attack
