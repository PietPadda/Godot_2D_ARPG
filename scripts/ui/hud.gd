# hud.gd
extends CanvasLayer

# Preload the panel scene we will be creating instances of.
const ShopPanelScene = preload("res://scenes/ui/shop_panel.tscn")

# scene nodes
@onready var health_bar: ProgressBar = $PlayerHealthBar
@onready var health_label: Label = $PlayerHealthBar/HealthLabel # child of healthbar
@onready var mana_bar: ProgressBar = $PlayerManaBar
@onready var mana_label: Label = $PlayerManaBar/ManaLabel # child of manabar
@onready var xp_bar: ProgressBar = $PlayerXpBar
@onready var xp_label: Label = $PlayerXpBar/XpLabel # child of xpbar
@onready var character_sheet = $CharacterSheet

func _ready() -> void:
	# Instead of trying to find the player, we now just listen for the announcement.
	EventBus.local_player_spawned.connect(_on_local_player_spawned)
		
	# The HUD now listens for requests to open the shop.
	EventBus.shop_panel_requested.connect(_on_shop_panel_requested)

func _unhandled_input(_event: InputEvent) -> void:
	# Toggle the character sheet panel's visibility
	if Input.is_action_just_pressed("toggle_character_sheet"): # "C"
		character_sheet.visible = not character_sheet.visible
		# Redraw the sheet every time it's opened to ensure it's up to date.
		if character_sheet.visible:
			character_sheet.redraw() # redraw it
	
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
	# Check if a shop panel already exists as a child of the HUD.
	var existing_panel = find_child("ShopPanel", true, false)
	if existing_panel:
		# If it exists, simply remove it.
		existing_panel.queue_free()
		# Also, ensure we return to gameplay state.
		EventBus.change_game_state(EventBus.GameState.GAMEPLAY)
	else:
		# If it does not exist, create a new one.
		var shop_panel_instance = ShopPanelScene.instantiate()
		# Add the panel as a child of the HUD. This is the crucial change.
		add_child(shop_panel_instance)
		
		# Get player components and initialize the shop
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var inv_comp = player.get_node("InventoryComponent")
			var stats_comp = player.get_node("StatsComponent")
			shop_panel_instance.initialize(inv_comp, stats_comp)
			
# This new function runs ONLY when the local_player_spawned signal is received.
func _on_local_player_spawned(player: Node) -> void:
	# Now that we have a guaranteed reference to the player, we connect to their stats.
	var player_stats = player.get_node("StatsComponent")
	# Connect our UI update function to the player's signal.
	player_stats.health_changed.connect(on_player_health_changed)
	player_stats.mana_changed.connect(on_player_mana_changed)
	player_stats.xp_changed.connect(on_player_xp_changed)
	
	# Manually update bars once using the component's final, calculated values.
	on_player_health_changed(player_stats.current_health, player_stats.total_max_health)
	on_player_mana_changed(player_stats.current_mana, player_stats.total_max_mana)
	on_player_xp_changed(player_stats.stats_data.level, player_stats.stats_data.current_xp, player_stats.stats_data.xp_to_next_level)
	
	# We only need to pass the components to the character sheet now.
	var player_inventory = player.get_node("InventoryComponent")
	var player_equipment: EquipmentComponent = player.get_node("EquipmentComponent")
	
	# Call the new, explicit initialize function
	character_sheet.initialize(player_inventory, player_equipment, player_stats)
