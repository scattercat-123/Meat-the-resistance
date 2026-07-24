extends Node

var score := 0
var enemies_alive := 0

func on_enemy_died() -> void:
	score += 1
	enemies_alive -= 1
