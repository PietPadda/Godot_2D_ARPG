# scripts/tools/spawner_monitor.gd
# A simple debug script to monitor what a MultiplayerSpawner is despawning.
extends Node

func _ready() -> void:
	# Get the direct parent of this node.
	var parent = get_parent()
	
	# The parent of this node MUST be a MultiplayerSpawner.
	if !parent  is MultiplayerSpawner:
		push_warning("SpawnerMonitor should be a child of a MultiplayerSpawner!")
		return

	# Connect to the spawner's "despawned" signal.
	parent.despawned.connect(_on_node_despawned)

func _on_node_despawned(node: Node):
	# This will only print on the server, where the signal is emitted.
	print("[SERVER SPAWNER] Despawned: %s (Class: %s, Path: %s)" % [node.name, node.get_class(), node.get_path()])
