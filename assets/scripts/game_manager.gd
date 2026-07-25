extends Node

signal enemy_died
signal hit_landed
signal player_hurt

const SFX := {
	"swing": preload("res://assets/audio/swing.wav"),
	"hit": preload("res://assets/audio/hit.wav"),
	"hurt": preload("res://assets/audio/hurt.wav"),
	"dash": preload("res://assets/audio/dash.wav"),
	"enemy_die": preload("res://assets/audio/enemy_die.wav"),
	"upgrade": preload("res://assets/audio/upgrade.wav"),
	"game_over": preload("res://assets/audio/game_over.wav"),
	"splat": preload("res://assets/audio/splat.wav"),
}

var score := 0
var enemies_alive := 0
var arena_bound := Vector2(960, 540)
var dash_slots := 0
var max_dash_slots := 0

func request_dash_slot() -> bool:
	if dash_slots > 0:
		dash_slots -= 1
		return true
	return false

func release_dash_slot() -> void:
	dash_slots = min(dash_slots + 1, max_dash_slots)

var _voices: Array[AudioStreamPlayer] = []

func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_voices.append(p)

func play(sound: String, volume_db := 0.0) -> void:
	for p in _voices:
		if not p.playing:
			p.stream = SFX[sound]
			p.volume_db = volume_db
			p.play()
			return

func on_enemy_died() -> void:
	score += 1
	enemies_alive -= 1
	enemy_died.emit()

func on_hit_landed() -> void:
	hit_landed.emit()

func on_player_hurt() -> void:
	player_hurt.emit()
