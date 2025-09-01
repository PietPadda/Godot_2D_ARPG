# player_idle_state.gd
# The state for when the player is standing still.
class_name PlayerIdleState
extends PlayerState # Changed from 'State'

# References to the player's nodes we need to interact with.
@onready var animation_component: AnimationComponent = player.get_node("AnimationComponent")
@onready var targeting_component: PlayerTargetingComponent = player.get_node("PlayerTargetingComponent")

func enter() -> void:
	# Explicitly stop all movement when entering the Idle state.
	player.velocity = Vector2.ZERO
	# Play Idle Anim on Entering
	animation_component.play_animation("Idle")

# IdleState now only cares about the INITIAL press to decide what to do next.
func process_input(event: InputEvent) -> void:
	# Call the shared logic from our new base class first.
	if handle_skill_cast(event):
		return # If a skill was cast, we don't need to do anything else.
		
	# We use "is_action_JUST_pressed" for targeting to avoid conflicts with holding.
	if Input.is_action_just_pressed("move_click"):
		var target = targeting_component.get_target_under_mouse() # get object under mouse
		
		if target: # if something is below the mouse
			# A target was clicked! Pass it to the Chase state and transition.
			var chase_state: PlayerChaseState = state_machine.states["chase"]
			chase_state.target = target
			state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.CHASE])
		else:
			# The ground was clicked. Let the MoveState handle it.
			var move_state: PlayerMoveState = state_machine.states["move"]
			# CHANGED: We now pass the raw world position, not a tile coordinate.
			move_state.destination_world_pos = player.get_global_mouse_position()
			state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.MOVE])
		
# IdleState no longer needs a physics_process. It doesn't do anything continuously.
func _physics_process(_delta: float) -> void:
	pass
