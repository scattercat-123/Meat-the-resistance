extends CharacterBody2D

signal health_changed(hp: float, max_hp: float)
signal died

const CHAR_DIR := "res://assets/images/character/"
const WEAPON_DIR := "res://assets/images/weapon/"
const DIRECTIONS := ["Down", "Up", "Left", "Right", "DownLeft", "DownRight", "UpLeft", "UpRight"]
const SLASH_DIRS := ["DownRight", "DownLeft", "UpRight", "UpLeft"]
const SLASH_FPS := 14.0

@export var speed := 220.0
@export var attack_damage := 15.0
@export var attack_cooldown := 0.25
@export var max_health := 100.0

@onready var anim: AnimatedSprite2D = $Anim
@onready var weapon_anim: AnimatedSprite2D = $WeaponAnim
@onready var aim: Node2D = $Aim
@onready var hitbox: Area2D = $Aim/WeaponHitbox
@onready var hurtbox: Area2D = $Hurtbox

var health := 0.0
var can_attack := true
var attacking := false
var facing := Vector2.DOWN
var damage_cooldown: Timer

func _ready() -> void:
	add_to_group("player")
	health = max_health
	anim.sprite_frames = _build_char_frames()
	anim.play("Down")
	weapon_anim.sprite_frames = _build_weapon_frames()
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	health_changed.emit(health, max_health)

	damage_cooldown = Timer.new()
	damage_cooldown.wait_time = 0.6
	damage_cooldown.one_shot = true
	add_child(damage_cooldown)

func _build_char_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	for dir_name in DIRECTIONS:
		_add_sheet(sf, dir_name, CHAR_DIR + "Character_" + dir_name + ".png", 4, 32, 8.0)
	for dir_name in SLASH_DIRS:
		_add_sheet(sf, "Slash" + dir_name, CHAR_DIR + "Character_Slash" + dir_name + ".png", 5, 32, SLASH_FPS)
	return sf

func _build_weapon_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	for dir_name in SLASH_DIRS:
		_add_sheet(sf, dir_name, WEAPON_DIR + "Steak_" + dir_name + ".png", 5, 64, SLASH_FPS)
	return sf

func _add_sheet(sf: SpriteFrames, anim_name: String, path: String, count: int, size: int, fps: float) -> void:
	var tex: Texture2D = load(path)
	sf.add_animation(anim_name)
	sf.set_animation_speed(anim_name, fps)
	sf.set_animation_loop(anim_name, false if anim_name.begins_with("Slash") or size == 64 else true)
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
	velocity = dir.normalized() * speed
	move_and_slide()

	var b := GameManager.arena_bound
	global_position.x = clamp(global_position.x, -b.x, b.x)
	global_position.y = clamp(global_position.y, -b.y, b.y)

	if dir != Vector2.ZERO:
		facing = dir.normalized()
		aim.rotation = facing.angle()

	if not attacking:
		if dir != Vector2.ZERO:
			anim.play(_anim_name(facing))
		else:
			anim.stop()
			anim.frame = 0

	if can_attack and Input.is_action_just_pressed("attack"):
		attack()

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

func _slash_dir() -> String:
	var v := "Down" if facing.y >= 0.0 else "Up"
	var h := "Right" if facing.x >= 0.0 else "Left"
	return v + h

func attack() -> void:
	can_attack = false
	attacking = true
	var d := _slash_dir()
	anim.play("Slash" + d)
	weapon_anim.visible = true
	weapon_anim.play(d)

	hitbox.monitoring = true
	await get_tree().create_timer(3.0 / SLASH_FPS).timeout
	hitbox.monitoring = false
	await get_tree().create_timer(2.0 / SLASH_FPS).timeout
	attacking = false
	weapon_anim.visible = false
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func _on_hitbox_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(attack_damage)

func _on_hurtbox_body_entered(body: Node) -> void:
	if not damage_cooldown.is_stopped():
		return
	if "contact_damage" in body:
		take_damage(body.contact_damage)
		damage_cooldown.start()
		if body.has_method("apply_knockback"):
			var dir: Vector2 = (body.global_position - global_position).normalized()
			body.apply_knockback(dir, 650.0)

func take_damage(amount: float) -> void:
	health = max(health - amount, 0.0)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		died.emit()

func apply_upgrade(upgrade_name: String) -> void:
	match upgrade_name:
		"Bigger steak":
			attack_damage += 10
		"Double swing":
			attack_cooldown *= 0.6
		"Thick hide":
			max_health += 20
			health = max_health
			health_changed.emit(health, max_health)
		"Fast legs":
			speed += 40
		"Flaming steak":
			attack_damage += 15
		"Long reach":
			hitbox.get_node("WeaponShape").scale *= 1.2
			attack_cooldown *= 0.85
