extends CharacterBody2D

const FONT_PIXEL := preload("res://assets/fonts/meatfont.png")

@onready var change_state_timer: Timer = $change_state_timer
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var speed := 90.0
@export var max_health := 30.0
@export var contact_damage := 10.0

const DASH_SPEED := 700.0
const DASH_TIME := 0.3
const TELEGRAPH_TIME := 0.65

const SIGN_TEXTS := ["GO VEGAN", "MEAT IS MURDER", "EAT KALE", "TOFU 4EVER", "SAVE THE COWS", "PLANT POWER"]
const EGGPLANT_TEX := preload("res://assets/images/weapon/eggplant.png")
const MEAT_SCENE := preload("res://assets/scenes/meat_pickup.tscn")

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
var variant := "basic"
var casting := false
var lob_pending := false
var entered := false
var dash_state := "none"
var dash_dir := Vector2.ZERO
var telegraph: Node2D
var dash_timer: Timer
var bubble: Node2D

func _ready() -> void:
	randomize()
	health = max_health
	contact_damage += damage_bonus
	target = get_tree().get_first_node_in_group("player")
	change_state_timer.wait_time = randf_range(3, 5)
	change_state_timer.start()
	speed *= randf_range(0.85, 1.2)
	base_speed = speed
	sprite.speed_scale = randf_range(0.85, 1.15)
	dash_timer = Timer.new()
	dash_timer.one_shot = true
	dash_timer.wait_time = randf_range(3.0, 8.0)
	dash_timer.timeout.connect(_try_dash)
	add_child(dash_timer)
	dash_timer.start()

	match variant:
		"lobber":
			_setup_ability(randf_range(2.5, 5.0), _try_lob)
		"healer":
			_setup_ability(2.2, _heal_pulse, false)

func _setup_ability(wait: float, callback: Callable, one_shot := true) -> void:
	var t := Timer.new()
	t.one_shot = one_shot
	t.wait_time = wait
	t.timeout.connect(callback)
	t.name = "ability_timer"
	add_child(t)
	t.start()

func make_variant(kind: String) -> void:
	variant = kind
	if kind == "runner":
		speed *= 1.7
		max_health *= 0.55
		scale *= 0.8
		modulate = Color(1.0, 1.05, 0.6)
	elif kind == "tank":
		speed *= 0.6
		max_health *= 2.6
		damage_bonus += 5.0
		scale *= 1.35
		modulate = Color(0.45, 0.75, 0.5)
	elif kind == "lobber":
		speed *= 0.85
		modulate = Color(0.85, 0.62, 1.0)
	elif kind == "healer":
		speed *= 0.9
		max_health *= 0.8
		modulate = Color(1.0, 0.72, 0.85)

func _try_lob() -> void:
	var t: Timer = get_node("ability_timer")
	t.wait_time = randf_range(4.0, 8.0)
	t.start()
	if dying or target == null or dash_state != "none" or casting or not entered:
		return
	var dist := global_position.distance_to(target.global_position)
	if dist > 850.0 or dist < 160.0:
		return
	if not GameManager.request_lob_slot():
		return
	lob_pending = true
	casting = true
	var tw := create_tween()
	for i in 2:
		tw.tween_property(sprite, "modulate", Color(0.6, 0.3, 1.0), 0.16)
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.16)
	await get_tree().create_timer(0.65, false).timeout
	casting = false
	if dying or target == null:
		if lob_pending:
			lob_pending = false
			GameManager.release_lob_slot()
		return
	lob_pending = false
	_throw_eggplant()

func _throw_eggplant() -> void:
	var land: Vector2 = target.global_position
	var tgt: Node2D = target
	var dmg := 6.0 + damage_bonus * 0.7
	GameManager.play("swing", -14.0)

	var mark := Node2D.new()
	mark.position = land
	mark.rotation = PI / 4.0
	var mr := ColorRect.new()
	mr.size = Vector2(72, 72)
	mr.position = Vector2(-36, -36)
	mr.color = Color(0.9, 0.15, 0.15, 0.28)
	mark.add_child(mr)
	get_parent().add_child(mark)

	var egg := Sprite2D.new()
	egg.texture = EGGPLANT_TEX
	egg.scale = Vector2(4, 4)
	egg.global_position = global_position
	egg.z_index = 30
	get_parent().add_child(egg)

	var flight := global_position.distance_to(land) / 420.0
	var tws := egg.create_tween()
	tws.tween_property(egg, "scale", Vector2(6, 6), flight * 0.5)
	tws.tween_property(egg, "scale", Vector2(4, 4), flight * 0.5)
	var tw := egg.create_tween()
	tw.set_parallel(true)
	tw.tween_property(egg, "global_position", land, flight)
	tw.tween_property(egg, "rotation", TAU * 2.0, flight)
	tw.chain().tween_callback(func():
		mark.queue_free()
		GameManager.release_lob_slot()
		GameManager.play("splat", -4.0)
		var p := CPUParticles2D.new()
		p.one_shot = true
		p.emitting = true
		p.amount = 12
		p.lifetime = 0.4
		p.explosiveness = 1.0
		p.spread = 180.0
		p.initial_velocity_min = 100.0
		p.initial_velocity_max = 260.0
		p.gravity = Vector2(0, 800)
		p.scale_amount_min = 4.0
		p.scale_amount_max = 7.0
		p.color = Color(0.55, 0.25, 0.75)
		p.position = land
		p.z_index = 40
		egg.get_parent().add_child(p)
		egg.get_tree().create_timer(0.5).timeout.connect(p.queue_free)
		if is_instance_valid(tgt) and tgt.global_position.distance_to(land) < 60.0:
			tgt.take_damage(dmg)
		egg.queue_free()
	)

func _heal_pulse() -> void:
	if dying:
		return
	var healed := false
	for n in get_parent().get_children():
		if n != self and n.has_method("apply_knockback") and not n.dying and n.health < n.max_health and global_position.distance_to(n.global_position) < 260.0:
			n.health = minf(n.health + 12.0 + damage_bonus, n.max_health)
			n.sprite.modulate = Color(0.5, 1.0, 0.5)
			var twn := n.create_tween()
			twn.tween_property(n.sprite, "modulate", Color.WHITE, 0.3)
			healed = true
	if healed:
		var tw := create_tween()
		tw.tween_property(sprite, "scale", Vector2(1.25, 1.25), 0.12)
		tw.tween_property(sprite, "scale", Vector2.ONE, 0.15)

func carry_sign() -> void:
	var holder := Node2D.new()
	holder.z_index = 6
	var stick := ColorRect.new()
	stick.size = Vector2(1.2, 9.0)
	stick.position = Vector2(-0.6, -17.0)
	stick.color = Color(0.45, 0.3, 0.18)
	holder.add_child(stick)

	var txt: String = SIGN_TEXTS.pick_random()
	var board := ColorRect.new()
	var w := maxf(26.0, txt.length() * 6.4)
	board.size = Vector2(w, 11.0)
	board.position = Vector2(-w / 2.0, -25.0)
	board.color = Color(0.92, 0.88, 0.8)
	holder.add_child(board)

	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", FONT_PIXEL)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", Color(0.15, 0.35, 0.15))
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	board.add_child(l)

	add_child(holder)
	var tw := holder.create_tween()
	tw.set_loops()
	tw.tween_property(holder, "rotation", 0.09, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(holder, "rotation", -0.09, 0.7).set_trans(Tween.TRANS_SINE)

func _physics_process(delta: float) -> void:
	angle = velocity.angle()
	angle_deg = rad_to_deg(angle)
	if not follow and not dying and GameManager.enemies_alive <= 3:
		follow = true
		contact_damage = 10 + damage_bonus
	if knockback.length() > 10.0:
		velocity = knockback
		knockback = knockback.move_toward(Vector2.ZERO, 700.0 * delta)
	elif dash_state == "telegraph":
		velocity = Vector2.ZERO
	elif dash_state == "dashing":
		velocity = dash_dir * DASH_SPEED
	elif casting:
		velocity = Vector2.ZERO
	elif not entered or (target and follow):
		if target:
			velocity = (target.global_position - global_position).normalized() * speed
			movement()
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	var b := GameManager.arena_bound
	if entered:
		global_position.x = clamp(global_position.x, -b.x, b.x)
		global_position.y = clamp(global_position.y, -b.y, b.y)
	elif absf(global_position.x) <= b.x and absf(global_position.y) <= b.y:
		entered = true

func apply_knockback(dir: Vector2, force: float) -> void:
	knockback = dir * force

func take_damage(amount: float, from := Vector2.INF) -> void:
	if dying:
		return
	health -= amount
	GameManager.play("hit")
	if from != Vector2.INF:
		apply_knockback((global_position - from).normalized(), 420.0)
	_hit_flash()
	_squash()
	_spawn_damage_number(amount)
	_spawn_splatter()
	_end_dash()
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
	l.add_theme_font_size_override("font_size", 44)
	l.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	l.add_theme_color_override("font_outline_color", Color(0.2, 0.08, 0.04))
	l.add_theme_constant_override("outline_size", 10)
	l.z_index = 50
	l.position = global_position + Vector2(randf_range(-22, 22), -55)
	get_parent().add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 70.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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
	p.initial_velocity_min = 150.0
	p.initial_velocity_max = 320.0
	p.gravity = Vector2(0, 900)
	p.scale_amount_min = 4.0
	p.scale_amount_max = 8.0
	p.color = Color(0.35, 0.8, 0.35)
	p.position = global_position
	p.z_index = 40
	get_parent().add_child(p)
	get_tree().create_timer(0.6).timeout.connect(p.queue_free)

func shout(txt: String) -> void:
	if dying:
		return
	if is_instance_valid(bubble):
		bubble.queue_free()
	bubble = Node2D.new()
	bubble.z_index = 30
	var w := maxf(24.0, txt.length() * 6.4)
	var board := ColorRect.new()
	board.size = Vector2(w, 11.0)
	board.position = Vector2(-w / 2.0, -42.0)
	board.color = Color(0.95, 0.93, 0.88)
	bubble.add_child(board)
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", FONT_PIXEL)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", Color(0.55, 0.12, 0.12))
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	board.add_child(l)
	add_child(bubble)
	bubble.scale = Vector2(0.2, 0.2)
	var tw := bubble.create_tween()
	tw.tween_property(bubble, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.3)
	tw.tween_property(bubble, "modulate:a", 0.0, 0.25)
	tw.tween_callback(bubble.queue_free)

func die() -> void:
	dying = true
	if lob_pending:
		lob_pending = false
		GameManager.release_lob_slot()
	if randf() < 0.35:
		var m := MEAT_SCENE.instantiate()
		m.position = global_position
		get_parent().add_child.call_deferred(m)
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
	_end_dash()

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
	if randf() < 0.25 and GameManager.enemies_alive > 3:
		follow = false
		velocity = Vector2.ZERO
		idle(last_animation_state)
		contact_damage = 15 + damage_bonus
	else:
		follow = true
		contact_damage = 10 + damage_bonus

func apply_slow(factor: float, duration: float) -> void:
	speed = base_speed * factor
	sprite.modulate = Color(0.6, 0.75, 1.0)
	get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(self) and not dying:
			speed = base_speed
			sprite.modulate = Color.WHITE
	)

func idle(anim:String):
	if anim == "":
		return
	if anim == "bottom":
		anim = "back"
	var acc_anim = "idle_" + anim
	sprite.play(acc_anim)

func _try_dash() -> void:
	dash_timer.wait_time = randf_range(4.0, 9.0)
	dash_timer.start()
	if dying or dash_state != "none" or not follow or target == null or not entered:
		return
	if global_position.distance_to(target.global_position) > 700.0:
		return
	if not GameManager.request_dash_slot():
		return
	dash_state = "telegraph"
	dash_dir = (target.global_position - global_position).normalized()
	_show_telegraph()
	await get_tree().create_timer(TELEGRAPH_TIME, false).timeout
	if dying or dash_state != "telegraph":
		return
	dash_state = "dashing"
	GameManager.play("dash", -10.0)
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.3, 0.75), 0.06)
	_ghost_trail()
	await get_tree().create_timer(DASH_TIME, false).timeout
	_end_dash()

func _ghost_trail() -> void:
	while dash_state == "dashing" and not dying:
		var g := Sprite2D.new()
		g.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		g.global_position = sprite.global_position
		g.scale = sprite.global_scale
		g.modulate = Color(0.5, 1.0, 0.4, 0.5)
		g.z_index = z_index - 1
		get_parent().add_child(g)
		var gt := g.create_tween()
		gt.tween_property(g, "modulate:a", 0.0, 0.3)
		gt.tween_callback(g.queue_free)
		await get_tree().create_timer(0.04, false).timeout

func _show_telegraph() -> void:
	telegraph = Node2D.new()
	telegraph.position = global_position
	telegraph.rotation = dash_dir.angle()
	telegraph.z_index = 5
	var r := ColorRect.new()
	var reach := DASH_SPEED * DASH_TIME + 60.0
	r.size = Vector2(reach, 64)
	r.position = Vector2(0, -32)
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
	if not dying:
		var tw := create_tween()
		tw.tween_property(sprite, "scale", Vector2.ONE, 0.1)
