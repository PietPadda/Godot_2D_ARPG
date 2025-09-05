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

	# If a tween is already running, kill it to cancel any pending operations.
	if current_tween:
		current_tween.kill()
		
	# Always create a new, fresh tween for this operation.
	current_tween = create_tween()
	# When this new tween finishes ALL its tasks, it will call our cleanup function.
	current_tween.finished.connect(_on_tween_finished)

	# If a track is currently playing, fade it out first.
	if audio_player.playing and audio_player.volume_db > -79.0:
		var fade_time = 2.0 # set a default
		if current_track: # if there is a time in the data resource
			fade_time = current_track.fade_out_time # update it
			
		# Fade volume to "silence" (-80 db is effectively inaudible).
		current_tween.tween_property(audio_player, "volume_db", -80.0, fade_time)
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
	current_tween.finished.connect(_on_tween_finished) # Also connect the cleanup here.
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

	# The fade-in is now part of the SAME tween.
	current_tween.tween_property(audio_player, "volume_db", track_data.volume_db, track_data.fade_in_time)

# This is our cleanup function. It runs when a tween is truly finished.
func _on_tween_finished() -> void:
	# Set the reference to null so the manager knows it's free.
	current_tween = null
