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
# When the "Host" button is pressed, call the NetworkManager.
func _on_host_button_pressed():
	NetworkManager.host_game()
	# For now, we'll just immediately switch to the main game scene.
	# Later, this would transition to a lobby screen.
	get_tree().change_scene_to_file("res://scenes/levels/main.tscn")

# When the "Join" button is pressed, call the NetworkManager with the IP address.
func _on_join_button_pressed():
	# Add this line to prevent old data from interfering with our spawn position.
	GameManager.player_data_on_transition = null
	
	NetworkManager.join_game(ip_address_edit.text)
	# The client also switches to the main game scene. The NetworkManager will
	# tell us if the connection fails.
	# The client also switches to the main game scene.
	get_tree().change_scene_to_file("res://scenes/levels/main.tscn")
