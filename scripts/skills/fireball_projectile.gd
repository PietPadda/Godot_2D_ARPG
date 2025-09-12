# fireball_projectile.gd
extends Area2D

# init vars
var damage: int
var speed: float
var owner_id: int # store the ID of the player who fired the projectile.
var _is_processing_impact = false # flag to prevent multiple impacts

# scene nodes
@onready var timer: Timer = $Timer


func _ready() -> void:
	# Connect the timer to self-destruct after a few seconds.
	# Connect the timer to our new safe despawn method.
	timer.timeout.connect(despawn)

# A new initialize function to set up the projectile from data.
func initialize(skill_data: SkillData, _owner_id: int) -> void:
	self.damage = skill_data.damage
	self.speed = skill_data.projectile_data.speed
	self.owner_id = _owner_id # Store the ID
	timer.start(skill_data.projectile_data.lifetime)

func _physics_process(delta: float) -> void:
	# Move forward in the direction the projectile is facing.
	position += transform.x * speed * delta

func _on_body_entered(body: Node2D) -> void:
	# If we are already handling an impact, do nothing.
	if _is_processing_impact:
		return # do nothing
	_is_processing_impact = true # otherwise, we are handling an impact

	# SAFETY CHECK: Make sure the body we hit still exists.
	if not is_instance_valid(body):
		despawn() # Despawn if we hit an invalid body
		return # do nothing to prevent race conditions
		
	# Check if the body we hit has a StatsComponent.
	var stats: StatsComponent = body.get_node_or_null("StatsComponent")
	if stats:
		# Instead of dealing damage directly, we send a request to the server (peer ID 1).
		stats.server_take_damage.rpc_id(1, damage, owner_id)

	# Destroy the projectile on impact.
	despawn() # Use our new safe despawn method on impact.

# This function safely despawns the projectile.
func despawn():
	# SAFETY CHECK: If we're already set to be deleted, don't do it again.
	if is_queued_for_deletion():
		return # do nothing to prevent race conditions
		
	# If we are the authority (the server), we can destroy the node.
	if is_multiplayer_authority():
		queue_free()
	# If we are a client, we must ask the server to destroy it.
	else:
		server_request_despawn.rpc_id(1)

# --- RPCs ---
# This RPC receives the client's request.
@rpc("any_peer", "call_local", "reliable")
func server_request_despawn():
	# This code only runs on the server.
	queue_free()
