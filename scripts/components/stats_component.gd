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
