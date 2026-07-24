extends CharacterBody2D

@export var speed := 220.0
@export var attack_damage := 15.0
@export var attack_duration := 0.15
@export var attack_cooldown := 0.4

@onready var hitbox: Area2D = $WeaponHitbox

var can_attack := true

func _ready() -> void:
	add_to_group("player")
	hitbox.body_entered.connect(_on_hitbox_body_entered)

func _physics_process(_delta: float) -> void:
	var dir := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
	velocity = dir.normalized() * speed
	move_and_slide()

	if can_attack and Input.is_action_just_pressed("ui_accept"):
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
