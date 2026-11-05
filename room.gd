extends Node2D

const ROOM_WIDTH = 1152.0
const ROOM_HEIGHT = 648.0
const WALL_THICKNESS = 20.0
const WALL_COLOR = Color.WHITE

const PLATFORM_THICKNESS = 8.0
const PLATFORM_COLOR = Color(1, 1, 1, 0.6)
# Center position + width of each jump-through platform
const PLATFORMS = [
	[Vector2(300, 470), 220.0],
	[Vector2(852, 470), 220.0],
	[Vector2(576, 320), 260.0],
]


func _ready():
	# Solid walls on physics layer 1
	_make_wall(Vector2(ROOM_WIDTH / 2, WALL_THICKNESS / 2), Vector2(ROOM_WIDTH, WALL_THICKNESS))                 # top
	_make_wall(Vector2(ROOM_WIDTH / 2, ROOM_HEIGHT - WALL_THICKNESS / 2), Vector2(ROOM_WIDTH, WALL_THICKNESS))   # bottom
	_make_wall(Vector2(WALL_THICKNESS / 2, ROOM_HEIGHT / 2), Vector2(WALL_THICKNESS, ROOM_HEIGHT))               # left
	_make_wall(Vector2(ROOM_WIDTH - WALL_THICKNESS / 2, ROOM_HEIGHT / 2), Vector2(WALL_THICKNESS, ROOM_HEIGHT))  # right

	# Jump-through platforms on physics layer 2
	for p in PLATFORMS:
		_make_platform(p[0], p[1])


func _draw():
	draw_rect(Rect2(0, 0, ROOM_WIDTH, WALL_THICKNESS), WALL_COLOR)
	draw_rect(Rect2(0, ROOM_HEIGHT - WALL_THICKNESS, ROOM_WIDTH, WALL_THICKNESS), WALL_COLOR)
	draw_rect(Rect2(0, 0, WALL_THICKNESS, ROOM_HEIGHT), WALL_COLOR)
	draw_rect(Rect2(ROOM_WIDTH - WALL_THICKNESS, 0, WALL_THICKNESS, ROOM_HEIGHT), WALL_COLOR)
	for p in PLATFORMS:
		var pos: Vector2 = p[0]
		var w: float = p[1]
		draw_rect(Rect2(pos.x - w / 2, pos.y - PLATFORM_THICKNESS / 2, w, PLATFORM_THICKNESS), PLATFORM_COLOR)


func _make_wall(pos: Vector2, size: Vector2):
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	add_child(body)


func _make_platform(pos: Vector2, width: float):
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, PLATFORM_THICKNESS)
	shape.shape = rect
	shape.one_way_collision = true   # jump up through it, land on top
	body.add_child(shape)
	add_child(body)
