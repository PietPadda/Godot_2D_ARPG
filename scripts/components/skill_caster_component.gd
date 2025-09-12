# skill_caster_component.gd
class_name SkillCasterComponent
extends Node

# This creates a dedicated slot in the Inspector for our skill.
@export var secondary_attack_skill: SkillData

# scene nodes
@onready var stats_component: StatsComponent = get_owner().get_node("StatsComponent") # sibling

# Tries to cast a skill. Returns true on success.
func cast(skill_data: SkillData, target_position: Vector2) -> bool:
	# We perform a mana check on the client first to provide instant feedback.
	if not stats_component.use_mana(skill_data.mana_cost):
		print("Not enough mana!")
		return false # insufficient mana returns false

	# Instead of spawning, we call the RPC on the server (peer 1).
	# We no longer need to send the skill_path. The server knows what skill we have equipped.
	server_request_cast.rpc_id(1, target_position)
	return true

# --- RPCs ---
# This new RPC function will only run on the server.
@rpc("any_peer", "call_local", "reliable")
func server_request_cast(target_position: Vector2):
	# Use the skill data already on this component, don't load from a path.
	var skill_data = secondary_attack_skill
	if not skill_data: 
		return
		
	# The server re-validates the mana cost as a security check.
	# Note: get_owner() here is the server's puppet of the casting player.
	var caster_stats = get_owner().get_node("StatsComponent")
	
	# Server-side validation (prevents cheating)
	if not stats_component.use_mana(skill_data.mana_cost):
		return # The server determined they couldn't cast.
	
	# Find the projectile scene
	var projectile_scene = skill_data.projectile_scene
	# if no projectile scene, do not cast!
	if not projectile_scene:
		push_error("SkillData is missing a projectile scene!")
		return # do not cast
		
	# Find the spawner and container
	var projectile_container = get_tree().get_root().get_node_or_null("Main/ProjectileContainer")
	if not projectile_container:
		return

	# Instantiate and configure the projectile on the server
	var projectile = projectile_scene.instantiate()
	
	# Add the projectile to the scene tree FIRST. This ensures all its @onready variables will be ready.
	# Add it to the container, which the spawner will replicate for everyone
	projectile_container.add_child(projectile, true) # Force a network-safe name
	
	# The projectile needs to know where it's going.
	projectile.global_position = get_owner().global_position # get caster position
	projectile.look_at(target_position) # get target position
		
	# get the caster's network ID
	var caster_id = get_owner().get_multiplayer_authority()
	# Pass the skill data AND the caster's network ID to the projectile.
	projectile.initialize(skill_data, caster_id)
	
