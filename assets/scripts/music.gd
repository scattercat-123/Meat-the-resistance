extends Node

const FONT_PIXEL := preload("res://assets/fonts/pixelart.ttf")
const ICON_PLAY := preload("res://assets/images/noun-play-2009520.png")
const ICON_PAUSE := preload("res://assets/images/noun-pause-2009522.png")
const ICON_NEXT := preload("res://assets/images/noun-fast-forward-2009519.png")
const ICON_PREV := preload("res://assets/images/noun-fast-backward-2009518.png")
const ICON_NOTE := preload("res://assets/images/noun-music-note-6193360.png")
const CREAM := Color(0.91, 0.78, 0.66)

const TRACKS := [
	{"name": "The Mountain Game", "stream": preload("res://assets/audio/the_mountain-game-game-music-508018.mp3")},
	{"name": "Combat Fast Paced", "stream": preload("res://assets/audio/hauntsync-combat-fast-paced-8-bit-chiptune-for-action-games-374457.mp3")},
	{"name": "Heavy Doom", "stream": preload("res://assets/audio/hauntsync-heavy-doom-metal-instrumental-for-intense-combat-331738.mp3")},
	{"name": "Retro Arcade", "stream": preload("res://assets/audio/mondamusic-retro-arcade-game-music-512837.mp3")},
	{"name": "Samurai Spirit", "stream": preload("res://assets/audio/phatphrogstudio-samurai-spirit-cursed-oni-edm-royalty-free-music-502868.mp3")},
]

var order := []
var idx := 0
var paused := false
var held := false
var ui_layer: CanvasLayer
var player: AudioStreamPlayer
var name_label: Label
var bar_fill: ColorRect
var bar_bg: ColorRect
var pause_btn: TextureButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	order = range(TRACKS.size())
	order.shuffle()

	player = AudioStreamPlayer.new()
	player.volume_db = -10.0
	player.finished.connect(_next)
	add_child(player)

	_build_ui()
	_play_current()

func hold() -> void:
	held = true
	player.stream_paused = true
	ui_layer.visible = false

func resume() -> void:
	if not held:
		return
	held = false
	ui_layer.visible = true
	if not paused:
		player.stream_paused = false

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 15
	add_child(layer)
	ui_layer = layer

	var panel := Panel.new()
	panel.position = Vector2(1544, 1014)
	panel.size = Vector2(360, 52)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.09, 0.85)
	sb.border_color = Color(0.35, 0.35, 0.4)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(panel)

	var note := TextureRect.new()
	note.texture = ICON_NOTE
	note.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	note.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	note.position = Vector2(10, 10)
	note.size = Vector2(24, 24)
	note.modulate = CREAM
	panel.add_child(note)

	name_label = Label.new()
	name_label.add_theme_font_override("font", FONT_PIXEL)
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", CREAM)
	name_label.position = Vector2(42, 10)
	name_label.size = Vector2(205, 26)
	name_label.clip_text = true
	panel.add_child(name_label)

	var btns := [
		[ICON_PREV, _prev, Vector2(252, 8)],
		[ICON_PAUSE, _toggle_pause, Vector2(286, 8)],
		[ICON_NEXT, _next, Vector2(320, 8)],
	]
	for b in btns:
		var btn := TextureButton.new()
		btn.texture_normal = b[0]
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.position = b[2]
		btn.size = Vector2(28, 28)
		btn.modulate = CREAM
		btn.pressed.connect(b[1])
		btn.mouse_entered.connect(func(): btn.modulate = Color.WHITE)
		btn.mouse_exited.connect(func(): btn.modulate = CREAM)
		panel.add_child(btn)
		if b[0] == ICON_PAUSE:
			pause_btn = btn

	bar_bg = ColorRect.new()
	bar_bg.position = Vector2(10, 44)
	bar_bg.size = Vector2(340, 4)
	bar_bg.color = Color(0.25, 0.25, 0.3)
	panel.add_child(bar_bg)

	bar_fill = ColorRect.new()
	bar_fill.position = Vector2.ZERO
	bar_fill.size = Vector2(0, 4)
	bar_fill.color = Color(0.73, 0.22, 0.18)
	bar_bg.add_child(bar_fill)

func _process(_delta: float) -> void:
	if player.stream == null:
		return
	var length: float = player.stream.get_length()
	if length > 0.0:
		bar_fill.size.x = bar_bg.size.x * clampf(player.get_playback_position() / length, 0.0, 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_M: _toggle_pause()
			KEY_N: _next()

func force_track(track_name: String) -> void:
	for t in TRACKS:
		if t.name == track_name:
			player.stream = t.stream
			player.play()
			paused = false
			player.stream_paused = false
			pause_btn.texture_normal = ICON_PAUSE
			name_label.text = t.name
			return

func _play_current() -> void:
	player.stream = TRACKS[order[idx]].stream
	player.play()
	paused = false
	pause_btn.texture_normal = ICON_PAUSE
	name_label.text = TRACKS[order[idx]].name

func _next() -> void:
	idx = (idx + 1) % order.size()
	_play_current()

func _prev() -> void:
	idx = (idx - 1 + order.size()) % order.size()
	_play_current()

func _toggle_pause() -> void:
	paused = not paused
	player.stream_paused = paused
	pause_btn.texture_normal = ICON_PLAY if paused else ICON_PAUSE
