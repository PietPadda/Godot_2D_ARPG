# scripts/core/debug_manager.gd
extends Node

# This function checks for global input events that aren't handled by the UI or game.
func _unhandled_input(event: InputEvent) -> void:
	# We only care about keyboard presses.
	if not event is InputEventKey:
		return

	# Check if our specific debug action was just pressed.
	if event.is_action_pressed("debug_respawn_enemies"):
		# CRITICAL: We only want the server/host to be able to run this command.
		if multiplayer.is_server():
			print("DEBUG: F2 pressed on server. Requesting enemy respawn.")
			# In the next step, we'll emit a global signal here.
