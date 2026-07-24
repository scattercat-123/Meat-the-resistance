extends Node2D

const ENEMY_SCENE := preload("res://assets/scenes/enemy.tscn")

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

	wave_label = Label.new()
	wave_label.position = Vector2(20, 16)
	hud.add_child(wave_label)

	hp_label = Label.new()
	hp_label.position = Vector2(20, 44)
	hud.add_child(hp_label)

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

	var panel := Panel.new()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.position = Vector2(640, 400)
	panel.custom_minimum_size = Vector2(260, 110)
	hud.add_child(panel)

	var label := Label.new()
	label.text = "Game over — wave %d" % wave
	label.position = Vector2(16, 14)
	panel.add_child(label)

	var restart := Button.new()
	restart.text = "Restart"
	restart.position = Vector2(16, 50)
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

	var panel := Panel.new()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.position = Vector2(560, 300)
	panel.custom_minimum_size = Vector2(360, 170)
	hud.add_child(panel)

	var title := Label.new()
	title.text = "Choose an upgrade"
	title.position = Vector2(16, 12)
	panel.add_child(title)

	for i in choices.size():
		var choice = choices[i]
		var btn := Button.new()
		btn.text = "%s — %s" % [choice.name, choice.desc]
		btn.position = Vector2(16, 44 + i * 36)
		btn.custom_minimum_size = Vector2(320, 30)
		btn.pressed.connect(_pick_upgrade.bind(choice.name, panel))
		panel.add_child(btn)

func _pick_upgrade(upgrade_name: String, panel: Panel) -> void:
	player.apply_upgrade(upgrade_name)
	panel.queue_free()
	get_tree().paused = false
	_start_wave()
