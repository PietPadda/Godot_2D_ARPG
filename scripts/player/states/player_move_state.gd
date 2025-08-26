# player_move_state.gd
# The state for when the player is actively moving towards a target.
class_name PlayerMoveState
extends State

# References to the player's nodes we need to interact with.
@onready var player: CharacterBody2D = get_owner()
@onready var movement_component: PlayerMovementComponent = player.get_node("PlayerMovementComponent")
@onready var animation_component: AnimationComponent = player.get_node("AnimationComponent")
@onready var targeting_component: PlayerTargetingComponent = player.get_node("PlayerTargetingComponent")
@onready var skill_component: SkillCasterComponent = player.get_node("SkillCasterComponent")

func enter() -> void:
	# For debugging, let's see when we enter this state.
	animation_component.play_animation("Move") # play Move anim

func exit() -> void:
	pass

func process_input(event: InputEvent) -> void:
	# If the player clicks a new destination while already moving,
	# we update the target without changing state.
	if event.is_action_pressed("move_click"):
		# If the player clicks, we first check if they clicked on an enemy.
		if event.is_action_pressed("move_click"):
			var target = targeting_component.get_target_under_mouse()
			
			if target:
				# If a target was found, interrupt the current move and start chasing.
				print("New target selected while moving. Switching to Chase.")
				var chase_state = state_machine.states["chase"]
				chase_state.target = target
				state_machine.change_state("Chase")
			else:
				# If no target was found, it's just a regular move command.
				# Update the destination and stay in the MoveState.
				var target_position = player.get_global_mouse_position()
				movement_component.set_movement_target(target_position)
				
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

func process_physics(_delta: float) -> void:
	# In the physics update, we check if we've reached our destination.
	var distance_to_target = player.global_position.distance_to(movement_component.target_position)
	if distance_to_target < movement_component.stopping_distance:
		# If we have, we transition back to the "Idle" state.
		state_machine.change_state("Idle")
