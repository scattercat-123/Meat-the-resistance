extends Node2D

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

@export var spawn_interval := 2.0
@export var spawn_radius := 400.0

func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = spawn_interval
	timer.autostart = true
	timer.timeout.connect(_spawn_enemy)
	add_child(timer)

func _spawn_enemy() -> void:
	var enemy := ENEMY_SCENE.instantiate()
	var angle := randf() * TAU
	enemy.global_position = Vector2(cos(angle), sin(angle)) * spawn_radius
	add_child(enemy)
	GameManager.enemies_alive += 1
