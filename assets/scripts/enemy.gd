extends CharacterBody2D

const FONT_PIXEL := preload("res://assets/fonts/pixelart.ttf")

@onready var change_state_timer: Timer = $change_state_timer
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var speed := 90.0
@export var max_health := 30.0
@export var contact_damage := 10.0

const DASH_SPEED := 700.0
const DASH_TIME := 0.3
const TELEGRAPH_TIME := 0.65

var last_animation_state = ""
var health := 0.0
var target: Node2D
var knockback := Vector2.ZERO
var dying = false
var follow = true
var angle
var angle_deg
var base_color: Color
var base_speed := 0.0
var damage_bonus := 0.0
var dash_state := "none"
var dash_dir := Vector2.ZERO
var telegraph: Node2D
var dash_timer: Timer

func _ready() -> void:
	randomize()
	health = max_health
	contact_damage += damage_bonus
	speed *= randf_range(0.85, 1.2)
	base_speed = speed
	target = get_tree().get_first_node_in_group("player")
	change_state_timer.wait_time = randf_range(3, 5)
	change_state_timer.start()

	dash_timer = Timer.new()
	dash_timer.one_shot = true
	dash_timer.wait_time = randf_range(3.0, 8.0)
	dash_timer.timeout.connect(_try_dash)
	add_child(dash_timer)
	dash_timer.start()

func _physics_process(delta: float) -> void:
	angle = velocity.angle()
	angle_deg = rad_to_deg(angle)
	if knockback.length() > 10.0:
		velocity = knockback
		knockback = knockback.move_toward(Vector2.ZERO, 700.0 * delta)
	elif dash_state == "telegraph":
		velocity = Vector2.ZERO
	elif dash_state == "dashing":
		velocity = dash_dir * DASH_SPEED
	elif target and follow:
		velocity = (target.global_position - global_position).normalized() * speed
		movement()
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	var b := GameManager.arena_bound
	global_position.x = clamp(global_position.x, -b.x, b.x)
	global_position.y = clamp(global_position.y, -b.y, b.y)

func _try_dash() -> void:
	dash_timer.wait_time = randf_range(4.0, 9.0)
	dash_timer.start()
	if dying or dash_state != "none" or not follow or target == null:
		return
	if global_position.distance_to(target.global_position) > 700.0:
		return
	if not GameManager.request_dash_slot():
		return
	dash_state = "telegraph"
	dash_dir = (target.global_position - global_position).normalized()
	_show_telegraph()
	await get_tree().create_timer(TELEGRAPH_TIME).timeout
	if dying or dash_state != "telegraph":
		return
	dash_state = "dashing"
	GameManager.play("dash", -10.0)
	await get_tree().create_timer(DASH_TIME).timeout
	_end_dash()

func _show_telegraph() -> void:
	telegraph = Node2D.new()
	telegraph.position = global_position
	telegraph.rotation = dash_dir.angle()
	telegraph.z_index = 5
	var r := ColorRect.new()
	var reach := DASH_SPEED * DASH_TIME + 60.0
	r.size = Vector2(reach, 46)
	r.position = Vector2(0, -23)
	r.color = Color(0.9, 0.15, 0.15, 0.3)
	telegraph.add_child(r)
	get_parent().add_child(telegraph)
	var tw := r.create_tween()
	tw.set_loops()
	tw.tween_property(r, "color:a", 0.08, 0.12)
	tw.tween_property(r, "color:a", 0.38, 0.12)

func _end_dash() -> void:
	if dash_state == "none":
		return
	dash_state = "none"
	GameManager.release_dash_slot()
	if is_instance_valid(telegraph):
		telegraph.queue_free()
	telegraph = null

func apply_knockback(dir: Vector2, force: float) -> void:
	knockback = dir * force

func apply_slow(factor: float, duration: float) -> void:
	speed = base_speed * factor
	sprite.modulate = Color(0.6, 0.75, 1.0)
	get_tree().create_timer(duration).timeout.connect(func():
		if not dying and is_instance_valid(self):
			speed = base_speed
			sprite.modulate = Color.WHITE
	)

func take_damage(amount: float, from := Vector2.INF) -> void:
	if dying:
		return
	_end_dash()
	health -= amount
	GameManager.play("hit")
	if from != Vector2.INF:
		apply_knockback((global_position - from).normalized(), 420.0)
	_hit_flash()
	_squash()
	_spawn_damage_number(amount)
	_spawn_splatter()
	if health <= 0:
		die()

func _hit_flash() -> void:
	sprite.modulate = Color(1.5, 0.2, 0.2, 1)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.18)

func _squash() -> void:
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.35, 0.65), 0.05)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)

func _spawn_damage_number(amount: float) -> void:
	var l := Label.new()
	l.text = str(int(amount))
	l.add_theme_font_override("font", FONT_PIXEL)
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	l.add_theme_color_override("font_outline_color", Color(0.2, 0.08, 0.04))
	l.add_theme_constant_override("outline_size", 8)
	l.z_index = 50
	l.position = global_position + Vector2(randf_range(-18, 18), -40)
	get_parent().add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 55.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.55).set_delay(0.15)
	tw.chain().tween_callback(l.queue_free)

func _spawn_splatter() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 10
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 70.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 260.0
	p.gravity = Vector2(0, 900)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = Color(0.35, 0.8, 0.35)
	p.position = global_position
	p.z_index = 40
	get_parent().add_child(p)
	get_tree().create_timer(0.6).timeout.connect(p.queue_free)

func die() -> void:
	_end_dash()
	dying = true
	collision_layer = 0
	contact_damage = 0.0
	set_physics_process(false)
	GameManager.play("enemy_die", -3.0)
	GameManager.on_enemy_died()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(sprite, "scale", Vector2(1.7, 1.7), 0.16)
	tw.tween_property(self, "modulate:a", 0.0, 0.16)
	tw.chain().tween_callback(queue_free)

func _on_change_state_timer_timeout() -> void:
	change_state_timer.wait_time = randf_range(3, 5)
	change_state_timer.start()
	change_state()

func movement():
	if angle_deg >= -22.5 and angle_deg < 22.5:
		last_animation_state = "right"
		sprite.play("walk_right")
	elif angle_deg >= 22.5 and angle_deg < 67.5:
		last_animation_state = "front_right"
		sprite.play("walk_front_right")
	elif angle_deg >= 67.5 and angle_deg < 112.5:
		last_animation_state = "front"
		sprite.play("walk_front")
	elif angle_deg >= 112.5 and angle_deg < 157.5:
		last_animation_state = "front_left"
		sprite.play("walk_front_left")
	elif angle_deg >= 157.5 or angle_deg < -157.5:
		last_animation_state = "left"
		sprite.play("walk_left")
	elif angle_deg >= -157.5 and angle_deg < -112.5:
		last_animation_state = "bottom_left"
		sprite.play("walk_bottom_left")
	elif angle_deg >= -112.5 and angle_deg < -67.5:
		last_animation_state = "bottom"
		sprite.play("walk_bottom")
	elif angle_deg >= -67.5 and angle_deg < -22.5:
		last_animation_state = "bottom_right"
		sprite.play("walk_bottom_right")

func change_state():
	if dying:
		return
	var rand = randi_range(1,3)
	if rand == 1:
		follow = true
		contact_damage = 10 + damage_bonus
	elif rand == 2:
		follow = false
		velocity = Vector2.ZERO
		idle(last_animation_state)
		contact_damage = 15 + damage_bonus
	elif rand == 3:
		follow = true
		contact_damage = 0

func idle(anim:String):
	if anim == "":
		return
	if anim == "bottom":
		anim = "back"
	var acc_anim = "idle_" + anim
	sprite.play(acc_anim)
