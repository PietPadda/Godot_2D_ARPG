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
	# This check is vital for multiplayer. It ensures only the player who
	# actually controls their character can trigger the portal action.
	if body.is_multiplayer_authority():
		# Instead of calling the RPC directly, we defer a helper function.
		# Pass the specific player node that entered the portal.
		call_deferred("_request_transition", body)
		
# This new function contains our original RPC call.
func _request_transition(player: Node) -> void:
	print("Player entered portal. Requesting transition to: ", target_scene_path)
	
	# This client will now gather its own data and send it with the request.
	var my_id = multiplayer.get_unique_id()
	
	# Ask GameManager to package up the data for us.
	var data_dictionary = GameManager.get_player_data_as_dictionary(player)
	
	# Send the scene path, our ID, and our data package to the server.
	Scene.request_scene_transition.rpc_id(1, target_scene_path, my_id, data_dictionary)
