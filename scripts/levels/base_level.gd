# scripts/levels/base_level.gd

# The foundational script for all game levels, containing common logic
# for player spawning, music, and network events.
class_name BaseLevel
extends Node2D # Both main.gd and town.gd extend Node2D


func _ready() -> void:
	# This function will be called by child classes that use super().
	# We will move common logic here in the next step.
	pass
