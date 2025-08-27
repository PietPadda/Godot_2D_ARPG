# hud.gd
extends CanvasLayer

# scene nodes
@onready var health_bar: ProgressBar = $PlayerHealthBar
@onready var health_label: Label = $PlayerHealthBar/HealthLabel # child of healthbar
@onready var mana_bar: ProgressBar = $PlayerManaBar
@onready var mana_label: Label = $PlayerManaBar/ManaLabel # child of manabar
@onready var inventory_panel = $InventoryPanel
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
		
		# Manually update bars once on startup to get the initial value.
		on_player_health_changed(player_stats.current_health, player_stats.stats_data.max_health)
		on_player_mana_changed(player_stats.current_mana, player_stats.stats_data.max_mana)
		
		# Connect to the new inventory signal.
		var player_inventory = player.get_node("InventoryComponent")
		player_inventory.inventory_changed.connect(inventory_panel.redraw)
		# Call the new initialize function ONCE.
		inventory_panel.initialize_inventory(player_inventory.inventory_data)
		
		connect_inventory_slots() # Connect the slots after they are created.
		player_inventory.inventory_changed.connect(connect_inventory_slots) # Reconnect when inventory redraws.

		var player_equipment: EquipmentComponent = player.get_node("EquipmentComponent")
		# Pass the component references to the character sheet controller.
		character_sheet.inventory_component = player_inventory
		character_sheet.equipment_component = player_equipment

func _unhandled_input(event: InputEvent) -> void:
	# Toggle the inventory panel's visibility.
	if Input.is_action_just_pressed("toggle_inventory"):
		inventory_panel.visible = not inventory_panel.visible
	
	# Toggle the character sheet panel's visibility
	if Input.is_action_just_pressed("toggle_character_sheet"): # "C"
		character_sheet.visible = not character_sheet.visible
		# Redraw the sheet every time it's opened to ensure it's up to date.
		if character_sheet.visible:
			character_sheet.redraw()
	
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

# This function runs when an inventory slot's "clicked" signal is emitted.
# For now, it will just print a message.
func _on_inventory_slot_clicked(item_data: ItemData) -> void:
	print("Clicked on item in inventory: ", item_data.item_name)

# We need a central place to connect all the slot signals.
func connect_inventory_slots() -> void:
	for slot in inventory_panel.grid_container.get_children():
		# Check if it's not already connected to prevent duplicates.
		if not slot.slot_clicked.is_connected(_on_inventory_slot_clicked):
			slot.slot_clicked.connect(_on_inventory_slot_clicked)
