extends CharacterBody2D

signal health_changed(hp: float, max_hp: float)
signal died

const CHAR_DIR := "res://assets/images/character/"
const WEAPON_DIR := "res://assets/images/weapon/"
const DIRECTIONS := ["Down", "Up", "Left", "Right", "DownLeft", "DownRight", "UpLeft", "UpRight"]
const SLASH_DIRS := ["DownRight", "DownLeft", "UpRight", "UpLeft"]
const SLASH_FPS := 14.0

const WEAPONS := {
	"raw": {
		"hand": preload("res://assets/images/weapon/steak_small.png"),
		"sheet": "Steak_", "dmg": 1.0, "cd": 1.0, "reach": 1.0, "slow": 0.0,
	},
	"frozen": {
		"hand": preload("res://assets/images/weapon/steak_frozen_small.png"),
		"sheet": "Steak_Frozen_", "dmg": 0.8, "cd": 1.15, "reach": 1.0, "slow": 2.0,
	},
	"bone": {
		"hand": preload("res://assets/images/weapon/steak_bone_small.png"),
		"sheet": "Steak_Bone_", "dmg": 1.5, "cd": 1.35, "reach": 1.3, "slow": 0.0,
	},
}

@export var speed := 220.0
@export var attack_damage := 15.0
@export var attack_cooldown := 0.25
@export var max_health := 100.0
@export var dash_speed := 780.0
@export var dash_time := 0.18
@export var dash_cooldown := 0.8

@onready var anim: AnimatedSprite2D = $Anim
@onready var weapon_anim: AnimatedSprite2D = $WeaponAnim
@onready var steak: Sprite2D = $Steak
@onready var aim: Node2D = $Aim
@onready var hitbox: Area2D = $Aim/WeaponHitbox
@onready var hurtbox: Area2D = $Hurtbox

const TOMATO_SCENE := preload("res://assets/scenes/tomato.tscn")

var health := 0.0
var tomato_damage := 0.0
var tomato_timer: Timer
var can_attack := true
var attacking := false
var weapon := "raw"
var reach_bonus := 1.0
var dashing := false
var can_dash := true
var dash_dir := Vector2.DOWN
var dash_ready_at := 0
var facing := Vector2.DOWN
var damage_cooldown: Timer

func _ready() -> void:
	add_to_group("player")
	health = max_health
	anim.sprite_frames = _build_char_frames()
	anim.play("Down")
	weapon_anim.sprite_frames = _build_weapon_frames()
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	health_changed.emit(health, max_health)

	damage_cooldown = Timer.new()
	damage_cooldown.wait_time = 0.6
	damage_cooldown.one_shot = true
	add_child(damage_cooldown)

	tomato_timer = Timer.new()
	tomato_timer.wait_time = 2.2
	tomato_timer.timeout.connect(_throw_tomato)
	add_child(tomato_timer)

func _build_char_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	for dir_name in DIRECTIONS:
		_add_sheet(sf, dir_name, CHAR_DIR + "Character_" + dir_name + ".png", 4, 32, 8.0)
	for dir_name in SLASH_DIRS:
		_add_sheet(sf, "Slash" + dir_name, CHAR_DIR + "Character_Slash" + dir_name + ".png", 5, 32, SLASH_FPS)
	for dir_name in DIRECTIONS:
		_add_sheet(sf, "Roll" + dir_name, CHAR_DIR + "Character_Roll" + dir_name + ".png", 4, 32, 4.0 / dash_time)
	return sf

func _build_weapon_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	for w in WEAPONS:
		for dir_name in SLASH_DIRS:
			_add_sheet(sf, WEAPONS[w].sheet + dir_name, WEAPON_DIR + WEAPONS[w].sheet + dir_name + ".png", 5, 64, SLASH_FPS)
	return sf

func set_weapon(name_key: String) -> void:
	weapon = name_key
	steak.texture = WEAPONS[name_key].hand
	hitbox.get_node("WeaponShape").scale = Vector2.ONE * WEAPONS[name_key].reach * reach_bonus

func _add_sheet(sf: SpriteFrames, anim_name: String, path: String, count: int, size: int, fps: float) -> void:
	var tex: Texture2D = load(path)
	sf.add_animation(anim_name)
	sf.set_animation_speed(anim_name, fps)
	var one_shot := anim_name.begins_with("Slash") or anim_name.begins_with("Roll") or size == 64
	sf.set_animation_loop(anim_name, not one_shot)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * size, 0, size, size)
		sf.add_frame(anim_name, at)

func _physics_process(_delta: float) -> void:
	var dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)

	if dashing:
		velocity = dash_dir * dash_speed
	else:
		velocity = dir.normalized() * speed
	move_and_slide()

	var b := GameManager.arena_bound
	global_position.x = clamp(global_position.x, -b.x, b.x)
	global_position.y = clamp(global_position.y, -b.y, b.y)

	if not dashing:
		_handle_contacts()

	if dir != Vector2.ZERO and not dashing:
		facing = dir.normalized()
		if facing.x != 0.0:
			var s := 1.0 if facing.x > 0.0 else -1.0
			steak.flip_h = s < 0.0
			steak.position.x = 34.0 * s
			steak.rotation = 0.3 * s

	if not attacking and not dashing:
		if dir != Vector2.ZERO:
			anim.play(_anim_name(facing))
		else:
			anim.stop()
			anim.frame = 0

	if can_dash and not dashing and Input.is_action_just_pressed("dash"):
		dash(dir)

	if can_attack and not dashing and Input.is_action_just_pressed("attack"):
		attack()

func dash(dir: Vector2) -> void:
	can_dash = false
	dashing = true
	dash_ready_at = Time.get_ticks_msec() + int((dash_time + dash_cooldown) * 1000.0)
	GameManager.play("dash", -6.0)
	dash_dir = dir.normalized() if dir != Vector2.ZERO else facing
	hurtbox.monitoring = false
	anim.play("Roll" + _anim_name(dash_dir))
	await get_tree().create_timer(dash_time).timeout
	dashing = false
	hurtbox.monitoring = true
	await get_tree().create_timer(dash_cooldown).timeout
	can_dash = true

func dash_progress() -> float:
	if can_dash:
		return 1.0
	var total := (dash_time + dash_cooldown) * 1000.0
	return clampf(1.0 - (dash_ready_at - Time.get_ticks_msec()) / total, 0.0, 1.0)

func _anim_name(d: Vector2) -> String:
	var deg := rad_to_deg(d.angle())
	if deg >= -112.5 and deg < -67.5: return "Up"
	if deg >= -67.5 and deg < -22.5: return "UpRight"
	if deg >= -22.5 and deg < 22.5: return "Right"
	if deg >= 22.5 and deg < 67.5: return "DownRight"
	if deg >= 67.5 and deg < 112.5: return "Down"
	if deg >= 112.5 and deg < 157.5: return "DownLeft"
	if deg >= -157.5 and deg < -112.5: return "UpLeft"
	return "Left"

func _slash_dir(d: Vector2) -> String:
	var v := "Down" if d.y >= 0.0 else "Up"
	var h := "Right" if d.x >= 0.0 else "Left"
	return v + h

func attack() -> void:
	can_attack = false
	attacking = true
	GameManager.play("swing", -4.0)
	var aim_dir := (get_global_mouse_position() - global_position).normalized()
	aim.rotation = aim_dir.angle()
	var d := _slash_dir(aim_dir)
	anim.play("Slash" + d)
	steak.visible = false
	weapon_anim.visible = true
	weapon_anim.play(WEAPONS[weapon].sheet + d)

	hitbox.monitoring = true
	await get_tree().create_timer(3.0 / SLASH_FPS).timeout
	hitbox.monitoring = false
	await get_tree().create_timer(2.0 / SLASH_FPS).timeout
	attacking = false
	weapon_anim.visible = false
	steak.visible = true
	await get_tree().create_timer(attack_cooldown * WEAPONS[weapon].cd).timeout
	can_attack = true

func _on_hitbox_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(attack_damage * WEAPONS[weapon].dmg, global_position)
		if WEAPONS[weapon].slow > 0.0 and body.has_method("apply_slow"):
			body.apply_slow(0.5, WEAPONS[weapon].slow)
		GameManager.on_hit_landed()
		_hit_stop()

func _hit_stop() -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(0.045, true, false, true).timeout
	Engine.time_scale = 1.0

func _handle_contacts() -> void:
	for body in hurtbox.get_overlapping_bodies():
		if not body.has_method("apply_knockback"):
			continue
		if damage_cooldown.is_stopped() and "contact_damage" in body and body.contact_damage > 0:
			take_damage(body.contact_damage)
			damage_cooldown.start()
		if "knockback" in body and body.knockback.length() < 50.0:
			var dir: Vector2 = (body.global_position - global_position).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.RIGHT.rotated(randf() * TAU)
			body.apply_knockback(dir, 650.0)

func _throw_tomato() -> void:
	var best: Node2D
	var best_d := 900.0
	for n in get_parent().get_children():
		if n.has_method("apply_knockback") and not n.dying:
			var d := global_position.distance_to(n.global_position)
			if d < best_d:
				best_d = d
				best = n
	if best == null:
		return
	var t := TOMATO_SCENE.instantiate()
	t.global_position = global_position
	t.target = best
	t.damage = tomato_damage
	get_parent().add_child(t)
	GameManager.play("swing", -12.0)

func heal(amount: float) -> void:
	health = minf(health + amount, max_health)
	health_changed.emit(health, max_health)

func take_damage(amount: float) -> void:
	health = max(health - amount, 0.0)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		died.emit()
		return
	GameManager.play("hurt")
	GameManager.on_player_hurt()
	_damage_flash()

func _damage_flash() -> void:
	modulate = Color(1.0, 0.25, 0.25)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.15)
	for i in 3:
		tw.tween_property(self, "modulate:a", 0.35, 0.07)
		tw.tween_property(self, "modulate:a", 1.0, 0.07)

func apply_upgrade(upgrade_name: String) -> void:
	match upgrade_name:
		"Bigger steak":
			attack_damage *= 1.25
		"Double swing":
			attack_cooldown = maxf(attack_cooldown * 0.7, 0.08)
		"Thick hide":
			max_health += 25
			health = max_health
			health_changed.emit(health, max_health)
		"Fast legs":
			speed += 40
		"Flaming steak":
			attack_damage *= 1.35
		"Long reach":
			reach_bonus *= 1.2
			set_weapon(weapon)
			attack_cooldown = maxf(attack_cooldown * 0.85, 0.08)
		"Frozen steak":
			set_weapon("frozen")
		"Bone-in steak":
			set_weapon("bone")
		"Protein shake":
			attack_damage *= 1.15
			speed += 35
		"Tomato launcher":
			if tomato_damage == 0.0:
				tomato_damage = 25.0
				tomato_timer.start()
			else:
				tomato_damage *= 1.5
				tomato_timer.wait_time = maxf(tomato_timer.wait_time * 0.75, 0.6)
