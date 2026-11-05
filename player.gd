extends CharacterBody2D

# --- Movement tuning ---
const SPEED = 320.0
const ACCEL = 2400.0          # how fast you reach full speed
const AIR_ACCEL = 1600.0      # a bit floatier in the air
const FRICTION = 2800.0       # how fast you stop on the ground
const JUMP_VELOCITY = -620.0
const DOUBLE_JUMP_VELOCITY = -560.0
const GRAVITY = 1600.0
const FAST_FALL_SPEED = 900.0 # hold S in the air
const MAX_FALL_SPEED = 700.0
const JUMP_CUT = 0.45         # let go of jump early = shorter hop
const MAX_JUMPS = 2
const COYOTE_TIME = 0.1       # can still jump just after walking off a ledge
const DROP_TIME = 0.25        # S on a platform drops through it

# --- Look ---
const COLOR = Color.WHITE
const LINE = 3.0
const HEAD_RADIUS = 9.0
const NECK = Vector2(0, -26)
const SHOULDER = Vector2(0, -20)
const HEAD = Vector2(0, -35)
const LIMB = 13.0             # length of each limb segment
const FLIP_TIME = 0.35

var jumps_left := MAX_JUMPS
var coyote := 0.0
var drop_timer := 0.0
var facing := 1
var anim_time := 0.0
var flip_timer := 0.0


func _physics_process(delta):
	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0:
		facing = int(sign(dir))

	# Gravity + fast fall
	if is_on_floor():
		jumps_left = MAX_JUMPS
		coyote = COYOTE_TIME
	else:
		coyote -= delta
		if coyote <= 0 and jumps_left == MAX_JUMPS:
			jumps_left = MAX_JUMPS - 1  # walked off a ledge: only the air jump is left
		var max_fall := FAST_FALL_SPEED if Input.is_action_pressed("move_down") else MAX_FALL_SPEED
		velocity.y = min(velocity.y + GRAVITY * delta, max_fall)

	# Jump / double jump
	if Input.is_action_just_pressed("jump") and jumps_left > 0:
		var air_jump := not is_on_floor() and coyote <= 0
		velocity.y = DOUBLE_JUMP_VELOCITY if air_jump else JUMP_VELOCITY
		jumps_left -= 1
		coyote = 0
		if air_jump:
			flip_timer = FLIP_TIME
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= JUMP_CUT

	# Drop through one-way platforms (layer 2)
	if is_on_floor() and Input.is_action_just_pressed("move_down"):
		drop_timer = DROP_TIME
	drop_timer -= delta
	set_collision_mask_value(2, drop_timer <= 0)

	# Run
	var accel := ACCEL if is_on_floor() else AIR_ACCEL
	if dir != 0:
		velocity.x = move_toward(velocity.x, dir * SPEED, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, (FRICTION if is_on_floor() else AIR_ACCEL) * delta)

	move_and_slide()


func _process(delta):
	anim_time += delta
	flip_timer = max(flip_timer - delta, 0.0)
	queue_redraw()


# ---------------------------------------------------------------
# Procedural animation
# Every limb is two segments. Angles are in radians:
#   0 = pointing straight down, positive = toward the way you're facing.
# The second angle is relative to the first (knee / elbow bend).
# ---------------------------------------------------------------
func _draw():
	var t := anim_time
	var bob := 0.0
	var lean := 0.0
	# [thigh, shin] for each leg, [upper, fore] for each arm
	var leg_a := Vector2.ZERO
	var leg_b := Vector2.ZERO
	var arm_a := Vector2.ZERO
	var arm_b := Vector2.ZERO

	if flip_timer > 0:
		# Tucked ball for the double-jump spin
		leg_a = Vector2(1.6, -2.2)
		leg_b = Vector2(1.3, -2.0)
		arm_a = Vector2(1.2, 1.0)
		arm_b = Vector2(0.9, 1.0)
	elif not is_on_floor():
		if velocity.y < 0:
			# Going up: knees up, arms up
			leg_a = Vector2(1.0, -1.5)
			leg_b = Vector2(0.2, -0.6)
			arm_a = Vector2(2.2, 0.3)
			arm_b = Vector2(-2.2, -0.3)
		else:
			# Falling: legs dangle, arms out, a little flail
			var flail := sin(t * 14.0) * 0.15
			leg_a = Vector2(0.35, -0.4)
			leg_b = Vector2(-0.2, -0.2)
			arm_a = Vector2(1.9 + flail, 0.3)
			arm_b = Vector2(-1.9 - flail, -0.3)
	elif abs(velocity.x) > 20:
		# Run cycle: legs swing opposite each other, arms opposite the legs
		var speed_frac: float = abs(velocity.x) / SPEED
		var p := t * 13.0
		var swing := 0.9 * speed_frac
		bob = -abs(sin(p)) * 3.0 * speed_frac
		lean = 0.18 * speed_frac
		leg_a = Vector2(sin(p) * swing, -0.9 * (0.5 + 0.5 * cos(p)) * speed_frac)
		leg_b = Vector2(-sin(p) * swing, -0.9 * (0.5 - 0.5 * cos(p)) * speed_frac)
		arm_a = Vector2(-sin(p) * swing, 1.2)
		arm_b = Vector2(sin(p) * swing, 1.2)
	else:
		# Idle: slow breathing sway
		var breathe := sin(t * 2.5)
		bob = breathe * 1.0
		leg_a = Vector2(0.15, 0.0)
		leg_b = Vector2(-0.15, 0.0)
		arm_a = Vector2(0.4 + breathe * 0.05, 0.25)
		arm_b = Vector2(-0.4 - breathe * 0.05, -0.25)

	# Whole-body transform: bob + lean, and the spin during a double jump
	var xf := Transform2D(lean * facing, Vector2(0, bob))
	if flip_timer > 0:
		var spin := (1.0 - flip_timer / FLIP_TIME) * TAU * facing
		var center := Vector2(0, -12)
		xf = Transform2D(0, center) * Transform2D(spin, Vector2.ZERO) * Transform2D(0, -center)
	draw_set_transform_matrix(xf)

	var hip := Vector2.ZERO
	draw_line(hip, NECK, COLOR, LINE)                      # torso
	draw_circle(HEAD, HEAD_RADIUS, COLOR, false, LINE)     # head
	_limb(hip, leg_a)
	_limb(hip, leg_b)
	_limb(SHOULDER, arm_a)
	_limb(SHOULDER, arm_b)


func _limb(origin: Vector2, angles: Vector2):
	var a1 := angles.x
	var a2 := angles.x + angles.y
	var joint := origin + Vector2(sin(a1) * facing, cos(a1)) * LIMB
	var tip := joint + Vector2(sin(a2) * facing, cos(a2)) * LIMB
	draw_line(origin, joint, COLOR, LINE)
	draw_line(joint, tip, COLOR, LINE)
