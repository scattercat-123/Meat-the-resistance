extends Node2D
@onready var mouse_pos: Marker2D = $mouse_pos

var play_button_hover = false
var credits_hover = false
var settings_hover = false

func _ready() -> void:
	Input.warp_mouse(mouse_pos.position)

func _process(delta: float) -> void:
	pass

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
