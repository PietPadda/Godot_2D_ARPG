# game_over_screen.gd
extends CanvasLayer

func _on_button_pressed() -> void:
	# This reloads the entire currently active scene.
	get_tree().reload_current_scene()
