# player_idle_state.gd
# The state for when the player is standing still.
class_name PlayerIdleState
extends PlayerState # Changed from 'State'

# References to the player's nodes we need to interact with.
@onready var animation_component: AnimationComponent = player.get_node("AnimationComponent")
@onready var input_component: PlayerInputComponent = get_owner().get_node("PlayerInputComponent")

func enter() -> void:
	# Explicitly stop all movement when entering the Idle state.
	player.velocity = Vector2.ZERO
	# Play Idle Anim on Entering
	animation_component.play_animation("Idle")
	
	# Connect to the input component's signals when entering the idle state.
	input_component.move_to_requested.connect(_on_move_to_requested)
	input_component.target_requested.connect(_on_target_requested)
	input_component.cast_requested.connect(_on_cast_requested)

func exit() -> void:
	# IMPORTANT: Disconnect from the signals when we leave this state to prevent
	# listening for input when we're not supposed to (e.g., while moving or attacking).
	input_component.move_to_requested.disconnect(_on_move_to_requested)
	input_component.target_requested.disconnect(_on_target_requested)
	input_component.cast_requested.disconnect(_on_cast_requested)

# IdleState no longer needs a prcess_input. It doesn't do any input.
func process_input(event: InputEvent) -> void:
	pass
		
# IdleState no longer needs a physics_process. It doesn't do anything continuously.
func _physics_process(_delta: float) -> void:
	pass

# -- Signal Handlers ---
func _on_move_to_requested(target_position: Vector2) -> void:
	var move_state: PlayerMoveState = state_machine.states["move"]
	move_state.destination_tile = Grid.world_to_map(target_position)
	state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.MOVE])

func _on_target_requested(target: Node2D) -> void:
	var chase_state: PlayerChaseState = state_machine.states["chase"]
	chase_state.target = target
	state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.CHASE])
	
# Add the handler for our new cast signal.
func _on_cast_requested(skill_slot: int, target_position: Vector2) -> void:
	# Use the skill_slot to get the actual skill data from the component.
	# For now, since we only have one skill, we'll just grab the secondary_attack_skill.
	var skill_to_cast: SkillData = skill_caster_component.secondary_attack_skill
	
	# edge case handling
	if not is_instance_valid(skill_to_cast):
		print("No skill equipped to cast.")
		return
	
	var cast_state: PlayerCastState = state_machine.states["cast"]
	# assign the SkillData object and the Vector2 position.
	cast_state.skill_to_cast = skill_to_cast
	cast_state.cast_target_position = target_position
	
	state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.CAST])
