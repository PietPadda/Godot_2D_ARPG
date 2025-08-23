# player_idle_state.gd
# The state for when the player is standing still.
class_name PlayerIdleState
extends State

# References to the player's nodes we need to interact with.
@onready var player: CharacterBody2D = get_owner()
@onready var movement_component: MovementComponent = player.get_node("MovementComponent")
@onready var animation_component: AnimationComponent = player.get_node("AnimationComponent")

func enter() -> void:
	# Play Idle Anim on Entering
	animation_component.play_animation("Idle")

func process_input(event: InputEvent) -> void:
	# When the move action is pressed, we want to start moving.
	if event.is_action_pressed("move_click"):
		var target = _get_target_under_mouse() # get object under mouse
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
		
	# Temporary attack trigger (we'll remove this soon).
	if event.is_action_pressed("attack"):
		state_machine.change_state("Attack")

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
