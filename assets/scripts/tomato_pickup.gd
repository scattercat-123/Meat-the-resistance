extends Area2D

func _ready() -> void:
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
