extends Node2D

var music_scene = preload("res://Assets/scenes/music.tscn").instantiate()

func _ready() -> void:
	await get_tree().create_timer(5.0).timeout
	add_child(music_scene)
