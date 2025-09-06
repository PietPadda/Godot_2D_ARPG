# player_cast_state.gd
class_name PlayerCastState
extends PlayerState

# var type init
var skill_to_cast: SkillData
var cast_target_position: Vector2

func enter() -> void:
	# For now, we'll reuse the Attack animation for casting.
	animation_component.play_animation("Attack")

	# Tell the skill caster to perform the action.
	skill_caster_component.cast(skill_to_cast, cast_target_position)

	# After a short casting animation, return to Idle.
	# We can use a SceneTreeTimer for a simple, one-off delay.
	await get_tree().create_timer(skill_to_cast.cast_time).timeout

	# Check if the state is still active before changing.
	if state_machine.current_state == self:
		state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE])
