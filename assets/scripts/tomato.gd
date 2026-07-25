extends Node2D

var target: Node2D
var damage := 25.0
var speed := 520.0
var last_dir := Vector2.RIGHT

func _process(delta: float) -> void:
	rotation += 12.0 * delta
	if is_instance_valid(target) and not target.dying:
		last_dir = (target.global_position - global_position).normalized()
		if global_position.distance_to(target.global_position) < 30.0:
			_splat()
			return
	global_position += last_dir * speed * delta
	var b := GameManager.arena_bound
	if absf(global_position.x) > b.x + 40.0 or absf(global_position.y) > b.y + 40.0:
		queue_free()

func _splat() -> void:
	target.take_damage(damage, global_position)
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
