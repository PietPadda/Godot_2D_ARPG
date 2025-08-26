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

## add xp to players
func add_xp(amount: int) -> void:
	if not stats_data: return # return if enemy doesn't have stats

	stats_data.current_xp += amount # add xp
	print("Gained %d XP. Total: %d / %d" % [amount, stats_data.current_xp, stats_data.xp_to_next_level])

	# Check if we have enough XP to level up.
	while stats_data.current_xp >= stats_data.xp_to_next_level:
		_level_up() # level up ONLY if more than req

## level up on sufficient xp
func _level_up() -> void:
	# Use up the XP for the level up.
	stats_data.current_xp -= stats_data.xp_to_next_level
	stats_data.level += 1 # incr level
	
	# Increase the XP requirement for the next level (e.g., by 50%).
	stats_data.xp_to_next_level = int(stats_data.xp_to_next_level * 1.5)

	# Apply stat gains.
	stats_data.max_health += 20 # hp increase
	current_health = stats_data.max_health # Heal to full on level up.

	print("LEVEL UP! Reached level %d." % stats_data.level)
	# Announce the health change so the UI updates.
	emit_signal("health_changed", current_health, stats_data.max_health)
