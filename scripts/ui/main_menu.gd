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
	
	# --- THE FIX ---
	# Instead of destroying the World, we tell our SceneManager
	# to load the main level inside the LevelContainer.
	Scene.transition_to_scene("res://scenes/levels/main.tscn")
	
	# We can now remove the main menu from the screen.
	self.queue_free()

# When the "Join" button is pressed, call the NetworkManager with the IP address.
func _on_join_button_pressed():
	# Add this line to prevent old data from interfering with our spawn position.
	GameManager.player_data_on_transition = null
	
	NetworkManager.join_game(ip_address_edit.text)
	
	# --- THE FIX ---
	# The client also uses the SceneManager. It doesn't need to load the
	# scene, as the server will handle spawning it in the correct level.
	# We just need to remove the main menu.
	# get_tree().change_scene_to_file("res://scenes/levels/main.tscn")
	self.queue_free()
