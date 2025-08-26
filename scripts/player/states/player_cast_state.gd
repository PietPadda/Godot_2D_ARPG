# player_cast_state.gd
class_name PlayerCastState
extends State

# var type init
var skill_to_cast: SkillData
var cast_target_position: Vector2

# scene nodes
@onready var player: CharacterBody2D = get_owner()
@onready var animation_component: AnimationComponent = player.get_node("AnimationComponent")
@onready var skill_caster_component: SkillCasterComponent = player.get_node("SkillCasterComponent")

func enter() -> void:
	# For now, we'll reuse the Attack animation for casting.
	animation_component.play_animation("Attack")

	# Tell the skill caster to perform the action.
	skill_caster_component.cast(skill_to_cast, cast_target_position)

	# After a short casting animation, return to Idle.
	# We can use a SceneTreeTimer for a simple, one-off delay.
	await get_tree().create_timer(0.5).timeout

	# Check if the state is still active before changing.
	if state_machine.current_state == self:
		state_machine.change_state("Idle")
