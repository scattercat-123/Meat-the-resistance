extends Node

signal enemy_died

var score := 0
var enemies_alive := 0
var arena_bound := Vector2(900, 500)

func on_enemy_died() -> void:
	score += 1
	enemies_alive -= 1
	enemy_died.emit()
