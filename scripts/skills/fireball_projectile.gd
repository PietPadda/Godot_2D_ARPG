# fireball_projectile.gd
extends Area2D

# default vars
var damage: int = 0
var speed: float = 400.0
var timer_expire: float = 3.0

# scene nodes
@onready var timer: Timer = $Timer

func _ready() -> void:
	# Connect the body_entered signal to our hit logic.
	body_entered.connect(_on_body_entered)
	# Connect the timer to self-destruct after a few seconds.
	timer.timeout.connect(queue_free)
	timer.start(timer_expire) # Projectile lasts for X seconds.

func _physics_process(delta: float) -> void:
	# Move forward in the direction the projectile is facing.
	position += transform.x * speed * delta

func _on_body_entered(body: Node2D) -> void:
	# Check if the body we hit has a StatsComponent.
	var stats: StatsComponent = body.get_node_or_null("StatsComponent")
	if stats:
		stats.take_damage(damage)

	# Destroy the projectile on impact.
	queue_free()
