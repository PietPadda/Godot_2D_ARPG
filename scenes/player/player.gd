# Player.gd
# Handles player input and character movement.
extends CharacterBody2D

# The speed at which the player moves, in pixels per second.
@export var move_speed: float = 200.0

# The target position for the player to move towards.
var target_position: Vector2

func _ready() -> void:
	# Set the initial target position to the player's starting position
	# to prevent movement at the start of the game.
	target_position = global_position

func _unhandled_input(event: InputEvent) -> void:
	# Check if the "move_click" action was just pressed.
	if event.is_action_pressed("move_click"):
		# Update the target position to the mouse's global position.
		target_position = get_global_mouse_position()

func _physics_process(delta: float) -> void:
	# Calculate the distance to the target.
	var distance_to_target = global_position.distance_to(target_position)

	# Stop moving if we are close enough to the target.
	if distance_to_target < 5.0:
		velocity = Vector2.ZERO
		return

	# Calculate the direction vector from the current position to the target.
	var direction = global_position.direction_to(target_position)
	
	# Set the velocity to move in that direction at the defined speed.
	velocity = direction * move_speed
	
	# Godot's built-in function to move the character and handle collisions.
	move_and_slide()
