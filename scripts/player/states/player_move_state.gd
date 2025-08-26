# player_move_state.gd
# The state for when the player is actively moving towards a target.
class_name PlayerMoveState
extends State

@onready var player: CharacterBody2D = get_owner()
@onready var movement_component: MovementComponent = player.get_node("MovementComponent")
@onready var animation_component: AnimationComponent = player.get_node("AnimationComponent")
@onready var targeting_component: PlayerTargetingComponent = player.get_node("PlayerTargetingComponent")

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

func process_physics(_delta: float) -> void:
	# In the physics update, we check if we've reached our destination.
	var distance_to_target = player.global_position.distance_to(movement_component.target_position)
	if distance_to_target < movement_component.stopping_distance:
		# If we have, we transition back to the "Idle" state.
		state_machine.change_state("Idle")
		
# Helper function to check for colliders under the mouse.
func _get_target_under_mouse() -> Node2D:
	var world_space = player.get_world_2d().direct_space_state
	var mouse_pos = player.get_global_mouse_position()
	
	# Set up the query.
	var query = PhysicsPointQueryParameters2D.new()
	query.position = mouse_pos
	# This is where we specify which layer we are looking for.
	# 2 is the number for our "enemies" layer.
	query.collision_mask = 2
	
	# Perform the query.
	var results = world_space.intersect_point(query)
	
	# Return the first valid collider found.
	if not results.is_empty():
		return results[0].collider
	
	return null
