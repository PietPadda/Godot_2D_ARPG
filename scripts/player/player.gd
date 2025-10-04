# scripts/player/player.gd
extends CharacterBody2D

# preload scenes to instance
const GameOverScreen = preload("res://scenes/ui/game_over_screen.tscn")

# get components
@export var attack_component: AttackComponent
@export var equipment_component: EquipmentComponent
@export var movement_component: GridMovementComponent
@export var inventory_component: InventoryComponent
@export var stats_component: StatsComponent
@export var stat_calculator: StatCalculator
@export var state_machine: StateMachine
@export var camera: Camera2D

# consts and vars
var _first_physics_frame_checked: bool = false

# This is a built-in Godot function.
func _enter_tree() -> void:
	# DEBUG: Trace when a player node enters the scene tree.
	print("[%s] PLAYER _enter_tree: Node '%s' is entering the tree. Setting authority to %s." % [multiplayer.get_unique_id(), name, int(name)])
	
	# The player's name is its multiplayer ID, set by the server upon creation.
	# We convert the name (which is a String) to an integer.
	# This is the crucial line: it assigns the network authority immediately.
	set_multiplayer_authority(int(name))
	
	# The server is responsible for managing the registry.
	if multiplayer.is_server():
		GameManager.register_player(self)
	
func _ready() -> void:
	# --- Resource Duplication ---
	# We duplicate our data resources to ensure this player instance has its own unique
	# stats, inventory, and equipment. Without this, all players would share the same data objects.
	if stats_component.stats_data:
		stats_component.stats_data = stats_component.stats_data.duplicate(true)
	if inventory_component.inventory_data:
		inventory_component.inventory_data = inventory_component.inventory_data.duplicate(true)
	if equipment_component.equipment_data:
		equipment_component.equipment_data = equipment_component.equipment_data.duplicate(true)
	
	# --- Authority Check ---
	# This is the most important check for a networked character.
	# If this node's multiplayer authority is NOT this local machine, it's a "puppet."
	if not is_multiplayer_authority():
		# Disable all logic and components that are only relevant to the controlling player.
		camera.enabled = false
		state_machine.set_physics_process(false)
		state_machine.set_process_unhandled_input(false)
		return# Stop execution here for puppets.
	
	# --- Local Player Setup ---
	# The following code only runs for the player character that we control.
	camera.make_current()
	
	# Connect signals for game events.
	stats_component.died.connect(_on_death) # player died
	EventBus.game_state_changed.connect(_on_game_state_changed) # game state change
	
	# Announce to the rest of the game (like the HUD) that the local player is ready.
	EventBus.emit_signal("local_player_spawned", self)
	
	# Connect equipment changes to stat recalculation.
	if equipment_component:
		equipment_component.equipment_changed.connect(stats_component.recalculate_max_stats)
	
	# Set the initial game state and calculate stats based on starting equipment.
	_on_game_state_changed(EventBus.current_game_state)
	stats_component.recalculate_max_stats()

# We need to add _physics_process to see the position on the first frame of gameplay.
func _physics_process(_delta: float) -> void:
	# This code will only run once for our controlled character.
	if is_multiplayer_authority() and not _first_physics_frame_checked:
		_first_physics_frame_checked = true

# --- Public API ---
# This function is now just a clean pass-through to the dedicated calculator.
func get_total_stat(stat_name: String) -> float:
	if stat_calculator:
		return stat_calculator.get_total_stat(stat_name)
	
	# no stats returned? error and give 0
	push_warning("StatCalculator not found on %s" % name)
	return 0.0
	
# The public-facing function for this entity to receive damage.
# It acts as a clean entry point that delegates the actual damage logic to the StatsComponent.
# Other objects should call this function to deal damage, rather than accessing components directly.
func handle_damage(damage_amount: int, attacker_id: int) -> void:
	# Guard Clause: Ensure the stats_component is valid before using it.
	if not is_instance_valid(stats_component):
		push_warning("handle_damage called on %s, but no StatsComponent was found." % name)
		return
		
	var my_multiplayer_authority = get_multiplayer_authority()
	stats_component.server_take_damage.rpc_id(my_multiplayer_authority, damage_amount, attacker_id)

# This new public function is the player's API for receiving data.
func apply_persistent_data(data: Resource, is_transition: bool) -> void:
	# This is the same logic as before, just refactored into a function.
	stats_component.stats_data = data.player_stats_data
	inventory_component.inventory_data = data.player_inventory_data
	equipment_component.equipment_data = data.player_equipment_data
	
	if is_transition:
		# On SCENE TRANSITION, apply the carried-over health and mana.
		stats_component.current_health = data.current_health
		stats_component.current_mana = data.current_mana
		if data.target_spawn_position != Vector2.INF:
			call_deferred("set_global_position", data.target_spawn_position)
	else:
		# On SAVE LOAD, restore to full health and mana.
		stats_component.current_health = stats_component.stats_data.max_health
		stats_component.current_mana = stats_component.stats_data.max_mana

	# Tell the UI to update.
	stats_component.refresh_stats()
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.character_sheet:
		hud.character_sheet.redraw()
		
# This is our new, reusable function that does the actual work.
func _apply_data_dictionary(data: Dictionary):
	# We received our data dictionary from the server, now apply it.
	
	# dynamic stats application
	var stats_dictionary = data["stats_data"]
	for stat_name in stats_dictionary:
		# Use set() to apply the value using the stat's name (the dictionary key)
		stats_component.stats_data.set(stat_name, stats_dictionary[stat_name])

	# Clear ALL old item data first for a clean slate.
	inventory_component.inventory_data.items.clear()
	for slot in equipment_component.equipment_data.equipped_items:
		equipment_component.equipment_data.equipped_items[slot] = null
		
	# Re-add items to the main inventory.
	for item_path in data["inventory_items"]:
		# THE FIX: Use the database instead of load()
		var item_resource = ItemDatabase.get_item(item_path)
		if is_instance_valid(item_resource):
			inventory_component.inventory_data.items.append(item_resource)
		
	# Re-equip items to their correct slots.
	for slot_str in data["equipped_items"]:
		var item_path = data["equipped_items"][slot_str]
		# The dictionary keys are strings from JSON, so we convert them back to int for the slot.
		var slot_index = int(slot_str) 
		if item_path != null:
			# THE FIX: Use the database instead of load()
			var item_resource = ItemDatabase.get_item(item_path)
			if is_instance_valid(item_resource):
				equipment_component.equipment_data.equipped_items[slot_index] = item_resource

	# Manually emit signals AFTER all data has been rebuilt.
	inventory_component.inventory_changed.emit()
	equipment_component.equipment_changed.emit()
	
	# Apply live stats/mana AFTER stats and equipment are set
	stats_component.recalculate_max_stats() # Recalculate totals based on new items
	stats_component.current_health = data["current_health"]
	stats_component.current_mana = data["current_mana"]
	
	# Finally, tell the UI to update with all the new data.
	stats_component.refresh_stats()
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and is_instance_valid(hud.character_sheet):
		hud.character_sheet.redraw()

# -- Signal Handlers --
# Called by this player's own StatsComponent when its health reaches zero.
## Player death function for Player
func _on_death(_attacker_id: int) -> void:
	state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.DEAD])
	
	# Create an instance of our Game Over screen.
	var game_over_instance = GameOverScreen.instantiate()
	
	# Guard Clause: Before adding a child, ensure the current_scene is valid.
	# This prevents a crash if the player dies during a volatile moment, like a scene transition.
	var current_scene = get_tree().current_scene
	if !is_instance_valid(current_scene):
		push_error("Player died but could not find a valid current_scene to add GameOverScreen to.")
		# We still want to free the instance we created to prevent a memory leak.
		game_over_instance.queue_free()
		return
		
	# Add it to the parent (level) scene tree.
	current_scene.add_child(game_over_instance)

# This function is called by the EventBus when the game state changes.
func _on_game_state_changed(new_state: EventBus.GameState) -> void:
	# Determine if gameplay should be active based on the new state.
	var is_gameplay_active: bool = (new_state == EventBus.GameState.GAMEPLAY)
	
	# This is the correct way to enable/disable the FSM.
	state_machine.set_physics_process(is_gameplay_active)
	state_machine.set_process_unhandled_input(is_gameplay_active)

	# If gameplay is NOT active, we must also ensure the player stops moving.
	if not is_gameplay_active:
		if movement_component:
			movement_component.stop()
			
func check_fsm_status():
	print("--- FSM STATUS CHECK ---")
	print("Is StateMachine processing physics? ", state_machine.is_physics_processing())
			
# -- RPCs ---
@rpc("any_peer", "call_local")
func award_xp_rpc(amount: int):
	# When this RPC is called by the server, award the XP.
	stats_component.add_xp(amount)
	
# This RPC is called by the server on the specific client that owns this player.
# It sets the character's starting position in the level.
@rpc("any_peer", "call_local", "reliable")
func set_initial_position(pos: Vector2):
	global_position = pos

# This RPC is called BY the server ON a specific client to deliver their data.
# The RPC function is now just a simple wrapper that calls our new function.
@rpc("any_peer", "call_local", "reliable")
func client_apply_transition_data(data: Dictionary):
	_apply_data_dictionary(data)

# RPC called BY the server ON a client, asking for their data.
@rpc("any_peer", "call_local", "reliable")
func client_gather_and_send_data():
	# This client has been asked for its data. Gather it now.
	var data_dictionary = GameManager.get_player_data_as_dictionary(self)
	# Send the data back to the server.
	server_receive_data.rpc_id(1, multiplayer.get_unique_id(), data_dictionary)

# RPC called BY a client ON the server, delivering the requested data.
@rpc("any_peer", "call_local", "reliable")
func server_receive_data(player_id: int, player_data: Dictionary):
	if not multiplayer.is_server():
		return
	
	# The server has received the data from a client and stores it.
	GameManager.all_players_transition_data[player_id] = player_data
	print("[SERVER] Received and stored data from client %s." % player_id)
