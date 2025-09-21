# skill_caster_component.gd
class_name SkillCasterComponent
extends Node

# Add a signal to announce when the cast time is over.
signal cast_finished

# This creates a dedicated slot in the Inspector for our skill.
@export var secondary_attack_skill: SkillData
@export var stats_component: StatsComponent
# Add a timer to manage the cast duration.
@onready var duration_timer: Timer = Timer.new()

func _ready():
	# Configure the timer.
	duration_timer.one_shot = true
	duration_timer.timeout.connect(on_timer_timeout)
	add_child(duration_timer)

# Tries to cast a skill. Returns true on success.
func cast(skill_data: SkillData, target_position: Vector2) -> bool:
	# We perform a mana check on the client first to provide instant feedback.
	if not stats_component.use_mana(skill_data.mana_cost):
		print("Not enough mana!")
		return false # insufficient mana returns false
	
	# Start the timer using the cast_time from our data resource.
	duration_timer.start(skill_data.cast_time)

	# Instead of spawning, we call the RPC on the server (peer 1).
	# We no longer need to send the skill_path. The server knows what skill we have equipped.
	server_request_cast.rpc_id(1, target_position)
	return true

# -- Signal Handlers --
# This function will be called when the timer ends.
func on_timer_timeout():
	emit_signal("cast_finished")

# --- RPCs ---
# This new RPC function will only run on the server.
@rpc("any_peer", "call_local", "reliable")
func server_request_cast(target_position: Vector2):
	# Use the skill data already on this component, don't load from a path.
	var skill_data = secondary_attack_skill
	if not skill_data: 
		return
		
	# Only the server validates mana for remote players.
	# The host (server, ID 1) already paid mana locally in the 'cast' function.
	if owner.get_multiplayer_authority() != 1:
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

	# Instantiate and configure the  (now invisible) projectile on the server
	var projectile = projectile_scene.instantiate()
	
	# Add the projectile to the scene tree FIRST. This ensures all its @onready variables will be ready.
	# Add it to the container, which the spawner will replicate for everyone
	projectile_container.add_child(projectile, true) # Force a network-safe name
	
	# The projectile needs to know where it's going.
	# get the caster's network ID
	var caster_id = owner.get_multiplayer_authority()
	var caster_pos = owner.global_position
	
	# we call our unified RPC to do everything on all clients at once.
	# Instead of passing the whole 'skill_data' object,
	# we pass its 'resource_path', which is just a string.
	projectile.initialize.rpc(skill_data.resource_path, caster_id, caster_pos, target_position)
	
