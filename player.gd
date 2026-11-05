extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -600.0
const GRAVITY = 1500.0
const MAX_JUMPS = 2

var jumps_left = MAX_JUMPS

func _physics_process(delta):
	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		jumps_left = MAX_JUMPS

	# Jump (space, up arrow, or W)
	var jump_pressed = Input.is_action_just_pressed("ui_accept") \
		or Input.is_action_just_pressed("ui_up") \
		or Input.is_key_pressed(KEY_W)
	if jump_pressed and jumps_left > 0:
		velocity.y = JUMP_VELOCITY
		jumps_left -= 1

	# Left/right
	var direction = 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		direction = -1.0
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		direction = 1.0

	velocity.x = direction * SPEED
	move_and_slide()

func _draw():
	draw_circle(Vector2(0, -35), 15, Color.WHITE)
	draw_line(Vector2(0, -20), Vector2(0, 10), Color.WHITE, 3)
	draw_line(Vector2(0, -20), Vector2(-25, 5), Color.WHITE, 3)
	draw_line(Vector2(0, -20), Vector2(25, 5), Color.WHITE, 3)
	draw_line(Vector2(0, 10), Vector2(-20, 30), Color.WHITE, 3)
	draw_line(Vector2(0, 10), Vector2(20, 30), Color.WHITE, 3)
