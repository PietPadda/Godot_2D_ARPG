# scripts/ui/shop_panel.gd
# Manages the Shop UI panel, including its display and interactions.
class_name ShopPanel
extends PanelContainer

# Emitted when the panel is closed, allowing other systems to react.
signal closed

# This function is automatically called when the CloseButton is pressed.
func _on_close_button_pressed() -> void:
	close_panel()

# Centralized function for closing the panel. Can be called from other events too (like pressing Escape).
func close_panel() -> void:
	closed.emit() # emit the shop panel is closed
	queue_free() # This safely removes the UI panel from the game.
