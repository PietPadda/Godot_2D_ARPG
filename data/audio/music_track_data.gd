# data/audio/music_track_data.gd
# A data container for a single music track's properties.
class_name MusicTrackData
extends Resource

# Description
## A data container for a single music track's properties.

@export var stream: AudioStream
@export var loop: bool = true
@export var volume_db: float = 0.0
@export var fade_in_time: float = 1.0
@export var fade_out_time: float = 1.0
