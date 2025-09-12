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

# DELETE the old despawn() and server_request_despawn() functions. They are no longer needed.
