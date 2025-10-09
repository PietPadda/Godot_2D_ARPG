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
			# We now use our new additive loading system to add the first level.
			var new_level_scene = load(starting_level)
			if new_level_scene:
				var level_instance = new_level_scene.instantiate()
				var container = get_tree().get_first_node_in_group("level_container")
				container.add_child(level_instance)
				# Add it to the SceneManager's tracking dictionary.
				Scene.active_levels[starting_level] = level_instance
