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
		
		# --- THIS IS THE FIX ---
		# Disable the physics on the CharacterBody2D for this puppet.
		# Its movement will now be driven ONLY by the MultiplayerSynchronizer.
		set_physics_process(false)
		
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
	
	# Manually call the handler on startup to set the initial correct state.
	_on_game_state_changed(EventBus.current_game_state)

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
