# player_idle_state.gd
# The state for when the player is standing still.
class_name PlayerIdleState
extends State

# References to the player's nodes we need to interact with.
@onready var player: CharacterBody2D = get_owner()
@onready var movement_component: PlayerMovementComponent = player.get_node("PlayerMovementComponent")
@onready var animation_component: AnimationComponent = player.get_node("AnimationComponent")
@onready var targeting_component: PlayerTargetingComponent = player.get_node("PlayerTargetingComponent")
@onready var skill_component: SkillCasterComponent = player.get_node("SkillCasterComponent")

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
			
	# Cast a skill on right click
	if event.is_action_pressed("cast_skill"):
		# Ask it which skill is equipped for this action.
		var skill_to_cast = skill_component.secondary_attack_skill

		# Only proceed if a skill is actually equipped.
		if skill_to_cast:
			var cast_state: PlayerCastState = state_machine.states["cast"]
			cast_state.skill_to_cast = skill_to_cast
			cast_state.cast_target_position = player.get_global_mouse_position()
			state_machine.change_state("Cast")
		else:
			print("No secondary attack equipped")
