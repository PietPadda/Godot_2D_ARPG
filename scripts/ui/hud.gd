# hud.gd
extends CanvasLayer

# REMOVED: We no longer need to preload the scene.
# const ShopPanelScene = preload("res://scenes/ui/shop_panel.tscn")

# scene nodes
@onready var health_bar: ProgressBar = $PlayerHealthBar
@onready var health_label: Label = $PlayerHealthBar/HealthLabel # child of healthbar
@onready var mana_bar: ProgressBar = $PlayerManaBar
@onready var mana_label: Label = $PlayerManaBar/ManaLabel # child of manabar
@onready var xp_bar: ProgressBar = $PlayerXpBar
@onready var xp_label: Label = $PlayerXpBar/XpLabel # child of xpbar
@onready var player_inventory: PanelContainer = $PlayerInventory
@onready var character_sheet: PanelContainer = $CharacterSheet
@onready var shop_panel: PanelContainer = $ShopPanel

var _is_player_in_shop_range := false

func _ready() -> void:
	EventBus.local_player_spawned.connect(_on_local_player_spawned)
	EventBus.shop_panel_requested.connect(_on_shop_panel_requested)
	EventBus.player_entered_shop_range.connect(func(): _is_player_in_shop_range = true)
	EventBus.player_exited_shop_range.connect(func(): _is_player_in_shop_range = false)

func _unhandled_input(_event: InputEvent) -> void:
	# Toggle player inventory panel's visibility
	if Input.is_action_just_pressed("toggle_inventory"): # "I"
		player_inventory.visible = !player_inventory.visible
		# Redraw the inventory every time it's opened to ensure it's up to date.
		if player_inventory.visible:
			player_inventory.redraw() # redraw it
	
	# Toggle character sheet panel's visibility
	if Input.is_action_just_pressed("toggle_character_sheet"): # "C"
		character_sheet.visible = not character_sheet.visible
		if character_sheet.visible:
			character_sheet.redraw() # This will populate stats later
	
	# E to interact with shop npc
	if _is_player_in_shop_range and Input.is_action_just_pressed("interact"):
		_on_shop_panel_requested()
		
	# F5 to quick save
	if Input.is_action_just_pressed("save_game"):
		GameManager.save_game()
	
	# F6 to quick load
	if Input.is_action_just_pressed("load_game"):
		GameManager.load_game()

## handle hp updates
func on_player_health_changed(current_health: int, max_health: int) -> void:
	health_bar.max_value = max_health
	health_bar.value = current_health
	# Update the label's text with the current and max health.
	health_label.text = "%d / %d" % [current_health, max_health]

## handle mana updates
func on_player_mana_changed(current_mana: int, max_mana: int) -> void:
	mana_bar.max_value = max_mana
	mana_bar.value = current_mana
	mana_label.text = "%d / %d" % [current_mana, max_mana]

## handle xp & level updates
func on_player_xp_changed(level: int, current_xp: int, xp_to_next_level: int) -> void:
	xp_bar.max_value = xp_to_next_level
	xp_bar.value = current_xp
	xp_label.text = "Lvl %d: %d / %d XP" % [level, current_xp, xp_to_next_level]
	
# This function runs when the EventBus emits the signal.
func _on_shop_panel_requested() -> void:
	# Toggle the panel's visibility.
	shop_panel.visible = not shop_panel.visible
	
	# Update the game state based on the new visibility.
	if shop_panel.visible:
		# If we're opening the panel, tell it to redraw its contents.
		shop_panel.redraw()
		EventBus.change_game_state(EventBus.GameState.UI_MODE)
	else:
		EventBus.change_game_state(EventBus.GameState.GAMEPLAY)
			
# This new function runs ONLY when the local_player_spawned signal is received.
func _on_local_player_spawned(player: Node) -> void:
		# Ensure UI panels are hidden on spawn
	player_inventory.hide()
	shop_panel.hide()
	
		# Now that we have a guaranteed reference to the player, we connect to their stats.
	var player_stats = player.get_node("StatsComponent")
	var inventory_component = player.get_node("InventoryComponent")
	var player_equipment: EquipmentComponent = player.get_node("EquipmentComponent")
	
	# Connect our UI update function to the player's signal.
	player_stats.health_changed.connect(on_player_health_changed)
	player_stats.mana_changed.connect(on_player_mana_changed)
	player_stats.xp_changed.connect(on_player_xp_changed)
	
	# Manually update bars once using the component's final, calculated values.
	on_player_health_changed(player_stats.current_health, player_stats.total_max_health)
	on_player_mana_changed(player_stats.current_mana, player_stats.total_max_mana)
	on_player_xp_changed(player_stats.stats_data.level, player_stats.stats_data.current_xp, player_stats.stats_data.xp_to_next_level)
	
	# Initialize both panels with the player's components.
	player_inventory.initialize(inventory_component, player_equipment, player_stats)
	shop_panel.initialize(inventory_component, player_stats)
