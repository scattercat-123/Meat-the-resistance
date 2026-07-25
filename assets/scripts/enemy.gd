extends CharacterBody2D

@export var speed := 90.0
@export var max_health := 30.0
@export var contact_damage := 10.0

var health := 0.0
var target: Node2D
var knockback := Vector2.ZERO

func _ready() -> void:
	health = max_health
	target = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if knockback.length() > 10.0:
		velocity = knockback
		knockback = knockback.move_toward(Vector2.ZERO, 900.0 * delta)
	elif target:
		velocity = (target.global_position - global_position).normalized() * speed
	move_and_slide()

func apply_knockback(dir: Vector2, force: float) -> void:
	knockback = dir * force

func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0:
		die()

func die() -> void:
	GameManager.on_enemy_died()
	queue_free()
