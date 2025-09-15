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
	# The timer should also report to the server to despawn itself.
	timer.timeout.connect(on_timeout)

func _physics_process(delta: float) -> void:
	# Move forward in the direction the projectile is facing.
	position += transform.x * speed * delta

func _on_body_entered(body: Node2D) -> void:
	# If we are already handling an impact, do nothing.
	if _is_processing_impact:
		return # do nothing
	_is_processing_impact = true # otherwise, we are handling an impact

	# Instead of dealing damage, we report the hit to the server.
	# The server's Main node will handle the rest.
	var main_node = get_tree().get_root().get_node("Main")
	if main_node:
		main_node.server_process_projectile_hit.rpc_id(1, get_path(), body.get_path())
		
# function to handle projecile timeout
func on_timeout():
	# If we are the server, we can just free ourselves.
	if is_multiplayer_authority():
		queue_free()
	# Clients don't need to do anything, the server will replicate the deletion.

# --- RPCs ---
# Convert 'initialize' into a unified RPC that runs on all clients.
@rpc("any_peer", "call_local", "reliable")
func initialize(skill_data_path: String, _owner_id: int, start_pos: Vector2, target_pos: Vector2) -> void:
	# Load the SkillData resource from the provided path.
	var loaded_skill_data = load(skill_data_path)
	if not loaded_skill_data:
		queue_free() # If the path is bad, delete this projectile.
		return
	
	# Now we can safely use the loaded data.
	# Set up the projectile's data.
	self.damage = loaded_skill_data.damage
	self.speed = loaded_skill_data.projectile_data.speed
	self.owner_id = _owner_id # Store the ID
	timer.start(loaded_skill_data.projectile_data.lifetime)
	
	# Set the position and rotation while it's still invisible.
	global_position = start_pos
	look_at(target_pos)
	
	# Now that everything is perfect, make it visible.
	visible = true
