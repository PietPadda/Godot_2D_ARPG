# player_idle_state.gd
# The state for when the player is standing still.
class_name PlayerIdleState
extends State

# References to the player's nodes we need to interact with.
@onready var player: CharacterBody2D = get_owner()
@onready var movement_component: PlayerMovementComponent = player.get_node("PlayerMovementComponent")
@onready var animation_component: AnimationComponent = player.get_node("AnimationComponent")
@onready var targeting_component: PlayerTargetingComponent = player.get_node("PlayerTargetingComponent")

func enter() -> void:
	# Play Idle Anim on Entering
	animation_component.play_animation("Idle")

func process_input(event: InputEvent) -> void:
	# When the move action is pressed, we want to start moving.
	if event.is_action_pressed("move_click"):
		var target = targeting_component.get_target_under_mouse() # get object under mouse
		if target: # if something is below the mouse
			# If we found a target, we will attack it.
			# We found a target! Pass it to the chase state.
			var chase_state = state_machine.states["chase"]
			chase_state.target = target # pass target to chase state
			state_machine.change_state("Chase") # we now chase
		else: # general movement
			# We tell the MovementComponent where to go...
			var target_position = player.get_global_mouse_position()
			movement_component.set_movement_target(target_position)
			
			# ...and then we tell the state machine to switch to the "Move" state.
			state_machine.change_state("Move")
			
	# Add this to process_input in both IdleState and MoveState
	if event.is_action_pressed("cast_skill"):
		var cast_state: PlayerCastState = state_machine.states["cast"]
		# We need to load our fireball data. In a real game, this would
		# come from a skill bar, but for now we'll load it directly.
		cast_state.skill_to_cast = load("res://data/skills/fireball_skill.tres")
		cast_state.cast_target_position = player.get_global_mouse_position()

		state_machine.change_state("Cast")
