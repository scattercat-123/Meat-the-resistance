extends Node2D

const ENEMY_SCENE := preload("res://assets/scenes/enemy.tscn")
const FONT_PIXEL := preload("res://assets/fonts/pixelart.ttf")
const FONT_TITLE := preload("res://assets/fonts/Singsong.otf")

const MEAT_RED := Color(0.73, 0.22, 0.18)
const CREAM := Color(0.91, 0.78, 0.66)
const PANEL_BG := Color(0.07, 0.07, 0.09, 0.96)

const UPGRADES := [
	{"name": "Bigger steak", "desc": "+10 damage"},
	{"name": "Double swing", "desc": "-30% attack cooldown"},
	{"name": "Thick hide", "desc": "+20 max health, full heal"},
	{"name": "Fast legs", "desc": "+40 speed"},
	{"name": "Flaming steak", "desc": "+15 damage, longer swing"},
	{"name": "Long reach", "desc": "bigger hitbox, faster swing"},
]

var wave := 0
var enemies_to_spawn := 0
var spawn_timer: Timer
var hud: CanvasLayer
var wave_label: Label
var hp_label: Label
var player: CharacterBody2D

func _ready() -> void:
	GameManager.enemies_alive = 0
	GameManager.score = 0
	player = $Player

	spawn_timer = Timer.new()
	spawn_timer.wait_time = 0.6
	spawn_timer.timeout.connect(_spawn_one)
	add_child(spawn_timer)

	_build_hud()
	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)
	GameManager.enemy_died.connect(_check_wave_clear)

	_start_wave()

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)

	wave_label = _make_label("", FONT_PIXEL, 44, Color.WHITE)
	wave_label.position = Vector2(32, 24)
	hud.add_child(wave_label)

	hp_label = _make_label("", FONT_PIXEL, 44, CREAM)
	hp_label.position = Vector2(32, 78)
	hud.add_child(hp_label)

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
	enemies_to_spawn = 3 + wave * 2
	spawn_timer.start()

func _spawn_one() -> void:
	if enemies_to_spawn <= 0:
		spawn_timer.stop()
		return
	enemies_to_spawn -= 1

	var enemy := ENEMY_SCENE.instantiate()
	enemy.speed += wave * 5.0
	enemy.max_health += wave * 5.0
	enemy.global_position = _edge_spawn_point()
	add_child(enemy)
	GameManager.enemies_alive += 1

func _edge_spawn_point() -> Vector2:
	var b := GameManager.arena_bound
	match randi() % 4:
		0: return Vector2(randf_range(-b.x, b.x), -b.y)
		1: return Vector2(randf_range(-b.x, b.x), b.y)
		2: return Vector2(-b.x, randf_range(-b.y, b.y))
		_: return Vector2(b.x, randf_range(-b.y, b.y))

func _check_wave_clear() -> void:
	if GameManager.enemies_alive <= 0 and enemies_to_spawn <= 0:
		_offer_upgrade()

func _on_health_changed(hp: float, max_hp: float) -> void:
	hp_label.text = "HP %d/%d" % [int(hp), int(max_hp)]

func _on_player_died() -> void:
	spawn_timer.stop()
	get_tree().paused = true

	var panel := _make_panel(Vector2(820, 460))

	var title := _make_label("Game Over", FONT_TITLE, 110, MEAT_RED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 30
	panel.add_child(title)

	var sub := _make_label("You survived %d waves" % (wave - 1), FONT_PIXEL, 42, CREAM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 200
	panel.add_child(sub)

	var restart := _make_button("Play again", Vector2(400, 90))
	restart.position = Vector2((panel.size.x - 400) / 2.0, 310)
	restart.pressed.connect(func():
		get_tree().paused = false
		get_tree().reload_current_scene()
	)
	panel.add_child(restart)

func _offer_upgrade() -> void:
	get_tree().paused = true
	var choices := UPGRADES.duplicate()
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
	player.apply_upgrade(upgrade_name)
	panel.queue_free()
	get_tree().paused = false
	_start_wave()
