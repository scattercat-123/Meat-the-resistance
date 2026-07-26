extends Area2D

var taken := false

func _ready() -> void:
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(self, "position:y", position.y - 6.0, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "position:y", position.y, 0.7).set_trans(Tween.TRANS_SINE)
	body_entered.connect(_on_body_entered)

	var rot := get_tree().create_timer(10.0)
	rot.timeout.connect(func():
		if taken or not is_instance_valid(self):
			return
		var blink := create_tween()
		blink.set_loops(5)
		blink.tween_property(self, "modulate:a", 0.25, 0.2)
		blink.tween_property(self, "modulate:a", 1.0, 0.2)
		blink.finished.connect(queue_free)
	)

func _on_body_entered(body: Node) -> void:
	if taken or not body.is_in_group("player"):
		return
	taken = true
	body.eat_meat(8.0)
	set_deferred("monitoring", false)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.1)
	tw.tween_callback(queue_free)
