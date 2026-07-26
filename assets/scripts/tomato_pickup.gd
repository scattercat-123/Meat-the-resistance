extends Area2D

const FONT_PIXEL := preload("res://assets/fonts/meatfont.png")

func _ready() -> void:
	if not GameManager.tomato_hint_shown:
		GameManager.tomato_hint_shown = true
		var l := Label.new()
		l.text = "MOUSE 2 TO THROW"
		l.add_theme_font_override("font", FONT_PIXEL)
		l.add_theme_font_size_override("font_size", 22)
		l.add_theme_color_override("font_color", Color(0.95, 0.8, 0.35))
		l.position = Vector2(-136, -84)
		l.z_index = 45
		add_child(l)
		var lt := l.create_tween()
		lt.set_loops()
		lt.tween_property(l, "modulate:a", 0.35, 0.35)
		lt.tween_property(l, "modulate:a", 1.0, 0.35)
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(self, "position:y", position.y - 8.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "position:y", position.y, 0.6).set_trans(Tween.TRANS_SINE)
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	body.tomatoes += 1
	GameManager.play("upgrade", -10.0)
	set_deferred("monitoring", false)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.6, 1.6), 0.12)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(queue_free)
