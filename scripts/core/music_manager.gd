# file: scripts/core/music_manager.gd
# A global singleton for managing background music and transitions.
class_name MusicManager
extends Node

# get scene nodes
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

# vars
var current_track: MusicTrackData = null
var current_tween: Tween

# The main public function to play a new music track.
func play_music(track_data: MusicTrackData) -> void:
	if not track_data or track_data == current_track:
		return # Don't replay the same track.

	# If a tween is already running, kill it to prevent conflicts.
	if current_tween:
		current_tween.kill()

	# If a track is currently playing, fade it out first.
	if audio_player.playing:
		current_tween = create_tween()
		# Fade volume to "silence" (-80 db is effectively inaudible).
		current_tween.tween_property(audio_player, "volume_db", -80.0, track_data.fade_out_time)
		# After fading out, call the function to play the new track.
		current_tween.tween_callback(_play_new_track.bind(track_data))
	else:
		# If nothing is playing, just start the new track immediately.
		_play_new_track(track_data)

# Public function to stop the music with a fade-out.
func stop_music(fade_out_time: float = 1.0) -> void:
	if not audio_player.playing:
		return

	if current_tween:
		current_tween.kill()
	
	current_track = null
	current_tween = create_tween()
	current_tween.tween_property(audio_player, "volume_db", -80.0, fade_out_time)
	current_tween.tween_callback(audio_player.stop)

# Internal function to handle the actual switch and fade-in.
func _play_new_track(track_data: MusicTrackData) -> void:
	# Add a safety check in case the resource is missing its stream.
	if not track_data.stream:
		push_error("Music track data is missing its audio stream!")
		return
		
	current_track = track_data
	audio_player.stream = track_data.stream
	audio_player.volume_db = -80.0 # Start silent
	audio_player.play()

	current_tween = create_tween()
	# Fade in to the track's target volume.
	current_tween.tween_property(audio_player, "volume_db", track_data.volume_db, track_data.fade_in_time)
