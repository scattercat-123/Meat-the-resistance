extends CharacterBody2D

@onready var change_state_timer: Timer = $change_state_timer
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var speed := 90.0
@export var max_health := 30.0
@export var contact_damage := 10.0

var health := 0.0
var target: Node2D
var knockback := Vector2.ZERO
var follow = true
var angle
var angle_deg

func _ready() -> void:
	randomize()
	health = max_health
	target = get_tree().get_first_node_in_group("player")
	change_state_timer.wait_time = randf_range(3, 5)
	change_state_timer.start()

func _physics_process(delta: float) -> void:
	angle = velocity.angle()
	angle_deg = rad_to_deg(angle)
	if knockback.length() > 10.0:
		velocity = knockback
		knockback = knockback.move_toward(Vector2.ZERO, 700.0 * delta)
	elif target and follow:
		velocity = (target.global_position - global_position).normalized() * speed
		movement()
	move_and_slide()

	var b := GameManager.arena_bound
	global_position.x = clamp(global_position.x, -b.x, b.x)
	global_position.y = clamp(global_position.y, -b.y, b.y)

func apply_knockback(dir: Vector2, force: float) -> void:
	knockback = dir * force

func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0:
		die()

func die() -> void:
	GameManager.on_enemy_died()
	queue_free()

func _on_change_state_timer_timeout() -> void:
	change_state_timer.wait_time = randf_range(3, 5)
	change_state_timer.start()
	change_state()

func movement():
	if angle_deg >= -22.5 and angle_deg < 22.5:
		sprite.play("walk_right")
	elif angle_deg >= 22.5 and angle_deg < 67.5:
		sprite.play("walk_front_right")
	elif angle_deg >= 67.5 and angle_deg < 112.5:
		sprite.play("walk_front")
	elif angle_deg >= 112.5 and angle_deg < 157.5:
		sprite.play("walk_front_left")
	elif angle_deg >= 157.5 or angle_deg < -157.5:
		sprite.play("walk_left")
	elif angle_deg >= -157.5 and angle_deg < -112.5:
		sprite.play("walk_bottom_left")
	elif angle_deg >= -112.5 and angle_deg < -67.5:
		sprite.play("walk_bottom")
	elif angle_deg >= -67.5 and angle_deg < -22.5:
		sprite.play("walk_bottom_right")

func change_state():
	var rand = randi_range(1,3)
	if rand == 1:
		follow = true
		contact_damage = 10
	elif rand == 2:
		follow = false
		velocity = Vector2.ZERO
		contact_damage = 15
	elif rand == 3:
		follow = true
		contact_damage = 0
