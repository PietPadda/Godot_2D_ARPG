# scripts/ui/main_menu.gd
extends Control

# --- Scene Nodes ---
@onready var host_button: Button = $VBoxContainer/HostButton
@onready var join_button: Button = $VBoxContainer/JoinButton
@onready var ip_address_edit: LineEdit = $VBoxContainer/IPAddressEdit

func _ready():
	host_button.pressed.connect(_on_host_button_pressed)
	join_button.pressed.connect(_on_join_button_pressed)

# --- Signal Handlers ---
# When the "Host" button is pressed, create a server and transition to the main level.
func _on_host_button_pressed():
	print("[HOST BOOTSTRAP] MainMenu: Host button pressed. Initiating first transition.")
	NetworkManager.host_game()
	
	# THE FIX: Authoritatively set the host's location BEFORE loading the level.
	var start_scene_path = "res://scenes/levels/town.tscn"
	GameManager.player_locations[1] = start_scene_path
	
	# Now, transition to that scene.
	Scene.transition_to_scene(start_scene_path)
	
	# The main menu's job is done, so we can safely remove it.
	self.queue_free()

# When the "Join" button is pressed, just connect to the server.
func _on_join_button_pressed():
	# The client should NOT change scenes on its own.
	# It simply connects and waits for the server to tell it which scene to load.
	GameManager.player_data_on_transition = null
	
	NetworkManager.join_game(ip_address_edit.text)
	
	# We remove the main menu, and then wait for the server's instructions.
	self.queue_free()
