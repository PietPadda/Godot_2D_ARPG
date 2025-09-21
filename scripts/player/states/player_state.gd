# scripts/player/states/player_state.gd
class_name PlayerState
extends State

# We can put references needed by ALL player states here.
@onready var player: CharacterBody2D = get_owner()

# export components
@export var animation_component: AnimationComponent
@export var attack_component: AttackComponent
@export var grid_movement_component: GridMovementComponent
@export var input_component: PlayerInputComponent
@export var skill_caster_component: SkillCasterComponent
@export var stats_component: StatsComponent

# The shared logic for handling a cast request.
func _on_cast_requested(skill_slot: int, target_position: Vector2) -> void:
	# Stop any current movement before casting.
	grid_movement_component.stop()
	
	var skill_to_cast = skill_caster_component.secondary_attack_skill # store skill to cast
	if not is_instance_valid(skill_to_cast):
		return

	var cast_state: PlayerCastState = state_machine.get_state(States.PLAYER.CAST) # store cast state
	cast_state.skill_to_cast = skill_to_cast # set the skill to cast
	cast_state.cast_target_position = player.get_global_mouse_position() # set target
	state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.CAST]) # change the state with skill and target

func _physics_process(_delta: float) -> void:
	pass
