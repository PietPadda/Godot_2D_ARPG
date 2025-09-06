# scripts/ui/shop_panel.gd
# Manages the Shop UI panel, including its display and interactions.
class_name ShopPanel
extends PanelContainer

# Emitted when the panel is closed, allowing other systems to react.
signal closed

# When the panel is created and ready, it immediately takes control.
func _ready() -> void:
	# Explicitly center the panel to ensure it's always visible.
	var viewport_size = get_viewport_rect().size
	self.position = (viewport_size - self.size) / 2.0
	
	EventBus.change_game_state(EventBus.GameState.UI_MODE)

# This function is automatically called when the CloseButton is pressed.
func _on_close_button_pressed() -> void:
	close_panel()

# Centralized function for closing the panel. Can be called from other events too (like pressing Escape).
func close_panel() -> void:
	# Before closing, it returns control back to the player.
	EventBus.change_game_state(EventBus.GameState.GAMEPLAY)
	closed.emit() # emit the shop panel is closed
	queue_free() # This safely removes the UI panel from the game.
