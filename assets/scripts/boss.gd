extends CharacterBody2D

const FONT_PIXEL := preload("res://assets/fonts/pixelart.ttf")
const FONT_TITLE := preload("res://assets/fonts/Singsong.otf")
const TOFU_CHUNK := preload("res://assets/images/weapon/tofu_chunk.png")
const ENEMY_SCENE := preload("res://assets/scenes/enemy.tscn")

const SHOUT_LINES := ["KNEEL BEFORE SOY!", "THE REVOLUTION IS PLANT-BASED", "I AM 100% ORGANIC", "YOU CAN'T GRILL AN IDEA"]

var max_health := 1300.0
var health := max_health
var speed := 70.0
var contact_damage := 22.0
var knockback := Vector2.ZERO
var dying = false
var entered := false
var enraged := false
var busy := false
var charging := false
var charge_dir := Vector2.DOWN
var target: Node2D
var bubble: Node2D
var hp_fill: ColorRect
var hp_layer: CanvasLayer

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	target = get_tree().get_first_node_in_group("player")
	_build_hp_bar()
	var bob := create_tween()
	bob.set_loops()
	bob.tween_property(sprite, "scale", Vector2(7.2, 6.8), 0.5).set_trans(Tween.TRANS_SINE)
	bob.tween_property(sprite, "scale", Vector2(6.8, 7.2), 0.5).set_trans(Tween.TRANS_SINE)
	_attack_loop()

func _physics_process(delta: float) -> void:
	if dying:
		return
	if knockback.length() > 10.0:
		velocity = knockback
		knockback = knockback.move_toward(Vector2.ZERO, 700.0 * delta)
	elif charging:
		velocity = charge_dir * 850.0
	elif busy or target == null:
		velocity = Vector2.ZERO
	else:
		velocity = (target.global_position - global_position).normalized() * speed
	move_and_slide()

	var b := GameManager.arena_bound
	if entered:
		global_position.x = clamp(global_position.x, -b.x, b.x)
		global_position.y = clamp(global_position.y, -b.y, b.y)
	elif absf(global_position.x) <= b.x and absf(global_position.y) <= b.y:
		entered = true
		_stomp()

func _stomp() -> void:
	GameManager.on_hit_landed()
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 16
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 85.0
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 200.0
	p.gravity = Vector2(0, 600)
	p.scale_amount_min = 4.0
	p.scale_amount_max = 8.0
	p.color = Color(0.5, 0.46, 0.4)
	p.position = global_position + Vector2(0, 70)
	p.z_index = 40
	get_parent().add_child(p)
	get_tree().create_timer(0.7).timeout.connect(p.queue_free)
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(8.2, 5.8), 0.08)
	tw.tween_property(sprite, "scale", Vector2(7, 7), 0.18).set_trans(Tween.TRANS_BACK)

func apply_knockback(dir: Vector2, force: float) -> void:
	knockback = dir * force * 0.15

func take_damage(amount: float, _from := Vector2.INF) -> void:
	if dying:
		return
	health = maxf(health - amount, 0.0)
	GameManager.play("hit")
	sprite.modulate = Color(1.5, 0.5, 0.5)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	_damage_number(amount)
	hp_fill.size.x = 694.0 * health / max_health
	if not enraged and health <= max_health * 0.5:
		enraged = true
		speed *= 1.35
		modulate = Color(1.0, 0.72, 0.72)
		shout("NOW I'M ANGRY. AND ORGANIC.")
		GameManager.on_player_hurt()
		var burst := CPUParticles2D.new()
		burst.one_shot = true
		burst.emitting = true
		burst.amount = 24
		burst.lifetime = 0.6
		burst.explosiveness = 1.0
		burst.spread = 180.0
		burst.initial_velocity_min = 180.0
		burst.initial_velocity_max = 420.0
		burst.gravity = Vector2.ZERO
		burst.scale_amount_min = 4.0
		burst.scale_amount_max = 8.0
		burst.color = Color(1.0, 0.5, 0.4)
		burst.position = global_position
		burst.z_index = 40
		get_parent().add_child(burst)
		get_tree().create_timer(0.8).timeout.connect(burst.queue_free)
	if health <= 0.0:
		die()

func _attack_loop() -> void:
	await get_tree().create_timer(2.8, false).timeout
	while not dying:
		await get_tree().create_timer(randf_range(2.0, 3.2) * (0.65 if enraged else 1.0), false).timeout
		if dying or target == null:
			return
		if not entered:
			continue
		busy = true
		var roll := randf()
		if roll < 0.38:
			await _charge()
		elif roll < 0.72:
			await _barrage()
		else:
			await _summon()
		busy = false

func _charge() -> void:
	var dir := (target.global_position - global_position).normalized()
	var tel := Node2D.new()
	tel.position = global_position
	tel.rotation = dir.angle()
	tel.z_index = 5
	var r := ColorRect.new()
	r.size = Vector2(850.0 * 0.5 + 120.0, 160)
	r.position = Vector2(0, -80)
	r.color = Color(0.9, 0.15, 0.15, 0.3)
	tel.add_child(r)
	get_parent().add_child(tel)
	var tw := r.create_tween()
	tw.set_loops()
	tw.tween_property(r, "color:a", 0.08, 0.11)
	tw.tween_property(r, "color:a", 0.4, 0.11)
	await get_tree().create_timer(0.9, false).timeout
	tel.queue_free()
	if dying:
		return
	contact_damage = 32.0
	charging = true
	charge_dir = dir
	GameManager.play("dash", -2.0)
	_ghost_trail()
	await get_tree().create_timer(0.5, false).timeout
	charging = false
	contact_damage = 22.0
	GameManager.on_hit_landed()

func _ghost_trail() -> void:
	while charging and not dying:
		var g := Sprite2D.new()
		g.texture = sprite.texture
		g.global_position = global_position
		g.scale = sprite.global_scale
		g.modulate = Color(1, 1, 1, 0.4)
		g.z_index = z_index - 1
		get_parent().add_child(g)
		var tw := g.create_tween()
		tw.tween_property(g, "modulate:a", 0.0, 0.3)
		tw.tween_callback(g.queue_free)
		await get_tree().create_timer(0.05, false).timeout

func _barrage() -> void:
	shout(SHOUT_LINES.pick_random())
	var tw := create_tween()
	for i in 2:
		tw.tween_property(sprite, "modulate", Color(1.6, 1.6, 1.6), 0.15)
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	await get_tree().create_timer(0.65, false).timeout
	if dying:
		return
	GameManager.play("swing", -6.0)
	var count := 5 if enraged else 4
	var b := GameManager.arena_bound - Vector2(60, 60)
	for i in count:
		var land: Vector2 = target.global_position
		if i > 0:
			land += Vector2(randf_range(-220, 220), randf_range(-220, 220))
		land.x = clampf(land.x, -b.x, b.x)
		land.y = clampf(land.y, -b.y, b.y)
		_lob_chunk(land)
	await get_tree().create_timer(1.0, false).timeout

func _lob_chunk(land: Vector2) -> void:
	var tgt: Node2D = target
	var parent := get_parent()

	var mark := Node2D.new()
	mark.position = land
	mark.rotation = PI / 4.0
	var mr := ColorRect.new()
	mr.size = Vector2(80, 80)
	mr.position = Vector2(-40, -40)
	mr.color = Color(0.9, 0.15, 0.15, 0.26)
	mark.add_child(mr)
	parent.add_child(mark)

	var chunk := Sprite2D.new()
	chunk.texture = TOFU_CHUNK
	chunk.scale = Vector2(4, 4)
	chunk.global_position = global_position
	chunk.z_index = 30
	parent.add_child(chunk)

	var flight := global_position.distance_to(land) / 430.0
	var tws := chunk.create_tween()
	tws.tween_property(chunk, "scale", Vector2(6, 6), flight * 0.5)
	tws.tween_property(chunk, "scale", Vector2(4, 4), flight * 0.5)
	var tw := chunk.create_tween()
	tw.set_parallel(true)
	tw.tween_property(chunk, "global_position", land, flight)
	tw.tween_property(chunk, "rotation", TAU * 1.5, flight)
	tw.chain().tween_callback(func():
		mark.queue_free()
		GameManager.play("splat", -6.0)
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
		p.color = Color(0.93, 0.9, 0.82)
		p.position = land
		p.z_index = 40
		chunk.get_parent().add_child(p)
		chunk.get_tree().create_timer(0.5).timeout.connect(p.queue_free)
		GameManager.on_hit_landed()
		if is_instance_valid(tgt) and tgt.global_position.distance_to(land) < 70.0:
			tgt.take_damage(12.0)
		chunk.queue_free()
	)

func _summon() -> void:
	shout("RALLY, BROTHERS!")
	await get_tree().create_timer(0.5, false).timeout
	if dying:
		return
	var count := 4 if enraged else 3
	var b := GameManager.arena_bound + Vector2(120, 120)
	for i in count:
		var e := ENEMY_SCENE.instantiate()
		e.speed += 40.0
		e.max_health += 120.0
		e.damage_bonus = 8.0
		if randf() < 0.4:
			e.make_variant("runner")
		match randi() % 4:
			0: e.global_position = Vector2(randf_range(-b.x, b.x), -b.y)
			1: e.global_position = Vector2(randf_range(-b.x, b.x), b.y)
			2: e.global_position = Vector2(-b.x, randf_range(-b.y, b.y))
			_: e.global_position = Vector2(b.x, randf_range(-b.y, b.y))
		get_parent().add_child.call_deferred(e)
		GameManager.enemies_alive += 1
	await get_tree().create_timer(0.4, false).timeout

func shout(txt: String) -> void:
	if dying:
		return
	if is_instance_valid(bubble):
		bubble.queue_free()
	bubble = Node2D.new()
	bubble.z_index = 30
	var w := maxf(120.0, txt.length() * 17.0)
	var board := ColorRect.new()
	board.size = Vector2(w, 38.0)
	board.position = Vector2(-w / 2.0, -160.0)
	board.color = Color(0.95, 0.93, 0.88)
	bubble.add_child(board)
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", FONT_PIXEL)
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color(0.55, 0.12, 0.12))
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	board.add_child(l)
	add_child(bubble)
	bubble.scale = Vector2(0.2, 0.2)
	var tw := bubble.create_tween()
	tw.tween_property(bubble, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.5)
	tw.tween_property(bubble, "modulate:a", 0.0, 0.25)
	tw.tween_callback(bubble.queue_free)

func _damage_number(amount: float) -> void:
	var l := Label.new()
	l.text = str(int(amount))
	l.add_theme_font_override("font", FONT_PIXEL)
	l.add_theme_font_size_override("font_size", 44)
	l.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	l.add_theme_color_override("font_outline_color", Color(0.2, 0.08, 0.04))
	l.add_theme_constant_override("outline_size", 10)
	l.z_index = 50
	l.position = global_position + Vector2(randf_range(-40, 40), -100)
	get_parent().add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 70.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.55).set_delay(0.15)
	tw.chain().tween_callback(l.queue_free)

func _build_hp_bar() -> void:
	hp_layer = CanvasLayer.new()
	add_child(hp_layer)

	var name_l := Label.new()
	name_l.text = "THE SUPREME TOFU"
	name_l.add_theme_font_override("font", FONT_TITLE)
	name_l.add_theme_font_size_override("font_size", 46)
	name_l.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	name_l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.offset_top = 16
	hp_layer.add_child(name_l)

	var bg := Panel.new()
	bg.position = Vector2(610, 84)
	bg.size = Vector2(700, 26)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.15)
	sb.border_color = Color(0.73, 0.22, 0.18)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(5)
	bg.add_theme_stylebox_override("panel", sb)
	hp_layer.add_child(bg)

	hp_fill = ColorRect.new()
	hp_fill.position = Vector2(3, 3)
	hp_fill.size = Vector2(694, 20)
	hp_fill.color = Color(0.95, 0.92, 0.85)
	bg.add_child(hp_fill)

func die() -> void:
	dying = true
	set_physics_process(false)
	collision_layer = 0
	contact_damage = 0.0
	if is_instance_valid(bubble):
		bubble.queue_free()
	hp_layer.queue_free()
	Engine.time_scale = 0.15
	var slow := get_tree().create_timer(0.4, true, false, true)
	slow.timeout.connect(func(): Engine.time_scale = 1.0)
	GameManager.play("enemy_die", 4.0)
	GameManager.play("splat", 2.0)
	for c in [Color(0.93, 0.9, 0.82), Color(0.35, 0.8, 0.35)]:
		var p := CPUParticles2D.new()
		p.one_shot = true
		p.emitting = true
		p.amount = 26
		p.lifetime = 0.8
		p.explosiveness = 1.0
		p.spread = 180.0
		p.initial_velocity_min = 200.0
		p.initial_velocity_max = 480.0
		p.gravity = Vector2(0, 500)
		p.scale_amount_min = 5.0
		p.scale_amount_max = 10.0
		p.color = c
		p.position = global_position
		p.z_index = 40
		get_parent().add_child(p)
		get_tree().create_timer(1.2).timeout.connect(p.queue_free)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(sprite, "scale", Vector2(9, 9), 0.5)
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(func():
		GameManager.on_enemy_died()
		queue_free()
	)
