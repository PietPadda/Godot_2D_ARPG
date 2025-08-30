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

# The process_input function now ONLY handles single-press targeting.
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
		
# The physics_process handles the continuous "hold-to-move" action.
func _physics_process(_delta: float) -> void:
	# If the move button is held down, and we're not targeting an enemy.
	if Input.is_action_pressed("move_click") and targeting_component.get_target_under_mouse() == null:
		var start_pos = Grid.world_to_map(player.global_position)
		var end_pos = Grid.world_to_map(player.get_global_mouse_position())
		var path = Grid.find_path(start_pos, end_pos)
		
		if not path.is_empty():
			var move_state: PlayerMoveState = state_machine.states["move"]
			move_state.move_path = path
			state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.MOVE])
