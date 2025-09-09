# fireball_projectile.gd
extends Area2D

# init vars
var damage: int
var speed: float
var owner_id: int # store the ID of the player who fired the projectile.

# scene nodes
@onready var timer: Timer = $Timer

func _ready() -> void:
	# Connect the timer to self-destruct after a few seconds.
	timer.timeout.connect(queue_free)

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
	# Check if the body we hit has a StatsComponent.
	var stats: StatsComponent = body.get_node_or_null("StatsComponent")
	if stats:
		# Instead of dealing damage directly, we send a request to the server (peer ID 1).
		stats.server_take_damage.rpc_id(1, damage, owner_id)

	# Destroy the projectile on impact.
	queue_free()
