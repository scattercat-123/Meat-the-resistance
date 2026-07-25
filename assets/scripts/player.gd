extends CharacterBody2D

signal health_changed(hp: float, max_hp: float)
signal died

@export var speed := 220.0
@export var attack_damage := 15.0
@export var attack_duration := 0.15
@export var attack_cooldown := 0.4
@export var max_health := 100.0

@onready var hitbox: Area2D = $WeaponHitbox
@onready var hurtbox: Area2D = $Hurtbox

var health := 0.0
var can_attack := true
var damage_cooldown: Timer

func _ready() -> void:
	add_to_group("player")
	health = max_health
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	health_changed.emit(health, max_health)

	damage_cooldown = Timer.new()
	damage_cooldown.wait_time = 0.6
	damage_cooldown.one_shot = true
	add_child(damage_cooldown)

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

	if can_attack and Input.is_action_just_pressed("attack"):
		attack()

func attack() -> void:
	can_attack = false
	hitbox.monitoring = true
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
			body.apply_knockback(dir, 350.0)

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
