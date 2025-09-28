# stats_component.gd
# Manages an entity's stats, using a CharacterStats resource as a data source.
class_name StatsComponent
extends Node


# --- Signals ---
## entity death signal
signal died # death notification
## health update signal
signal health_changed(current_health, max_health) # hp update
## mana update signal
signal mana_changed(current_mana, max_mana) # mana update
## xp and level update signal
signal xp_changed(level, current_xp, xp_to_next_level)
## gold update signal
signal gold_changed(total_gold) # Announce when gold total changes.
## one or more stats changed signal
signal stats_changed

# --- Exports ---
@export var stats_data: CharacterStats # resource file that holds the base stats.
@export var stat_calculator: StatCalculator # calculator to get total stat values

# --- State Variables ---
@export var current_health: int # entity hp tracker
@export var current_mana: int # mana tracker
var is_dead: bool = false # death tracker
# These will hold the final, calculated values including item bonuses.
var total_max_health: int
var total_max_mana: int

func _ready() -> void:
	# Ensure a stats resource has been assigned in the editor.
	if not stats_data:
		push_error("StatsComponent needs a CharacterStats resource to function.")
		return
		
	# Initialize our totals with the base stats first.
	total_max_health = stats_data.max_health
	total_max_mana = stats_data.max_mana
	
	# Current health starts at the maximum.
	current_health = stats_data.max_health
	current_mana = stats_data.max_mana
	
	# Use our single, reliable function to update the UI on the first frame.
	refresh_stats()

# --- Public Functions ---
# Public function to apply damage to this entity.
## Lose life function
func take_damage(damage_amount: int, attacker_id: int) -> void:
	# This is a "guard clause". If the entity is already dead,
	# we stop the function immediately.
	if is_dead or not stats_data:
		return

	current_health -= damage_amount # decr life
	# Emit the signal every time damage is taken.
	emit_signal("health_changed", current_health, stats_data.max_health)

	if current_health <= 0: # if dead
		is_dead = true # flag entity as dead
		current_health = 0 # set dead
		# Emit the 'died' signal WITH the attacker's ID
		emit_signal("died", attacker_id)

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
	if not stats_data: 
		return # return if enemy doesn't have stats
	stats_data.current_xp += amount # add xp

	# The level-up loop runs first, if applicable.
	while stats_data.current_xp >= stats_data.xp_to_next_level:
		_level_up() # level up ONLY if more than req		
		# If we are the client with authority, tell the server we have leveled up.
		if owner.is_multiplayer_authority():
			server_level_up.rpc_id(1, stats_data.level)
	
	# After all calculations are done, emit the signal once with the final values.
	# This correctly updates the UI both when we level up and when we don't.
	emit_signal("xp_changed", stats_data.level, stats_data.current_xp, stats_data.xp_to_next_level)

# Public function to add gold to the player's stats.
## add gold to player
func add_gold(amount: int) -> void:
	if not stats_data: # no stats, no gold
		return
	stats_data.gold += amount # inr
	emit_signal("gold_changed", stats_data.gold) # signal

## Helper to Announce to UI stats update
func refresh_stats() -> void:
	emit_signal("health_changed", current_health, total_max_health)
	emit_signal("mana_changed", current_mana, total_max_mana)
	emit_signal("xp_changed", stats_data.level, stats_data.current_xp, stats_data.xp_to_next_level)
	emit_signal("gold_changed", stats_data.gold)

# This function will be called whenever we need to update our max stats.
func recalculate_max_stats() -> void:
	if not stat_calculator: 
		return

	# Get the new totals from the one source of truth.
	total_max_health = stat_calculator.get_total_stat(Stats.STAT_NAMES[Stats.STAT.MAX_HEALTH])
	total_max_mana = stat_calculator.get_total_stat(Stats.STAT_NAMES[Stats.STAT.MAX_MANA])
	# We no longer modify stats_data. We only update our internal variables.
	
	# Ensure current health and mana do not exceed the new maximums.
	current_health = min(current_health, stats_data.max_health)
	current_mana = min(current_mana, stats_data.max_mana)

	# Emit the signals to update the UI with the new values.
	emit_signal("health_changed", current_health, total_max_health)
	emit_signal("mana_changed", current_mana, total_max_mana)

# --- Private Functions ---
## level up player on sufficient xp
func _level_up() -> void:
	# Use up the XP for the level up.
	stats_data.current_xp -= stats_data.xp_to_next_level
	stats_data.level += 1 # incr level
	
	# Increase the XP requirement for the next level (static addition for now)
	stats_data.xp_to_next_level = int(stats_data.xp_to_next_level + 100)
	emit_signal("xp_changed", stats_data.level, stats_data.current_xp, stats_data.xp_to_next_level)
	
	# Call new helper function to apply the stat gains.
	_apply_stat_gains_for_level()
	
	# Now that the base stats have increased, trigger a full recalculation.
	# This will factor in the new base stats AND all equipment bonuses.
	recalculate_max_stats()
	
	# Heal to the new, fully calculated total maximums.
	current_health = total_max_health
	current_mana = total_max_mana
	
	# After all calculations, use our unified function to update the UI.
	refresh_stats()
	
# reusable function for calculating stat gains.
## Applies stat increases based on the current level.
func _apply_stat_gains_for_level():
	# This is the same logic that was in _level_up.
	stats_data.max_health += 5
	stats_data.max_mana += 15
	# We can add more stat increases here in the future.
	
# --- RPCs ---
# This function can be called by any client, but will only run on the server/owner.
# UPDATE the server_take_damage RPC to pass the ID along.
## server deals damage
@rpc("any_peer", "call_local", "reliable")
func server_take_damage(damage_amount: int, attacker_id: int):
	# This function now just passes the information to the main damage function.
	take_damage(damage_amount, attacker_id)

## server add gold
@rpc("any_peer", "call_local", "reliable")
func client_add_gold(amount: int):
	add_gold(amount)
	
# This RPC is called by a client to inform the server that they have leveled up.
@rpc("any_peer", "call_local", "reliable")
func server_level_up(new_level: int):
	# This function now simply calls the same complete, correct logic.
	# This ensures the server's version of the player stays in sync.
	_level_up()
	
	# We can emit the stats_changed signal on the server as well,
	# in case any server-side logic needs to react to the puppet's new stats.
	stats_changed.emit()
