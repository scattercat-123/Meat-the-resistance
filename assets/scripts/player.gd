extends CharacterBody2D

signal health_changed(hp: float, max_hp: float)
signal died

const CHAR_DIR := "res://assets/images/character/"
const DIRECTIONS := ["Down", "Up", "Left", "Right", "DownLeft", "DownRight", "UpLeft", "UpRight"]

@export var speed := 220.0
@export var attack_damage := 15.0
@export var attack_duration := 0.15
@export var attack_cooldown := 0.4
@export var max_health := 100.0

@onready var anim: AnimatedSprite2D = $Anim
@onready var aim: Node2D = $Aim
@onready var steak: Sprite2D = $Aim/Steak
@onready var hitbox: Area2D = $Aim/WeaponHitbox
@onready var hurtbox: Area2D = $Hurtbox

var health := 0.0
var can_attack := true
var facing := Vector2.DOWN
var damage_cooldown: Timer

func _ready() -> void:
	add_to_group("player")
	health = max_health
	anim.sprite_frames = _build_frames()
	anim.play("Down")
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	health_changed.emit(health, max_health)

	damage_cooldown = Timer.new()
	damage_cooldown.wait_time = 0.6
	damage_cooldown.one_shot = true
	add_child(damage_cooldown)

func _build_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	for dir_name in DIRECTIONS:
		var tex: Texture2D = load(CHAR_DIR + "Character_" + dir_name + ".png")
		sf.add_animation(dir_name)
		sf.set_animation_speed(dir_name, 8.0)
		for i in 4:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * 32, 0, 32, 32)
			sf.add_frame(dir_name, at)
	return sf

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

func attack() -> void:
	can_attack = false
	hitbox.monitoring = true
	var tw := create_tween()
	tw.tween_property(steak, "rotation", 1.6, attack_duration).from(-0.9)
	tw.tween_property(steak, "rotation", 0.35, 0.1)
	await get_tree().create_timer(attack_duration).timeout
	hitbox.monitoring = false
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
			attack_cooldown *= 0.7
		"Thick hide":
			max_health += 20
			health = max_health
			health_changed.emit(health, max_health)
		"Fast legs":
			speed += 40
		"Flaming steak":
			attack_damage += 15
			attack_duration += 0.05
		"Long reach":
			hitbox.scale *= 1.15
			attack_cooldown *= 0.85
