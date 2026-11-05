extends CharacterBody2D

@export var player_id := 1
@export var weapon := "sword"     # "sword" or "axe"
@export var color := Color.WHITE
@export var start_facing := 1

# --- Movement tuning ---
const SPEED = 320.0
const ACCEL = 2400.0
const AIR_ACCEL = 1600.0
const FRICTION = 2800.0
const JUMP_VELOCITY = -620.0
const DOUBLE_JUMP_VELOCITY = -560.0
const GRAVITY = 1600.0
const FAST_FALL_SPEED = 900.0
const MAX_FALL_SPEED = 700.0
const JUMP_CUT = 0.45
const MAX_JUMPS = 2
const COYOTE_TIME = 0.1
const DROP_TIME = 0.25
const ATTACK_MOVE = 0.35          # how much you can move while swinging on the ground

# --- Getting hit ---
const HITSTOP = 0.06              # tiny freeze on hit so it feels crunchy

# --- Look ---
const LINE = 3.0
const HEAD_RADIUS = 9.0
const NECK = Vector2(0, -26)
const SHOULDER = Vector2(0, -20)
const HEAD = Vector2(0, -35)
const LIMB = 13.0
const FLIP_TIME = 0.35
const HURT_BOX = Rect2(-12, -44, 24, 70)   # matches the collision capsule

# Attack moves, shared by both weapons. Angles: 0 = arm straight down,
# PI/2 = straight forward, PI = straight up. The arm swings from "from" to "to".
const MOVES = {
	"jab":      {"windup": 0.05, "active": 0.09, "recovery": 0.14, "knockback": Vector2(280, -180), "from": 2.5, "to": 0.5},
	"side":     {"windup": 0.08, "active": 0.10, "recovery": 0.18, "knockback": Vector2(420, -170), "from": 2.0, "to": 1.2, "lunge": 260.0},
	"up":       {"windup": 0.07, "active": 0.14, "recovery": 0.18, "knockback": Vector2(60, -560),  "from": 0.3, "to": 3.9},
	"down":     {"windup": 0.07, "active": 0.10, "recovery": 0.18, "knockback": Vector2(300, -300), "from": 1.5, "to": 0.6},
	"down_air": {"windup": 0.10, "active": 0.12, "recovery": 0.20, "knockback": Vector2(40, 560),   "from": 2.8, "to": 0.0},
}
# How each weapon changes the moves: axe is slower but hits harder
const WEAPONS = {
	"sword": {"length": 40.0, "speed": 1.0, "power": 1.0},
	"axe":   {"length": 32.0, "speed": 1.45, "power": 1.3},
}
const REST_ARM = 0.5              # front arm angle when not attacking
const CHARGE_MAX = 1.0            # seconds to fully charge
const CHARGE_START = 0.1          # holding shorter than this is just a normal hit
const CHARGE_BONUS = 1.0          # full charge = 1 + this times the knockback

var jumps_left := MAX_JUMPS
var coyote := 0.0
var drop_timer := 0.0
var facing := 1
var anim_time := 0.0
var flip_timer := 0.0
var hitstun := 0.0
var hitstop := 0.0

var attack: Dictionary = {}       # current attack's data, empty when not attacking
var attack_t := 0.0
var attack_hit := false           # only one hit per swing
var charge := 0.0                 # how long the attack button was held in the windup
var charge_done := false          # let go (or maxed out), so the swing goes
var last_angle := REST_ARM        # arm angle last frame, so fast swings don't skip past people


func _ready():
	facing = start_facing
	add_to_group("players")


func act(action: String) -> String:
	return "p%d_%s" % [player_id, action]


func _physics_process(delta):
	if hitstop > 0:
		hitstop -= delta
		return

	hitstun = max(hitstun - delta, 0.0)
	var can_act := hitstun == 0
	var dir := Input.get_axis(act("left"), act("right")) if can_act else 0.0
	if dir != 0 and attack.is_empty():
		facing = int(sign(dir))

	# Gravity + fast fall
	if is_on_floor():
		jumps_left = MAX_JUMPS
		coyote = COYOTE_TIME
	else:
		coyote -= delta
		if coyote <= 0 and jumps_left == MAX_JUMPS:
			jumps_left = MAX_JUMPS - 1
		var fast := can_act and Input.is_action_pressed(act("down"))
		velocity.y = min(velocity.y + GRAVITY * delta, FAST_FALL_SPEED if fast else MAX_FALL_SPEED)

	if can_act:
		# Jump / double jump
		if Input.is_action_just_pressed(act("jump")) and jumps_left > 0:
			var air_jump := not is_on_floor() and coyote <= 0
			velocity.y = DOUBLE_JUMP_VELOCITY if air_jump else JUMP_VELOCITY
			jumps_left -= 1
			coyote = 0
			if air_jump:
				flip_timer = FLIP_TIME
		if Input.is_action_just_released(act("jump")) and velocity.y < 0:
			velocity.y *= JUMP_CUT

		# Drop through platforms
		if is_on_floor() and Input.is_action_just_pressed(act("down")):
			drop_timer = DROP_TIME

		# Start an attack
		if attack.is_empty():
			if Input.is_action_just_pressed(act("attack")):
				_start_attack(dir)
			# act("special") is mapped but does nothing yet

	drop_timer -= delta
	set_collision_mask_value(2, drop_timer <= 0)

	# Horizontal movement
	if hitstun > 0:
		velocity.x = move_toward(velocity.x, 0, 500 * delta)   # sliding from knockback
	else:
		var target := dir * SPEED
		if not attack.is_empty() and is_on_floor():
			target *= ATTACK_MOVE
		var accel := ACCEL if is_on_floor() else AIR_ACCEL
		if dir != 0:
			velocity.x = move_toward(velocity.x, target, accel * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, (FRICTION if is_on_floor() else AIR_ACCEL) * delta)

	_update_attack(delta)
	move_and_slide()


# ---------------------------------------------------------------
# Attacks
# ---------------------------------------------------------------
func _start_attack(dir: float):
	# Pick the move from the direction being held
	var move := "jab"
	if Input.is_action_pressed(act("jump")):
		move = "up"
	elif Input.is_action_pressed(act("down")):
		move = "down" if is_on_floor() else "down_air"
	elif dir != 0:
		move = "side"
		facing = int(sign(dir))

	# Copy the move and scale it for this weapon
	var w: Dictionary = WEAPONS[weapon]
	attack = MOVES[move].duplicate()
	attack.name = move
	for key in ["windup", "active", "recovery"]:
		attack[key] *= w.speed
	attack.knockback *= w.power
	attack_t = 0.0
	attack_hit = false
	charge = 0.0
	charge_done = not is_on_floor()   # only charge on the ground, like Smash
	last_angle = REST_ARM
	flip_timer = 0.0


func _charge_frac() -> float:
	return clamp((charge - CHARGE_START) / (CHARGE_MAX - CHARGE_START), 0.0, 1.0)


func _update_attack(delta):
	if attack.is_empty():
		return
	var a: Dictionary = attack

	# Hold the button at the end of the windup to charge
	if not charge_done and attack_t + delta >= a.windup:
		if Input.is_action_pressed(act("attack")) and charge < CHARGE_MAX and hitstun == 0:
			attack_t = a.windup
			charge += delta
			return
		charge_done = true

	var was_active: bool = attack_t >= a.windup
	attack_t += delta
	if not was_active and attack_t >= a.windup and a.has("lunge") and is_on_floor():
		velocity.x = facing * a.lunge * (1.0 + _charge_frac() * 0.5)

	if not attack_hit and attack_t >= a.windup and attack_t <= a.windup + a.active + delta:
		_check_hit()
	last_angle = _arm_angle()
	if attack_t >= a.windup + a.active + a.recovery:
		attack = {}


func _arm_angle() -> float:
	# Front arm angle for the current moment of the attack
	if attack.is_empty():
		return REST_ARM
	var a: Dictionary = attack
	if attack_t < a.windup:
		return lerp(REST_ARM, float(a.from), ease(attack_t / a.windup, 0.5))
	if attack_t < a.windup + a.active:
		return lerp(float(a.from), float(a.to), ease((attack_t - a.windup) / a.active, 0.6))
	var rec: float = (attack_t - a.windup - a.active) / a.recovery
	return lerp(float(a.to), REST_ARM, ease(rec, 2.0))


func _dir(angle: float) -> Vector2:
	return Vector2(sin(angle) * facing, cos(angle))


func _check_hit():
	# Sample points along the arm + weapon, at a few angles between last frame and now,
	# and see if any land inside the other player
	var length: float = WEAPONS[weapon].length
	var now := _arm_angle()
	for other in get_tree().get_nodes_in_group("players"):
		if other == self:
			continue
		var box: Rect2 = other.HURT_BOX
		box.position += other.global_position
		for step in 4:
			var angle: float = lerp(last_angle, now, step / 3.0)
			var hand := SHOULDER + _dir(angle) * LIMB * 2
			var tip := hand + _dir(angle) * length
			for i in 9:
				if box.has_point(global_position + hand.lerp(tip, i / 8.0)):
					var power := 1.0 + _charge_frac() * CHARGE_BONUS
					other.take_hit(attack.knockback * power, facing, HITSTOP * power)
					attack_hit = true
					hitstop = HITSTOP * power
					return


func take_hit(knockback: Vector2, from_dir: int, stop: float):
	var kb := Vector2(knockback.x * from_dir, knockback.y)
	if kb.y > 0 and is_on_floor():
		kb.y = -kb.y * 0.5                 # spiked into the ground: bounce up instead
	velocity = kb
	hitstun = 0.2 + knockback.length() * 0.0004
	hitstop = stop
	attack = {}
	flip_timer = 0.0
	facing = -from_dir                      # turn to face whoever hit you


func _process(delta):
	anim_time += delta
	flip_timer = max(flip_timer - delta, 0.0)
	queue_redraw()


# ---------------------------------------------------------------
# Procedural animation
# Every limb is two segments. Angles in radians:
#   0 = pointing straight down, positive = toward the way you're facing.
# The second number is relative to the first (knee / elbow bend).
# ---------------------------------------------------------------
func _draw():
	var t := anim_time
	var bob := 0.0
	var lean := 0.0
	var leg_a := Vector2.ZERO
	var leg_b := Vector2.ZERO
	var arm_front := Vector2(REST_ARM, 0.6)   # holds the weapon
	var arm_back := Vector2(-0.4, -0.25)

	if hitstun > 0:
		# Recoiling: limbs thrown back
		leg_a = Vector2(-0.5, 0.6)
		leg_b = Vector2(-0.2, 0.3)
		arm_front = Vector2(-1.8, 0.4)
		arm_back = Vector2(-2.4, 0.3)
		lean = -0.35
	elif flip_timer > 0:
		leg_a = Vector2(1.6, -2.2)
		leg_b = Vector2(1.3, -2.0)
		arm_front = Vector2(1.2, 1.0)
		arm_back = Vector2(0.9, 1.0)
	elif not is_on_floor():
		if velocity.y < 0:
			leg_a = Vector2(1.0, -1.5)
			leg_b = Vector2(0.2, -0.6)
			arm_front = Vector2(2.2, 0.3)
			arm_back = Vector2(-2.2, -0.3)
		else:
			var flail := sin(t * 14.0) * 0.15
			leg_a = Vector2(0.35, -0.4)
			leg_b = Vector2(-0.2, -0.2)
			arm_front = Vector2(1.9 + flail, 0.3)
			arm_back = Vector2(-1.9 - flail, -0.3)
	elif abs(velocity.x) > 20:
		var speed_frac: float = min(abs(velocity.x) / SPEED, 1.0)
		var p := t * 13.0
		var swing := 0.9 * speed_frac
		bob = -abs(sin(p)) * 3.0 * speed_frac
		lean = 0.18 * speed_frac
		leg_a = Vector2(sin(p) * swing, -0.9 * (0.5 + 0.5 * cos(p)) * speed_frac)
		leg_b = Vector2(-sin(p) * swing, -0.9 * (0.5 - 0.5 * cos(p)) * speed_frac)
		arm_front = Vector2(REST_ARM - sin(p) * swing * 0.5, 0.6)
		arm_back = Vector2(sin(p) * swing, 1.2)
	else:
		var breathe := sin(t * 2.5)
		bob = breathe * 1.0
		leg_a = Vector2(0.25, 0.0)
		leg_b = Vector2(-0.25, 0.0)
		arm_front = Vector2(REST_ARM + breathe * 0.04, 0.6)
		arm_back = Vector2(-0.4 - breathe * 0.05, -0.25)

	# Attacking overrides the front arm: straight arm swinging through the arc
	var weapon_angle := arm_front.x + arm_front.y + 1.1   # held up at rest
	var swing_dir := -1.0
	var shake := 0.0
	if not attack.is_empty():
		arm_front = Vector2(_arm_angle(), 0.0)
		weapon_angle = arm_front.x
		swing_dir = sign(attack.to - attack.from)
		lean = 0.15 if attack_t > attack.windup else -0.1
		if attack.name == "down":
			leg_a = Vector2(1.0, -1.2)       # crouch for the low sweep
			leg_b = Vector2(-0.6, -0.9)
			bob = 6.0
		if attack_t >= attack.windup and not charge_done:
			shake = sin(t * 70.0) * 2.0 * (0.3 + _charge_frac())   # trembling while charging

	var xf := Transform2D(lean * facing, Vector2(shake, bob))
	if flip_timer > 0:
		var spin := (1.0 - flip_timer / FLIP_TIME) * TAU * facing
		var center := Vector2(0, -12)
		xf = Transform2D(0, center) * Transform2D(spin, Vector2.ZERO) * Transform2D(0, -center)
	draw_set_transform_matrix(xf)

	# Flash red-ish while in hitstun
	var c := color
	if hitstun > 0 and int(t * 20) % 2 == 0:
		c = Color(1, 0.3, 0.3)

	var hip := Vector2.ZERO
	_limb(SHOULDER, arm_back, c)
	draw_line(hip, NECK, c, LINE)
	draw_circle(HEAD, HEAD_RADIUS, c, false, LINE)
	_limb(hip, leg_a, c)
	_limb(hip, leg_b, c)
	var hand := _limb(SHOULDER, arm_front, c)
	_draw_weapon(hand, weapon_angle, swing_dir)


func _limb(origin: Vector2, angles: Vector2, c: Color) -> Vector2:
	var joint := origin + _dir(angles.x) * LIMB
	var tip := joint + _dir(angles.x + angles.y) * LIMB
	draw_line(origin, joint, c, LINE)
	draw_line(joint, tip, c, LINE)
	return tip


func _draw_weapon(hand: Vector2, angle: float, swing_dir: float):
	var d := _dir(angle)
	# Side the edge faces (the direction the swing travels)
	var edge := Vector2(-cos(angle) * facing, sin(angle)) * -swing_dir
	var length: float = WEAPONS[weapon].length
	var tip := hand + d * length
	# Glow while charging: blink brighter the longer it's held
	var glow := 0.0
	if not attack.is_empty() and not charge_done and charge > CHARGE_START:
		glow = (0.4 + 0.6 * _charge_frac()) * (0.6 + 0.4 * sin(anim_time * 30.0))

	if weapon == "sword":
		var steel := Color(0.75, 0.75, 0.78).lerp(Color(1, 1, 0.75), glow)
		var guard := hand + d * 5
		draw_line(hand - d * 5, guard, Color(0.45, 0.45, 0.48), 4)          # grip
		draw_line(guard - edge * 7, guard + edge * 7, Color(0.6, 0.6, 0.63), 3)    # crossguard
		draw_colored_polygon(PackedVector2Array([
			guard - edge * 2.5, guard + edge * 2.5, tip - d * 6 + edge * 2.5, tip, tip - d * 6 - edge * 2.5
		]), steel)
	else:
		draw_line(hand - d * 6, tip, Color(0.45, 0.45, 0.48), 4)            # handle
		var head := tip - d * 6
		var steel := Color(0.75, 0.78, 0.82).lerp(Color(1, 1, 0.75), glow)
		draw_colored_polygon(PackedVector2Array([
			head - d * 6, head + d * 5,
			head + d * 11 + edge * 14, head + edge * 16, head - d * 12 + edge * 14,
		]), steel)
		draw_colored_polygon(PackedVector2Array([
			head - d * 4, head + d * 3, head + d * 2 - edge * 6, head - d * 3 - edge * 6,
		]), steel)                                                         # small back spike
