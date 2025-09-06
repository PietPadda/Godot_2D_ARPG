# scripts/core/network_manager.gd
extends Node

# Signal emitted when we successfully connect to a server.
signal connection_succeeded
# Signal emitted when we fail to connect.
signal connection_failed
# Signal emitted on the server when a new player joins.
signal player_connected(player_id)
# Signal emitted on the server when a player disconnects.
signal player_disconnected(player_id)
# Signal to tell the game world that a player needs to be spawned.
signal player_spawn_requested(player_id)

# --- Constants & Vars ---
const PLAYER_SCENE = preload("res://scenes/player/player.tscn")
const DEFAULT_PORT = 7777 # The default port for our game server.
var players = {} # A dictionary to store information about connected players.

func _ready():
	# Connect to the multiplayer API's signals to react to network events.
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

# --- Public API ---
# Call this to create a server.
func host_game():
	var peer = ENetMultiplayerPeer.new() # UDP only
	var error = peer.create_server(DEFAULT_PORT)
	if error != OK:
		print("Failed to create server!")
		return

	multiplayer.multiplayer_peer = peer
	print("Server created successfully. Waiting for players...")
	
	# Add the host player to the players dictionary.
	# The ID for the host is always 1.
	# Manually trigger the connection logic for the host, whose ID is always 1.
	_on_peer_connected(1)

# Call this to connect to a server at a given IP address.
func join_game(ip_address: String):
	var peer = ENetMultiplayerPeer.new()
	# Default to 127.0.0.1 (yourself) if no IP is provided.
	if ip_address == "":
		ip_address = "127.0.0.1"

	var error = peer.create_client(ip_address, DEFAULT_PORT)
	if error != OK:
		print("Failed to create client!")
		return

	multiplayer.multiplayer_peer = peer
	print("Joining game at %s..." % ip_address)
	
# This function is called by the game world when it's ready for players.
func spawn_existing_players():
	# Only the server should spawn players.
	if not multiplayer.is_server():
		return

	# Go through the list of already-connected players and request their spawn.
	for player_id in players:
		player_spawn_requested.emit(player_id)

# --- Signal Callbacks ---
func _on_peer_connected(id: int):
	print("Player connected: %d" % id)
	players[id] = { "name": "Player " + str(id) }
	player_connected.emit(id)
	
	# We NO LONGER emit the spawn request here immediately.
	# We wait for the main scene to tell us it's ready.


func _on_peer_disconnected(id: int):
	print("Player disconnected: %d" % id)
	players.erase(id)
	player_disconnected.emit(id)

func _on_connected_to_server():
	print("Successfully connected to server!")
	connection_succeeded.emit()

func _on_connection_failed():
	print("Failed to connect to server.")
	connection_failed.emit()

# --- Private Functions ---
# We DELETE the entire _spawn_player(id) function from this script.
