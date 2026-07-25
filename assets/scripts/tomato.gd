extends Node2D

var dir := Vector2.RIGHT
var damage := 10.0
var speed := 700.0

func _process(delta: float) -> void:
	rotation += 14.0 * delta
	global_position += dir * speed * delta
	for n in get_parent().get_children():
		if n.has_method("apply_knockback") and not n.dying and global_position.distance_to(n.global_position) < 40.0:
			_splat(n)
			return
	var b := GameManager.arena_bound
	if absf(global_position.x) > b.x + 40.0 or absf(global_position.y) > b.y + 40.0:
		queue_free()

func _splat(victim: Node2D) -> void:
	victim.take_damage(damage, global_position)
	GameManager.play("splat", -2.0)
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 14
	p.lifetime = 0.4
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 240.0
	p.gravity = Vector2(0, 800)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = Color(0.85, 0.15, 0.1)
	p.position = global_position
	p.z_index = 40
	get_parent().add_child(p)
	get_tree().create_timer(0.5).timeout.connect(p.queue_free)
	queue_free()
