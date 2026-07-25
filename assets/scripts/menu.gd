extends Node2D
@onready var mouse_pos: Marker2D = $mouse_pos
@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"
@onready var cutscene: VideoStreamPlayer = $"../cutscene"
@onready var skip_label: Label = $"../skip_label"

var play_button_hover = false
var credits_hover = false
var settings_hover = false
var skippable = false


func _ready() -> void:
	Input.warp_mouse(mouse_pos.position)

func _process(delta: float) -> void:
	if skippable == true and Input.is_action_just_pressed("attack"):
		animation_player.play("out")
		await animation_player.animation_finished
		get_tree().change_scene_to_file("res://assets/scenes/arena.tscn")
	
	if play_button_hover and Input.is_action_just_pressed("attack"):
		animation_player.play("play")
		await animation_player.animation_finished
		skip_label.visible = true
		animation_player.play("blink")
		cutscene.visible = true
		cutscene.play()
		skippable = true
		await cutscene.finished
		skip_label.visible = false
		animation_player.play("out")
		await animation_player.animation_finished
		get_tree().change_scene_to_file("res://assets/scenes/arena.tscn")
		

func _on_play_area_mouse_entered() -> void:
	play_button_hover = true

func _on_play_area_mouse_exited() -> void:
	play_button_hover = false

func _on_credits_area_mouse_entered() -> void:
	credits_hover = true

func _on_credits_area_mouse_exited() -> void:
	credits_hover = false

func _on_settings_area_mouse_entered() -> void:
	settings_hover = true

func _on_settings_area_mouse_exited() -> void:
	settings_hover = false
