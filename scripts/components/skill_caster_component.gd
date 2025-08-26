# skill_caster_component.gd
class_name SkillCasterComponent
extends Node

# This creates a dedicated slot in the Inspector for our skill.
@export var secondary_attack_skill: SkillData

# scene nodes
@onready var stats_component: StatsComponent = get_owner().get_node("StatsComponent") # sibling

# Tries to cast a skill. Returns true on success.
func cast(skill_data: SkillData, target_position: Vector2) -> bool:
	# if out of mana, do not cast!
	if not stats_component.use_mana(skill_data.mana_cost):
		print("Not enough mana!")
		return false # use mana returns false

	# if no scene, do not cast!
	if not skill_data.projectile_scene:
		push_error("SkillData is missing a projectile scene!")
		return false # false if no scene

	var projectile = skill_data.projectile_scene.instantiate()

	# The projectile needs to know where it's going.
	projectile.global_position = get_owner().global_position # get caster position
	projectile.look_at(target_position) # get target position
	
	# Add the projectile to the main scene FIRST
	get_tree().current_scene.add_child(projectile)
	
	# AFTER Pass the skill data to the projectile so it knows its stats.
	projectile.initialize(skill_data)



	return true
