# player_idle_state.gd
# The state for when the player is standing still.
class_name PlayerIdleState
extends PlayerState # Changed from 'State'

# References to the player's nodes we need to interact with.
@onready var animation_component: AnimationComponent = player.get_node("AnimationComponent")
@onready var targeting_component: PlayerTargetingComponent = player.get_node("PlayerTargetingComponent")
@onready var grid_movement_component: GridMovementComponent = player.get_node("GridMovementComponent")

func enter() -> void:
	# Explicitly stop all movement when entering the Idle state.
	player.velocity = Vector2.ZERO
	# Play Idle Anim on Entering
	animation_component.play_animation("Idle")

func process_input(event: InputEvent) -> void:
	# Call the shared logic from our new base class first.
	if handle_skill_cast(event):
		return # If a skill was cast, we don't need to do anything else.
		
	# When the move action is pressed, we want to start moving.
	if event.is_action_pressed("move_click"):
		# --- TEMPORARY TEST CODE ---
		# We'll use this to test moving to a SINGLE tile.
		
		# Get the map coordinate of the click.
		var map_pos = Grid.world_to_map(player.get_global_mouse_position())
		
		# Convert that grid coordinate back to a world position (the center of the tile).
		var target_world_pos = Grid.map_to_world(map_pos)
		
		# Tell our new component to move there.
		grid_movement_component.move_to(target_world_pos)
		# We are NOT changing state yet. This is just to test the component.
		
		'''
		var target = targeting_component.get_target_under_mouse() # get object under mouse
		if target: # if something is below the mouse
			# If we found a target, we will attack it.
			# We found a target! Pass it to the chase state.
			var chase_state = state_machine.states["chase"]
			chase_state.target = target # pass target to chase state
			state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.CHASE]) # we now chase
		else: # general movement
			# We tell the MovementComponent where to go...
			var target_position = player.get_global_mouse_position()
			movement_component.set_movement_target(target_position)
			
			# ...and then we tell the state machine to switch to the "Move" state.
			state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.MOVE])
			'''
