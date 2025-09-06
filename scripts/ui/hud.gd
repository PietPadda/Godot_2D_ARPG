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
	# We need a reference to the player to connect to their signals.
	# Using groups is a clean way to find the player.
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var player_stats = player.get_node("StatsComponent")
		# Connect our UI update function to the player's signal.
		player_stats.health_changed.connect(on_player_health_changed)
		player_stats.mana_changed.connect(on_player_mana_changed)
		player_stats.xp_changed.connect(on_player_xp_changed)
		
		# Manually update bars once on startup to get the initial value.
		on_player_health_changed(player_stats.current_health, player_stats.stats_data.max_health)
		on_player_mana_changed(player_stats.current_mana, player_stats.stats_data.max_mana)
		on_player_xp_changed(player_stats.stats_data.level, player_stats.stats_data.current_xp, player_stats.stats_data.xp_to_next_level)
		
		# We only need to pass the components to the character sheet now.
		var player_inventory = player.get_node("InventoryComponent")
		var player_equipment: EquipmentComponent = player.get_node("EquipmentComponent")
		
		# Call the new, explicit initialize function
		character_sheet.initialize(player_inventory, player_equipment, player_stats)
		
		# The HUD now listens for requests to open the shop.
		EventBus.shop_panel_requested.connect(_on_shop_panel_requested)

func _unhandled_input(event: InputEvent) -> void:
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
	# First, check if a shop panel already exists to prevent duplicates.
	if find_child("ShopPanel"):
		return

	var shop_panel_instance = ShopPanelScene.instantiate()
	# Add the panel as a child of the HUD. This is the crucial change.
	add_child(shop_panel_instance)
