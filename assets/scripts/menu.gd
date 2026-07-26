extends Node2D
@onready var mouse_pos: Marker2D = $mouse_pos
@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"
@onready var cutscene: VideoStreamPlayer = $"../cutscene"
@onready var skip_label: Label = $"../skip_label"

const FONT_PIXEL := preload("res://assets/fonts/meatfont.png")
const FONT_TITLE := preload("res://assets/fonts/Singsong.otf")
const CREAM := Color(0.91, 0.78, 0.66)
const CREDITS := [
	"Sajid Hossain - dev / designer",
	"Atharv Sharma - dev / designer",
	"Eddie Fangzhou - animator",
]

var play_button_hover = false
var credits_hover = false
var settings_hover = false
var skippable = false
var panel_open = false
var ui_layer: CanvasLayer


func _ready() -> void:
	get_tree().paused = false
	Input.warp_mouse(mouse_pos.position)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 20
	get_parent().add_child.call_deferred(ui_layer)

func _process(_delta: float) -> void:
	if skippable == true and Input.is_action_just_pressed("attack"):
		skippable = false
		Transition.swipe_to("res://assets/scenes/arena.tscn")
	
	if credits_hover and not panel_open and Input.is_action_just_pressed("attack"):
		_open_credits()

	if settings_hover and not panel_open and Input.is_action_just_pressed("attack"):
		_open_settings()

	if play_button_hover and not panel_open and Input.is_action_just_pressed("attack"):
		Music.hold()
		animation_player.play("play")
		await animation_player.animation_finished
		cutscene.visible = true
		cutscene.play()
		await get_tree().create_timer(1.0).timeout
		skip_label.visible = true
		animation_player.play("blink")
		skippable = true
		await cutscene.finished
		skip_label.visible = false
		Transition.swipe_to("res://assets/scenes/arena.tscn")
		

func _make_panel(size: Vector2) -> Panel:
	panel_open = true
	var panel := Panel.new()
	panel.size = size
	panel.position = (Vector2(1920, 1080) - size) / 2.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.09, 0.97)
	sb.border_color = Color(0.73, 0.22, 0.18)
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	ui_layer.add_child(panel)
	panel.pivot_offset = size / 2.0
	panel.scale = Vector2(0.8, 0.8)
	var tw := panel.create_tween()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return panel

func _make_label(txt: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _make_button(txt: String, size: Vector2) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = size
	btn.add_theme_font_override("font", FONT_PIXEL)
	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", CREAM)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.13, 0.13, 0.16)
	normal.border_color = Color(0.35, 0.35, 0.4)
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.73, 0.22, 0.18)
	hover.border_color = CREAM
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	return btn

func _add_close(panel: Panel) -> void:
	var btn := _make_button("Close", Vector2(300, 70))
	btn.position = Vector2((panel.size.x - 300) / 2.0, panel.size.y - 95)
	btn.pressed.connect(func():
		panel.queue_free()
		panel_open = false
	)
	panel.add_child(btn)

func _open_credits() -> void:
	var panel := _make_panel(Vector2(820, 560))
	var title := _make_label("Credits", FONT_TITLE, 90, CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 20
	panel.add_child(title)
	for i in CREDITS.size():
		var c := _make_label(CREDITS[i], FONT_PIXEL, 28, Color(0.85, 0.85, 0.9))
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.set_anchors_preset(Control.PRESET_TOP_WIDE)
		c.offset_top = 200 + i * 62
		panel.add_child(c)
	_add_close(panel)

func _open_settings() -> void:
	var panel := _make_panel(Vector2(820, 620))
	var title := _make_label("Settings", FONT_TITLE, 90, CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 20
	panel.add_child(title)

	var ml := _make_label("Music volume", FONT_PIXEL, 28, Color(0.85, 0.85, 0.9))
	ml.position = Vector2(120, 200)
	panel.add_child(ml)
	var ms := HSlider.new()
	ms.min_value = 0.0
	ms.max_value = 1.0
	ms.step = 0.05
	ms.value = Music.volume_linear
	ms.custom_minimum_size = Vector2(560, 30)
	ms.position = Vector2(120, 245)
	ms.value_changed.connect(func(v): Music.set_volume(v))
	panel.add_child(ms)

	var sl := _make_label("Sound effects", FONT_PIXEL, 28, Color(0.85, 0.85, 0.9))
	sl.position = Vector2(120, 310)
	panel.add_child(sl)
	var ss := HSlider.new()
	ss.min_value = 0.0
	ss.max_value = 1.0
	ss.step = 0.05
	ss.value = GameManager.sfx_volume
	ss.custom_minimum_size = Vector2(560, 30)
	ss.position = Vector2(120, 355)
	ss.value_changed.connect(func(v):
		GameManager.sfx_volume = v
		GameManager.play("hit", -6.0)
	)
	panel.add_child(ss)

	var fs := _make_button("Toggle fullscreen", Vector2(420, 65))
	fs.position = Vector2((panel.size.x - 420) / 2.0, 425)
	fs.pressed.connect(func():
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	)
	panel.add_child(fs)

	_add_close(panel)

func _on_play_area_mouse_entered() -> void:
	play_button_hover = true

func _on_play_area_mouse_exited() -> void:
	play_button_hover = false

func _on_credits_area_mouse_entered() -> void:
	credits_hover = true

func _on_credits_area_mouse_exited() -> void:
	credits_hover = false

func _on_settings_area_mouse_entered() -> void:
	settings_hover = true

func _on_settings_area_mouse_exited() -> void:
	settings_hover = false
