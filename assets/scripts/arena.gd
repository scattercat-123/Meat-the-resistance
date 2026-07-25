extends Node2D

const ENEMY_SCENE := preload("res://assets/scenes/enemy.tscn")
const FONT_PIXEL := preload("res://assets/fonts/pixelart.ttf")
const FONT_TITLE := preload("res://assets/fonts/Singsong.otf")

const MEAT_RED := Color(0.73, 0.22, 0.18)
const CREAM := Color(0.91, 0.78, 0.66)
const PANEL_BG := Color(0.07, 0.07, 0.09, 0.96)

const UPGRADES := [
	{"name": "Bigger steak", "desc": "+25% damage"},
	{"name": "Double swing", "desc": "-30% attack cooldown"},
	{"name": "Thick hide", "desc": "+25 max health, full heal"},
	{"name": "Fast legs", "desc": "+40 speed"},
	{"name": "Flaming steak", "desc": "+35% damage, well done"},
	{"name": "Long reach", "desc": "bigger hitbox, faster swing"},
	{"name": "Frozen steak", "desc": "freezing cuts slow vegans down"},
	{"name": "Bone-in steak", "desc": "+50% damage, more reach, slower"},
	{"name": "Protein shake", "desc": "+15% damage, +35 speed"},
]

const TOMATO_PICKUP_SCENE := preload("res://assets/scenes/tomato_pickup.tscn")
const TOMATO_WAVE := 6
const FINAL_WAVE := 10

const LINES_LOSE := [
	"COMPOSTED.",
	"The vegans turned you into fertilizer.",
	"Your steak now belongs to a salad bar.",
	"Beaten by people who don't even lift.",
	"Death by broccoli. Embarrassing.",
	"They are reading you tofu recipes. All of them.",
]
const LINES_WIN := [
	"The resistance has been MEATED.",
	"Vegans: 0 - Steak: everything.",
	"You grilled your way to freedom.",
	"Word is their Supreme Tofu leader escaped...",
]

var wave := 0
var enemies_to_spawn := 0
var wave_size := 0
var wave_kills := 0
var tomatoes_dropped := 0
var signs_this_wave := 0
var spawn_timer: Timer
var hud: CanvasLayer
var wave_label: Label
var score_label: Label
var hp_label: Label
var hp_fill: ColorRect
var dash_fill: ColorRect
var dash_was_ready := true
var tomato_label: Label
var player: CharacterBody2D

func _ready() -> void:
	Music.resume()
	GameManager.enemies_alive = 0
	GameManager.score = 0
	GameManager.dash_slots = 0
	GameManager.max_dash_slots = 0
	GameManager.lob_slots = 0
	GameManager.max_lob_slots = 0
	player = $Player

	spawn_timer = Timer.new()
	spawn_timer.wait_time = 0.6
	spawn_timer.timeout.connect(_spawn_one)
	add_child(spawn_timer)

	_build_hud()
	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)
	GameManager.enemy_died.connect(_check_wave_clear)
	GameManager.hit_landed.connect(_shake_camera.bind(14.0))
	GameManager.player_hurt.connect(_on_player_hurt)

	_start_wave()

func _shake_camera(base: float) -> void:
	var cam := $Camera2D
	var tw := create_tween()
	for i in 4:
		var strength := base * (1.0 - i / 4.0)
		tw.tween_property(cam, "offset", Vector2(randf_range(-strength, strength), randf_range(-strength, strength)), 0.03)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.04)

func _on_player_hurt() -> void:
	_shake_camera(24.0)
	var flash := ColorRect.new()
	flash.color = Color(0.75, 0.08, 0.08, 0.3)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(flash)
	var tw := flash.create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.3)
	tw.tween_callback(flash.queue_free)

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)

	wave_label = _make_label("", FONT_PIXEL, 44, Color.WHITE)
	wave_label.position = Vector2(32, 24)
	hud.add_child(wave_label)

	score_label = _make_label("Grilled: 0", FONT_PIXEL, 44, CREAM)
	score_label.position = Vector2(1520, 24)
	hud.add_child(score_label)

	var hp_title := _make_label("HP", FONT_PIXEL, 28, Color(0.65, 0.65, 0.7))
	hp_title.position = Vector2(32, 86)
	hud.add_child(hp_title)

	hp_fill = _make_bar(Vector2(130, 88), Vector2(300, 30))

	hp_label = _make_label("", FONT_PIXEL, 24, CREAM)
	hp_label.position = Vector2(444, 90)
	hud.add_child(hp_label)

	var dash_label := _make_label("Dash", FONT_PIXEL, 28, Color(0.65, 0.65, 0.7))
	dash_label.position = Vector2(32, 136)
	hud.add_child(dash_label)

	dash_fill = _make_bar(Vector2(130, 142), Vector2(200, 22))

	var tomato_icon := Sprite2D.new()
	tomato_icon.texture = preload("res://assets/images/weapon/tomato.png")
	tomato_icon.scale = Vector2(3, 3)
	tomato_icon.position = Vector2(52, 210)
	hud.add_child(tomato_icon)

	tomato_label = _make_label("x0", FONT_PIXEL, 30, CREAM)
	tomato_label.position = Vector2(84, 194)
	hud.add_child(tomato_label)

func _make_bar(pos: Vector2, size: Vector2) -> ColorRect:
	var bg := Panel.new()
	bg.position = pos
	bg.size = size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.15)
	sb.border_color = Color(0.35, 0.35, 0.4)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(5)
	bg.add_theme_stylebox_override("panel", sb)
	hud.add_child(bg)

	var fill := ColorRect.new()
	fill.position = Vector2(3, 3)
	fill.size = size - Vector2(6, 6)
	fill.color = CREAM
	fill.pivot_offset = (size - Vector2(6, 6)) / 2.0
	bg.add_child(fill)
	return fill

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	tomato_label.text = "x%d" % player.tomatoes
	var p: float = player.dash_progress()
	dash_fill.size.x = (dash_fill.get_parent().size.x - 6.0) * p
	var dash_ready := p >= 1.0
	dash_fill.color = CREAM if dash_ready else MEAT_RED
	if dash_ready and not dash_was_ready:
		var tw := dash_fill.create_tween()
		tw.tween_property(dash_fill, "scale", Vector2(1.15, 1.5), 0.08)
		tw.tween_property(dash_fill, "scale", Vector2.ONE, 0.1)
	dash_was_ready = dash_ready

func _make_label(txt: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _make_panel(size: Vector2) -> Panel:
	var panel := Panel.new()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.size = size
	panel.position = (Vector2(1920, 1080) - size) / 2.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = MEAT_RED
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	hud.add_child(panel)
	panel.pivot_offset = size / 2.0
	panel.scale = Vector2(0.8, 0.8)
	panel.modulate.a = 0.0
	var tw := panel.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)
	return panel

func _make_button(txt: String, size: Vector2) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = size
	btn.add_theme_font_override("font", FONT_PIXEL)
	btn.add_theme_font_size_override("font_size", 40)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", CREAM)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.13, 0.13, 0.16)
	normal.border_color = Color(0.35, 0.35, 0.4)
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = MEAT_RED
	hover.border_color = CREAM
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	return btn

func _start_wave() -> void:
	wave += 1
	wave_label.text = "Wave %d" % wave
	if wave > 1:
		player.heal(10.0)
	enemies_to_spawn = 3 + wave
	GameManager.max_dash_slots = 0 if wave < 3 else mini(1 + int((wave - 3) / 3.0), 3)
	GameManager.dash_slots = GameManager.max_dash_slots
	GameManager.max_lob_slots = 0 if wave < 3 else mini(1 + int((wave - 3) / 3.0), 3)
	GameManager.lob_slots = GameManager.max_lob_slots
	wave_size = enemies_to_spawn
	wave_kills = 0
	tomatoes_dropped = 0
	signs_this_wave = 0
	spawn_timer.start()

func _spawn_one() -> void:
	if enemies_to_spawn <= 0:
		spawn_timer.stop()
		return
	enemies_to_spawn -= 1

	var enemy := ENEMY_SCENE.instantiate()
	enemy.speed += minf(wave * 4.0, 100.0)
	enemy.max_health += wave * 7.0 + wave * wave
	enemy.damage_bonus = wave
	var roll := randf()
	var lob_chance := minf(0.10 + wave * 0.012, 0.20)
	if wave >= 7 and roll < 0.15:
		enemy.make_variant("tank")
	elif wave >= 5 and roll < 0.27:
		enemy.make_variant("healer")
	elif wave >= 3 and roll < 0.27 + lob_chance:
		enemy.make_variant("lobber")
	elif wave >= 4 and roll < 0.52 + lob_chance:
		enemy.make_variant("runner")
	var first_of_wave := enemies_to_spawn == wave_size - 1
	if first_of_wave or (signs_this_wave < 2 and randf() < 0.12):
		enemy.carry_sign()
		signs_this_wave += 1
	enemy.global_position = _edge_spawn_point()
	add_child(enemy)
	GameManager.enemies_alive += 1

func _edge_spawn_point() -> Vector2:
	var b := GameManager.arena_bound + Vector2(120, 120)
	match randi() % 4:
		0: return Vector2(randf_range(-b.x, b.x), -b.y)
		1: return Vector2(randf_range(-b.x, b.x), b.y)
		2: return Vector2(-b.x, randf_range(-b.y, b.y))
		_: return Vector2(b.x, randf_range(-b.y, b.y))

func _check_wave_clear() -> void:
	score_label.text = "Grilled: %d" % GameManager.score
	wave_kills += 1
	if wave >= TOMATO_WAVE:
		while tomatoes_dropped < 3 and wave_kills >= ceili(wave_size * 0.3 * (tomatoes_dropped + 1)):
			_drop_tomato()
	if GameManager.enemies_alive <= 0 and enemies_to_spawn <= 0:
		if wave >= FINAL_WAVE:
			_end_screen(true)
		else:
			_offer_upgrade()

func _drop_tomato() -> void:
	tomatoes_dropped += 1
	var pickup := TOMATO_PICKUP_SCENE.instantiate()
	var b := GameManager.arena_bound - Vector2(140, 140)
	pickup.position = Vector2(randf_range(-b.x, b.x), randf_range(-b.y, b.y))
	add_child.call_deferred(pickup)

func _on_health_changed(hp: float, max_hp: float) -> void:
	hp_label.text = "%d/%d" % [int(hp), int(max_hp)]
	var ratio := hp / max_hp
	var full_w: float = hp_fill.get_parent().size.x - 6.0
	var tw := hp_fill.create_tween()
	tw.tween_property(hp_fill, "size:x", full_w * ratio, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if ratio > 0.5:
		hp_fill.color = CREAM
	elif ratio > 0.25:
		hp_fill.color = Color(0.9, 0.6, 0.2)
	else:
		hp_fill.color = MEAT_RED

func _on_player_died() -> void:
	_end_screen(false)

func _end_screen(win: bool) -> void:
	spawn_timer.stop()
	GameManager.play("upgrade" if win else "game_over")
	get_tree().paused = true

	var panel := _make_panel(Vector2(920, 600))

	var title := _make_label("VICTORY" if win else "GAME OVER", FONT_TITLE, 110, CREAM if win else MEAT_RED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 25
	panel.add_child(title)

	var quip_text: String = LINES_WIN.pick_random() if win else LINES_LOSE.pick_random()
	var quip := _make_label(quip_text, FONT_PIXEL, 32, Color(0.78, 0.78, 0.84))
	quip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	quip.offset_top = 205
	panel.add_child(quip)

	var survived := wave if win else wave - 1
	var stats := _make_label("Waves: %d      Grilled: %d" % [survived, GameManager.score], FONT_PIXEL, 42, CREAM)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.set_anchors_preset(Control.PRESET_TOP_WIDE)
	stats.offset_top = 275
	panel.add_child(stats)

	var steak := Sprite2D.new()
	steak.texture = preload("res://assets/images/weapon/steak.png")
	steak.scale = Vector2(4, 4)
	steak.position = Vector2(panel.size.x - 110, -220)
	steak.rotation = 0.35
	panel.add_child(steak)
	var st := steak.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	st.tween_property(steak, "position:y", 95.0, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	st.tween_callback(func():
		var wob := steak.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		wob.set_loops()
		wob.tween_property(steak, "rotation", 0.5, 0.9).set_trans(Tween.TRANS_SINE)
		wob.tween_property(steak, "rotation", 0.2, 0.9).set_trans(Tween.TRANS_SINE)
	)

	var restart := _make_button("Play again", Vector2(400, 85))
	restart.position = Vector2((panel.size.x - 400) / 2.0, 370)
	restart.pressed.connect(func(): Transition.swipe_to(""))
	panel.add_child(restart)

	var menu_btn := _make_button("Back to menu", Vector2(400, 75))
	menu_btn.position = Vector2((panel.size.x - 400) / 2.0, 480)
	menu_btn.pressed.connect(func(): Transition.swipe_to("res://assets/scenes/intro.tscn"))
	panel.add_child(menu_btn)

func _offer_upgrade() -> void:
	await get_tree().create_timer(1.5).timeout
	get_tree().paused = true
	var choices := UPGRADES.filter(func(u): return not (
		(u.name == "Frozen steak" and player.weapon == "frozen")
		or (u.name == "Bone-in steak" and player.weapon == "bone")
	))
	choices.shuffle()
	choices = choices.slice(0, 3)

	var panel := _make_panel(Vector2(1000, 620))

	var title := _make_label("Choose an upgrade", FONT_TITLE, 80, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 35
	panel.add_child(title)

	for i in choices.size():
		var choice = choices[i]
		var btn := _make_button("%s\n%s" % [choice.name, choice.desc], Vector2(840, 110))
		btn.position = Vector2((panel.size.x - 840) / 2.0, 185 + i * 135)
		btn.pressed.connect(_pick_upgrade.bind(choice.name, panel))
		panel.add_child(btn)

func _pick_upgrade(upgrade_name: String, panel: Panel) -> void:
	GameManager.play("upgrade")
	player.apply_upgrade(upgrade_name)
	panel.queue_free()
	get_tree().paused = false
	_start_wave()
