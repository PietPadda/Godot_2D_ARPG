# equipment_slot.gd
extends PanelContainer

# We will emit this signal when the slot is clicked to unequip the item.
## Equipment slot left clicked signal
signal slot_clicked(slot_type, item_data)
# Signals for tooltip management.
signal show_tooltip(item_data, slot_node)
signal hide_tooltip()

# We'll set this in the editor to define what kind of slot this is.
## Equipment type
@export var slot_type: ItemData.EquipmentSlot

var current_item: ItemData

# Scene nodes
@onready var item_texture: TextureRect = $ItemTexture
@onready var slot_name_label: Label = $SlotNameLabel

func _ready() -> void:
	# Set the label text based on the enum value.
	slot_name_label.text = ItemData.EquipmentSlot.keys()[slot_type] # eq type
	# Connect the mouse signals.
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
# ---Public API---
func update_slot(item_data: ItemData) -> void:
	current_item = item_data # get item data
	if item_data:
		item_texture.texture = item_data.texture
		item_texture.visible = true
	else: # if none, empty
		item_texture.texture = null
		item_texture.visible = false

# ---Signal Handlers---
# mouse click
func _on_gui_input(event: InputEvent) -> void:
	# Detect a left mouse click on this slot.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# If there's an item in this slot, emit the signal.
		if current_item:
			emit_signal("slot_clicked", slot_type, current_item)

# mouse hover
func _on_mouse_entered() -> void:
	if current_item:
		emit_signal("show_tooltip", current_item, self)

# mouse unhover
func _on_mouse_exited() -> void:
	emit_signal("hide_tooltip")
