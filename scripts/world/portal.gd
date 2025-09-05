# scripts/world/portal.gd
# A reusable portal that transitions the player to a new scene.
class_name Portal
extends Area2D

# ---Properties---
# This will expose a file path selector in the Inspector, filtered to scenes.
@export_file("*.tscn") var target_scene_path: String
# Get a reference to our spawn point marker.
@onready var spawn_point: Marker2D = $SpawnPoint

func _ready() -> void:
	# Connect our own body_entered signal to our handler function.
	body_entered.connect(_on_body_entered)

# ---Signal Handlers---
func _on_body_entered(body: Node2D) -> void:
	# First, check if the body that entered is the player.
	if body.is_in_group("player"):
		print("Player entered portal. Transitioning to: ", target_scene_path)
		# Call our global SceneManager to handle the transition.
		# Get the spawn point's global position and pass it along.
		Scene.change_scene(target_scene_path, spawn_point.global_position)
