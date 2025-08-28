# scripts/player/states/player_state.gd
class_name PlayerState
extends State

# We can put references needed by ALL player states here.
@onready var player: CharacterBody2D = get_owner()
@onready var skill_caster_component: SkillCasterComponent = player.get_node("SkillCasterComponent")

# This is our shared input logic.
func handle_skill_cast(event: InputEvent) -> bool:
	if event.is_action_pressed("cast_skill"): # press cast
		var skill_to_cast = skill_caster_component.secondary_attack_skill # store skill to cast
		if skill_to_cast: # if something is in there
			var cast_state: PlayerCastState = state_machine.states["cast"] # store cast state
			cast_state.skill_to_cast = skill_to_cast # set the skill to cast
			cast_state.cast_target_position = player.get_global_mouse_position() # set target
			state_machine.change_state("Cast") # change the state with skill and target
			return true # Input was handled
	return false # Input was not handled
