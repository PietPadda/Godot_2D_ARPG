# stats_component.gd
# Manages an entity's stats, using a CharacterStats resource as a data source.
class_name StatsComponent
extends Node

# Link to the resource file that holds the base stats.
@export var stats_data: CharacterStats

# The entity's current, in-game stats.
var current_health: int

func _ready() -> void:
	# Ensure a stats resource has been assigned in the editor.
	if not stats_data:
		push_error("StatsComponent needs a CharacterStats resource to function.")
		return
	
	# Initialize the current stats from the base stats data.
	current_health = stats_data.max_health
	
	# For testing: print the initialized health.
	print("%s initialized with %d HP." % [get_parent().name, current_health])


# Public function to apply damage to this entity.
func take_damage(damage_amount: int) -> void:
	# We need to make sure we have stats data before proceeding.
	if not stats_data:
		return # early exit

	current_health -= damage_amount # decr life
	print("%s took %d damage, %d HP remaining." % [get_parent().name, damage_amount, current_health])

	if current_health <= 0: # if dead
		current_health = 0 # set dead
		print("%s has been defeated!" % get_parent().name)
		# Later, we will emit a "died" signal here. For now, we'll make the enemy disappear.
		get_parent().queue_free() # delete the "parent" ie Entity
