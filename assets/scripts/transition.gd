extends CanvasLayer

var cover: Node2D
var steak: Sprite2D
var busy := false

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	cover = Node2D.new()
	var r := ColorRect.new()
	r.size = Vector2(2600, 1600)
	r.position = Vector2(-1300, -800)
	r.color = Color(0.07, 0.07, 0.09)
	cover.add_child(r)
	var edge := ColorRect.new()
	edge.size = Vector2(56, 1600)
	edge.position = Vector2(1300, -800)
	edge.color = Color(0.73, 0.22, 0.18)
	cover.add_child(edge)
	var tail := ColorRect.new()
	tail.size = Vector2(56, 1600)
	tail.position = Vector2(-1356, -800)
	tail.color = Color(0.73, 0.22, 0.18)
	cover.add_child(tail)
	steak = Sprite2D.new()
	steak.texture = preload("res://assets/images/weapon/steak_small.png")
	steak.scale = Vector2(7, 7)
	cover.add_child(steak)
	cover.rotation = 0.06
	cover.position = Vector2(-3200, 540)
	add_child(cover)

func swipe_to(path: String) -> void:
	if busy:
		return
	busy = true
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(cover, "position:x", 960.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(steak, "rotation", TAU, 0.4)
	await tw.finished
	get_tree().paused = false
	if path == "":
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw2.set_parallel(true)
	tw2.tween_property(cover, "position:x", 5200.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw2.tween_property(steak, "rotation", TAU * 2.0, 0.4)
	await tw2.finished
	cover.position.x = -3200
	steak.rotation = 0.0
	busy = false
