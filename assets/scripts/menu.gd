extends Node2D

var play_button_hover = false

func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_play_area_mouse_entered() -> void:
	play_button_hover = true

func _on_play_area_mouse_exited() -> void:
	play_button_hover = false


func _on_credits_area_mouse_entered() -> void:
	pass # Replace with function body.


func _on_credits_area_mouse_exited() -> void:
	pass # Replace with function body.


func _on_settings_area_mouse_entered() -> void:
	pass # Replace with function body.


func _on_settings_area_mouse_exited() -> void:
	pass # Replace with function body.
