# scripts/tools/WallSyncTool.gd
@tool
class_name WallSyncTool
extends Node

# scene nodes
@export var source_map: TileMapLayer
@export var destination_map: TileMapLayer

# This function runs automatically when the scene is opened in the editor.
func _ready() -> void:
	# Ensure this code ONLY runs in the editor, not in the game.
	if Engine.is_editor_hint():
		# Wait one frame to ensure all other nodes are ready.
		await get_tree().process_frame
		_sync_tilemaps()

# The core logic for copying the tiles.
func _sync_tilemaps() -> void:
	if not is_instance_valid(source_map) or not is_instance_valid(destination_map):
		return

	print("Auto-syncing wall tiles to shadow caster...")
	destination_map.clear()
	var used_cells = source_map.get_used_cells()

	for cell in used_cells:
		var source_id = source_map.get_cell_source_id(cell)
		var atlas_coords = source_map.get_cell_atlas_coords(cell)
		var alternative_tile = source_map.get_cell_alternative_tile(cell)
		destination_map.set_cell(cell, source_id, atlas_coords, alternative_tile)

	print("Sync complete.")
