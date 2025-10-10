# scripts/world/world.gd

# This is the persistent root of our game world. It loads the initial level.
extends Node2D

# We can set the starting level in the Inspector for this scene.
@export_file("*.tscn") var starting_level: String

func _ready() -> void:
	# This world is only responsible for loading the very first level.
	# The server is the only one who should decide this.
	if multiplayer.is_server():
		if not starting_level.is_empty():
			# We use our existing SceneManager to handle the logic.
			Scene.transition_to_scene.call_deferred(starting_level)
