# player_cast_state.gd
class_name PlayerCastState
extends PlayerState

# var type init
var skill_to_cast: SkillData
var cast_target_position: Vector2

func enter() -> void:
	# Immediately stop any residual movement.
	grid_movement_component.stop()
	
	# Try to cast the skill and check if it was successful.
	var cast_succeeded = skill_caster_component.cast(skill_to_cast, cast_target_position)
	
	# THE FIX: If the cast fails (e.g., not enough mana), exit this state immediately.
	if !cast_succeeded:
		state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE])
		return # Stop execution to prevent connecting a signal that will never fire.
	
	# If the cast was successful, play the animation and wait for the cast to finish.
	animation_component.play_animation(Anims.PLAYER_NAMES[Anims.PLAYER.ATTACK])
	skill_caster_component.cast_finished.connect(on_cast_finished)

# Add an exit function for clean signal disconnection.
func exit() -> void:
	if skill_caster_component.cast_finished.is_connected(on_cast_finished):
		skill_caster_component.cast_finished.disconnect(on_cast_finished)

func _physics_process(delta: float) -> void:
	pass
	
# -- Signal Handlers --
# This function is now the gatekeeper for exiting the state.
func on_cast_finished():
	# Check if the state is still active before changing.
	if state_machine.current_state == self:
		state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE])
