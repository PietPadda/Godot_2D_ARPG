# scripts/levels/town.gd
extends BaseLevel

# Get direct references to the tilemap nodes in this scene.
@onready var floor_tilemap: TileMapLayer = $FloorTileMap
@onready var wall_tilemap: TileMapLayer = $WallTileMap

# Expose a slot in the Inspector for the music track.
@export var level_music: MusicTrackData

# The setup logic MUST be in _ready() to run once at the start.
func _ready():
	super() # This runs all the logic from BaseLevel._ready()
	
	# When the level loads, tell the GridManager about our tilemaps.
	Grid.register_level_tilemaps(floor_tilemap, wall_tilemap)
	
	# Play the music track that has been assigned in the Inspector.
	if level_music:
		Music.play_music(level_music)
	
	# Announce which level is setting the tilemap.
	print(self.scene_file_path, ": _ready() is setting Grid.tile_map_layer.")
	
# This function can now be left empty or used for other inputs.
func _unhandled_input(event: InputEvent) -> void:
	pass
