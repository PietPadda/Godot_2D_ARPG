# stats_component.gd
# Manages an entity's stats, using a CharacterStats resource as a data source.
class_name StatsComponent
extends Node

# signals
signal died
signal health_changed(current_health, max_health)

# Link to the resource file that holds the base stats.
@export var stats_data: CharacterStats

# The entity's current, in-game stats.
var current_health: int
var is_dead: bool = false

func _ready() -> void:
	# Ensure a stats resource has been assigned in the editor.
	if not stats_data:
		push_error("StatsComponent needs a CharacterStats resource to function.")
		return
	
	# Initialize the current stats from the base stats data.
	current_health = stats_data.max_health
	# Emit the signal on ready to set the initial health bar value.
	emit_signal("health_changed", current_health, stats_data.max_health)
	# For testing: print the initialized health.
	print("%s initialized with %d HP." % [get_parent().name, current_health])

# Public function to apply damage to this entity.
func take_damage(damage_amount: int) -> void:
	# This is a "guard clause". If the entity is already dead,
	# we stop the function immediately.
	if is_dead:
		return
		
	# We need to make sure we have stats data before proceeding.
	if not stats_data:
		return # early exit

	current_health -= damage_amount # decr life
	# Emit the signal every time damage is taken.
	emit_signal("health_changed", current_health, stats_data.max_health)
	print("%s took %d damage, %d HP remaining." % [get_parent().name, damage_amount, current_health])

	if current_health <= 0: # if dead
		is_dead = true # flag entity as dead
		current_health = 0 # set dead
		print("%s has been defeated!" % get_parent().name)
		# Instead of queue_free(), we now emit a signal.
		emit_signal("died")
