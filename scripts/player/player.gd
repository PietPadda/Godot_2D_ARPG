# player.gd
extends CharacterBody2D

# preload scenes to instance
const GameOverScreen = preload("res://scenes/ui/game_over_screen.tscn")

# get components
@onready var stats_component: StatsComponent = $StatsComponent
@onready var inventory_component: InventoryComponent = $InventoryComponent
@onready var equipment_component: EquipmentComponent = $EquipmentComponent
@onready var state_machine: StateMachine = $StateMachine
@onready var camera: Camera2D = $Camera2D

# consts and vars
var _first_physics_frame_checked: bool = false

# This is a built-in Godot function.
func _enter_tree() -> void:
	# The player's name is its multiplayer ID, set by the server upon creation.
	# We convert the name (which is a String) to an integer.
	# The engine error log specifically tells us to set authority here.
	set_multiplayer_authority(int(name))

func _ready() -> void:
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
	camera.make_current() # <-- Add this line
	
	# Check for SAVE GAME data first (highest priority).
	if is_instance_valid(GameManager.loaded_player_data):
		# Swap our default resources with the loaded ones.
		stats_component.stats_data = GameManager.loaded_player_data.player_stats_data
		# Apply the loaded inventory data
		var inventory_component = get_node("InventoryComponent")
		inventory_component.inventory_data = GameManager.loaded_player_data.player_inventory_data
		# Apply the loaded equipment data
		var equipment_component = get_node("EquipmentComponent")
		equipment_component.equipment_data = GameManager.loaded_player_data.player_equipment_data
		
		# On SAVE LOAD, restore to full health and mana (Diablo II style).
		stats_component.current_health = stats_component.stats_data.max_health
		stats_component.current_mana = stats_component.stats_data.max_mana

		# Tell the UI to update.
		stats_component.refresh_stats()

		# Clear the data from the manager so it's not reused.
		GameManager.loaded_player_data = null
		
		# We need to manually tell the UI to redraw after loading all the data
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.character_sheet:
			hud.character_sheet.redraw()
			
	# If not loading a save, check for TRANSITION data.
	elif is_instance_valid(GameManager.player_data_on_transition):
		var transition_data = GameManager.player_data_on_transition
		stats_component.stats_data = transition_data.player_stats_data
		get_node("InventoryComponent").inventory_data = transition_data.player_inventory_data
		get_node("EquipmentComponent").equipment_data = transition_data.player_equipment_data
		
		# Check if a target spawn position was carried over.
		if transition_data.target_spawn_position != Vector2.INF:
			# Use call_deferred to wait for the physics engine to settle.
			call_deferred("set_global_position", transition_data.target_spawn_position)
		
		# On SCENE TRANSITION, apply the carried-over health and mana.
		stats_component.current_health = transition_data.current_health
		stats_component.current_mana = transition_data.current_mana
		
		# Tell the UI to update.
		stats_component.refresh_stats()
		
		# Clear the transition data from the manager so it's not reused.
		GameManager.player_data_on_transition = null
		
	# Connect signals only for the local player.
	stats_component.died.connect(_on_death) # player died
	EventBus.game_state_changed.connect(_on_game_state_changed) # game state change
	
	# This block only runs for the player we control. This is the perfect place
	# to announce that the local player is ready.
	EventBus.emit_signal("local_player_spawned", self)
	
	# Manually call the handler on startup to set the initial correct state.
	_on_game_state_changed(EventBus.current_game_state)

# We need to add _physics_process to see the position on the first frame of gameplay.
func _physics_process(delta: float) -> void:
	# This code will only run once for our controlled character.
	if is_multiplayer_authority() and not _first_physics_frame_checked:
		_first_physics_frame_checked = true

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
		var movement_component = get_node_or_null("GridMovementComponent")
		if movement_component:
			movement_component.stop()
			
# -- Remote Procedure Calls (RPCs) ---
@rpc("any_peer", "call_local")
func award_xp_rpc(amount: int):
	# When this RPC is called by the server, award the XP.
	stats_component.add_xp(amount)
	
# Re-add this function. It allows the server to tell an owning client where to start.
@rpc("any_peer", "call_local")
func set_initial_position(pos: Vector2):
	if multiplayer.get_remote_sender_id() == 1:
		global_position = pos
