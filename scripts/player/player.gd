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
	# DEBUG: Trace when a player node is ready.
	print("[%s] PLAYER _ready: Node '%s' is ready. Is it mine to control? %s" % [multiplayer.get_unique_id(), name, is_multiplayer_authority()])
	
	# Duplicate the data resources to make them unique to this player instance.
	# This prevents players from sharing inventories, stats, or equipment.
	if stats_component.stats_data:
		stats_component.stats_data = stats_component.stats_data.duplicate(true)
	if inventory_component.inventory_data:
		inventory_component.inventory_data = inventory_component.inventory_data.duplicate(true)
	if equipment_component.equipment_data:
		equipment_component.equipment_data = equipment_component.equipment_data.duplicate(true)
	
	# This is the crucial check. Do it first!
	if not is_multiplayer_authority():
		# This is a remote player's puppet.
		camera.enabled = false # disable the camera
		# Deactivate its StateMachine so it doesn't try to run logic.
		state_machine.set_physics_process(false)
		state_machine.set_process_unhandled_input(false)
		
		# Do nothing else
		return # This is the most important part!
	
	# Force this camera to be the active one for the viewport.
	camera.make_current()
	
	# Connect signals only for the local player.
	stats_component.died.connect(_on_death) # player died
	EventBus.game_state_changed.connect(_on_game_state_changed) # game state change
	
	# This block only runs for the player we control. This is the perfect place
	# to announce that the local player is ready.
	EventBus.emit_signal("local_player_spawned", self)
	
	# When equipment changes, tell the StatsComponent to recalculate.
	if equipment_component:
		equipment_component.equipment_changed.connect(stats_component.recalculate_max_stats)
	
	# Manually call the handler on startup to set the initial correct state.
	_on_game_state_changed(EventBus.current_game_state)
	
	# This ensures our stats are correct for any starting equipment.
	stats_component.recalculate_max_stats()
	
	# REMOVE the 'if is_multiplayer_authority()' block from the end of this function.
	# We are moving this logic to _physics_process.
	# if is_multiplayer_authority():
	# 	server_request_my_data.rpc_id(1)

# We need to add _physics_process to see the position on the first frame of gameplay.
func _physics_process(_delta: float) -> void:
	# This code will only run once for our controlled character.
	if is_multiplayer_authority() and not _first_physics_frame_checked:
		_first_physics_frame_checked = true
		# By running this here, we guarantee the server has had time to register us.
		server_request_my_data.rpc_id(1)

# --- Public API ---
# This function is now just a clean pass-through to the dedicated calculator.
func get_total_stat(stat_name: String) -> float:
	if stat_calculator:
		return stat_calculator.get_total_stat(stat_name)
	
	# no stats returned? error and give 0
	push_warning("StatCalculator not found on %s" % name)
	return 0.0
	
# This is the entity's public interface for taking damage.
func handle_damage(damage_amount: int, attacker_id: int) -> void:
	if stats_component:
		# The entity is responsible for communicating with its own components.
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

# -- Signal Handlers --
# This function is called when the StatsComponent emits the "died" signal.
## Player death function for Player
func _on_death(_attacker_id: int) -> void:
	# We tell our state machine to switch to the DeadState.
	state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.DEAD])
	
	# Create an instance of our Game Over screen.
	var game_over_instance = GameOverScreen.instantiate()
	# Add it to the parent (level) scene tree.
	get_tree().current_scene.add_child(game_over_instance)

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
@rpc("any_peer", "call_local", "reliable")
func client_apply_transition_data(data: Dictionary):
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

# Sent from a client to the server to request transition data.
@rpc("any_peer", "call_local", "reliable")
func server_request_my_data():
	# This function only needs to run on the server.
	if not multiplayer.is_server():
		return
	
	# Tell the GameManager to send this client their data.
	var client_id = multiplayer.get_remote_sender_id()
	GameManager.send_transition_data_to_player(client_id)
	
# This RPC is called BY the server ON a client to tell it to freeze
# its state in preparation for a scene transition.
@rpc("any_peer", "call_local", "reliable")
func client_prepare_for_transition():
	# Stop the state machine from processing input or physics. This effectively
	# freezes the player and stops it from sending any more network updates.
	state_machine.set_physics_process(false)
	state_machine.set_process_unhandled_input(false)
	# Also explicitly stop any movement.
	if movement_component:
		movement_component.stop()
		
# RPC called BY the server ON a client, asking for their data.
@rpc("authority", "call_local", "reliable")
func client_gather_and_send_data():
	# This client has been asked for its data. Gather it now.
	var data_dictionary = GameManager.get_player_data_as_dictionary(self)
	# Send the data back to the server via the GameManager singleton.
	GameManager.server_receive_client_data.rpc_id(1, multiplayer.get_unique_id(), data_dictionary)

# RPC called BY a client ON the server, delivering the requested data.
@rpc("any_peer", "call_local", "reliable")
func server_receive_data(player_id: int, player_data: Dictionary):
	if not multiplayer.is_server():
		return
	
	# The server has received the data from a client and stores it.
	GameManager.all_players_transition_data[player_id] = player_data
	print("[SERVER] Received and stored data from client %s." % player_id)
