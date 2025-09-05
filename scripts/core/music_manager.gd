# scripts/core/music_manager.gd
# A global singleton for managing background music and transitions.
class_name MusicManager
extends Node

# get scene nodes
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

# vars
var current_track: MusicTrackData = null
var active_transition_tween: Tween = null

# The main public function to play a new music track.
func play_music(new_track: MusicTrackData) -> void:
	# If the requested track is already playing and no transition is active, do nothing.
	if new_track == current_track and not active_transition_tween:
		return # do nothing

	# If there's an active transition, kill it immediately. We have a new command.
	if active_transition_tween:
		active_transition_tween.kill()
		
	# Create a new, authoritative tween for this entire operation.
	active_transition_tween = create_tween()
	# When the tween finishes ALL its tasks, clean up the reference.
	active_transition_tween.finished.connect(func(): active_transition_tween = null)

	# The Transition Sequence
	# If music is currently audible, fade it out first.
	if audio_player.playing and audio_player.volume_db > -79.0:
		var fade_time = current_track.fade_out_time if current_track else 1.0
		active_transition_tween.tween_property(audio_player, "volume_db", -80.0, fade_time)

	# Chain the track switch callback. This will run after the fade-out (if any).
	active_transition_tween.tween_callback(_play_new_track.bind(new_track))

	# Chain the fade-in for the new track.
	active_transition_tween.tween_property(audio_player, "volume_db", new_track.volume_db, new_track.fade_in_time)

# Public function to stop the music with a fade-out.
func stop_music(fade_out_time: float = 1.0) -> void:
	if not audio_player.playing:
		return

	if active_transition_tween:
		active_transition_tween.kill()
	
	current_track = null
	active_transition_tween = create_tween()
	active_transition_tween.finished.connect(func(): active_transition_tween = null) # Also cleanup here
	active_transition_tween.tween_property(audio_player, "volume_db", -80.0, fade_out_time)
	active_transition_tween.tween_callback(audio_player.stop)

# Internal function that is ONLY responsible for switching the audio stream.
func _play_new_track(track_data: MusicTrackData) -> void:
	# Add a safety check in case the resource is missing its stream.
	if not is_instance_valid(track_data) or not track_data.stream:
		push_error("Music track data or its audio stream is invalid!")
		return
		
	current_track = track_data # set track
	audio_player.stream = track_data.stream # update stream
	audio_player.play()
