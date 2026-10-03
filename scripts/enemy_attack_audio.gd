extends RefCounted
class_name EnemyAttackAudio

const WOOSH_SOUND: AudioStream = preload("res://assets/sounds/enemystandardattack.mp3")
const WOOSH_VOLUME_DB: float = -2.0

static func create_player(parent: Node2D, pitch: float) -> AudioStreamPlayer2D:
	var audio: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	audio.name = "AttackWooshSound"
	audio.stream = WOOSH_SOUND
	audio.pitch_scale = pitch
	audio.volume_db = WOOSH_VOLUME_DB
	parent.add_child(audio)
	return audio
