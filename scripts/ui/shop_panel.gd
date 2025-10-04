# scripts/ui/shop_panel.gd
# Manages the Shop UI panel, including its display and interactions.
class_name ShopPanel
extends PanelContainer

# --- Scene Nodes ---
@onready var inventory_panel: PanelContainer = %InventoryPanel
@onready var gold_label: Label = %GoldLabel

# --- Properties ---
var inventory_component: InventoryComponent
var stats_component: StatsComponent

# --- Godot Lifecycle ---
# When the panel is created and ready, it immediately takes control.
func _ready() -> void:
	# Explicitly center the panel to ensure it's always visible.
	var viewport_size = get_viewport_rect().size
	self.position = (viewport_size - self.size) / 2.0

# --- Public API ---
func initialize(inv_comp: InventoryComponent, stats_comp: StatsComponent):
	self.inventory_component = inv_comp
	self.stats_component = stats_comp

	# Connect to signals to keep the UI up-to-date
	inventory_component.inventory_changed.connect(redraw)
	stats_component.gold_changed.connect(_on_gold_changed)

	# Initialize the UI
	inventory_panel.initialize_inventory(inventory_component.inventory_data)
	for slot in inventory_panel.grid_container.get_children():
		slot.slot_right_clicked.connect(_on_inventory_slot_right_clicked)

	# Manually draw once to show initial state
	redraw()

# --- Signal Handlers ---
# When the "Close" button is pressed, it now emits the same signal as the 'E' key.
func _on_close_button_pressed() -> void:
	EventBus.shop_panel_requested.emit()
	
func _on_inventory_slot_right_clicked(item_data: ItemData):
	# Sell the item
	inventory_component.remove_item(item_data)
	stats_component.add_gold(item_data.value)

func _on_gold_changed(total_gold: int):
	gold_label.text = "Gold: " + str(total_gold)

# --- Private Methods ---
# REMOVED: The close_panel function is no longer needed.

func redraw():
	# don't redraw if both inventory and stats not there
	if not is_instance_valid(inventory_component) or not is_instance_valid(stats_component):
		return
	inventory_panel.redraw(inventory_component.inventory_data) # redraw panel
	_on_gold_changed(stats_component.stats_data.gold) # get new gold
