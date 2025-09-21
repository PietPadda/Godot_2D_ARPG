# player_cast_state.gd
class_name PlayerCastState
extends PlayerState

# var type init
var skill_to_cast: SkillData
var cast_target_position: Vector2

func enter() -> void:
	# For now, we'll reuse the Attack animation for casting.
	animation_component.play_animation(Anims.PLAYER_NAMES[Anims.PLAYER.ATTACK])
	# Tell the skill caster to perform the action.
	skill_caster_component.cast(skill_to_cast, cast_target_position)
	# Connect to the signal from our component.
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
