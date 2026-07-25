extends Node2D
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var label: Label = $Label
@onready var paused_sprite: Sprite2D = $paused
@onready var playing_sprite: Sprite2D = $playing

var music_names = ["The Mountain Game", "Hautsync Combat Fast paced", "Hautsync Heavy Doom", "Mondamusic Retro Arcade", "Phatphrog Studio Samurai Spirit"]
var pause_button_area_hover = false
var music_rand_order_num = 0
var current_music_roll_no = 0
var music_order : Array
var paused = false
var last_music_time : float

func _ready() -> void:
	randomize()
	music_order = [1, 2, 3, 4, 5]
	music_order.shuffle()
	
func _process(delta: float) -> void:
	var current_player = get_parent().get_node("Music/" + str(music_order[current_music_roll_no]))
	if not current_player.playing and not paused:
		if current_music_roll_no < music_order.size() - 1:
			current_music_roll_no += 1
		else:
			current_music_roll_no = 0

		current_player = get_parent().get_node("Music/" + str(music_order[current_music_roll_no]))
		current_player.play()
	
	var percentage = (current_player.get_playback_position() / current_player.stream.get_length()) * 100
	progress_bar.value = percentage
	label.text = str(music_names[music_order[current_music_roll_no] - 1])
	
	if pause_button_area_hover and Input.is_action_just_pressed("attack"):
		if paused:
			current_player.play(last_music_time)
		last_music_time = current_player.get_playback_position()
		paused = not paused
		paused_sprite.visible = paused
		playing_sprite.visible = not paused
		current_player.playing = not paused

func _on_pause_area_mouse_entered() -> void:
	pause_button_area_hover = true

func _on_pause_area_mouse_exited() -> void:
	pause_button_area_hover = false
