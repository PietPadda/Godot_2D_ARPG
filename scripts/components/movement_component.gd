# movement_component.gd
# A component that moves its parent CharacterBody2D towards a target position.
class_name MovementComponent
extends Node

# The speed at which the character moves.
@export var move_speed: float = 200.0

# A reference to the parent node, which must be a CharacterBody2D.
@onready var character_body: CharacterBody2D = get_parent()

# The target position for the character to move towards.
var target_position: Vector2

func _ready() -> void:
	# Ensure the parent is a CharacterBody2D. If not, this component can't work.
	if not character_body is CharacterBody2D:
		push_error("MovementComponent must be a child of a CharacterBody2D.")
		queue_free() # The component disables itself if not setup correctly.
		return
	
	# Start by targeting the current position to prevent initial movement.
	target_position = character_body.global_position

func _physics_process(delta: float) -> void:
	# Calculate the distance to the target.
	var distance_to_target = character_body.global_position.distance_to(target_position)

	# Stop moving if we are close enough to the target.
	if distance_to_target < 5.0:
		character_body.velocity = Vector2.ZERO
		return

	# Calculate the direction and set velocity.
	var direction = character_body.global_position.direction_to(target_position)
	character_body.velocity = direction * move_speed
	
	character_body.move_and_slide()

# Public function that allows other nodes to set a new movement target.
func set_movement_target(new_target: Vector2) -> void:
	target_position = new_target
