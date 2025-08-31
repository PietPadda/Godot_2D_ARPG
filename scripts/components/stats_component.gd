# stats_component.gd
# Manages an entity's stats, using a CharacterStats resource as a data source.
class_name StatsComponent
extends Node

# signals
## entity death signal
signal died # death notification
## health update signal
signal health_changed(current_health, max_health) # hp update
## mana update signal
signal mana_changed(current_mana, max_mana) # mana update
## xp and level update signal
signal xp_changed(level, current_xp, xp_to_next_level)

# Link to the resource file that holds the base stats.
@export var stats_data: CharacterStats

# get sibling components
@onready var equipment_component: EquipmentComponent = get_parent().get_node_or_null("EquipmentComponent")
@onready var attack_component: AttackComponent = get_parent().get_node_or_null("AttackComponent")

# The entity's current, in-game stats.
var current_health: int # entity hp tracker
var current_mana: int # mana tracker
var is_dead: bool = false # death tracker

func _ready() -> void:
	# Ensure a stats resource has been assigned in the editor.
	if not stats_data:
		push_error("StatsComponent needs a CharacterStats resource to function.")
		return
	
	# Initialize the current stats from the base stats data.
	current_health = stats_data.max_health
	current_mana = stats_data.max_mana
	# Emit the signals on ready to initialise current stats
	emit_signal("health_changed", current_health, stats_data.max_health)
	emit_signal("mana_changed", current_mana, stats_data.max_mana)
	emit_signal("xp_changed", stats_data.level, stats_data.current_xp, stats_data.xp_to_next_level)

# Public function to apply damage to this entity.
## Lose life function
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

	if current_health <= 0: # if dead
		is_dead = true # flag entity as dead
		current_health = 0 # set dead
		# Instead of queue_free(), we now emit a signal.
		emit_signal("died")

# Public function to attempt to use mana. Returns true on success.
## Consume Mana function
func use_mana(amount: int) -> bool:
	if current_mana >= amount: # if sufficient
		current_mana -= amount # decr
		emit_signal("mana_changed", current_mana, stats_data.max_mana) # update
		return true # mana use
	else:
		return false # no mana used!

## add xp to players
func add_xp(amount: int) -> void:
	if not stats_data: return # return if enemy doesn't have stats
	stats_data.current_xp += amount # add xp
	emit_signal("xp_changed", stats_data.level, stats_data.current_xp, stats_data.xp_to_next_level)
	# Check if we have enough XP to level up.
	while stats_data.current_xp >= stats_data.xp_to_next_level:
		_level_up() # level up ONLY if more than req

## level up player on sufficient xp
func _level_up() -> void:
	# Use up the XP for the level up.
	stats_data.current_xp -= stats_data.xp_to_next_level
	stats_data.level += 1 # incr level
	
	# Increase the XP requirement for the next level (static addition for now)
	stats_data.xp_to_next_level = int(stats_data.xp_to_next_level + 100)

	# Apply stat gains.
	stats_data.max_health += 25 # hp increase
	stats_data.max_mana += 20 # mana increase
	emit_signal("xp_changed", stats_data.level, stats_data.current_xp, stats_data.xp_to_next_level)
	
	current_health = stats_data.max_health # Heal to full on level up.
	current_mana = stats_data.max_mana # Restore to full on level up.
	# Announce the stats changes so the UI updates.
	refresh_stats()

## Helper to Announce to UI stats update
func refresh_stats() -> void:
	emit_signal("health_changed", current_health, stats_data.max_health)
	emit_signal("mana_changed", current_mana, stats_data.max_mana)
	emit_signal("xp_changed", stats_data.level, stats_data.current_xp, stats_data.xp_to_next_level)

## Calculates a final stat value by combining base stats with equipment modifiers.
func get_total_stat(stat_name: String) -> float:
	var total_value: float = 0.0 # init 0

	# If we're calculating "damage", get the base value from the AttackComponent.
	if (stat_name == "damage" or stat_name == "range") and attack_component and attack_component.attack_data:
		# Base damage and range come from the equipped attack.
		total_value = attack_component.attack_data.get(stat_name)
	# Start with the base value from the CharacterStats resource, if it exists.
	elif stat_name in stats_data:
		total_value = stats_data.get(stat_name)

	# Add modifiers from equipped items.
	if equipment_component: # if something equipped
		for item in equipment_component.equipment_data.equipped_items.values(): # loop each
			if item and item.stat_modifiers.has(stat_name): # if has same stat
				total_value += item.stat_modifiers[stat_name] # add to our total value

	return total_value # calculaed value
