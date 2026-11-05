extends Node2D

const ROOM_WIDTH = 1152.0
const ROOM_HEIGHT = 648.0
const WALL_THICKNESS = 20.0
const WALL_COLOR = Color.WHITE

func _ready():
	_build_walls()

func _draw():
	# Draw border
	draw_rect(Rect2(0, 0, ROOM_WIDTH, WALL_THICKNESS), WALL_COLOR)           # top
	draw_rect(Rect2(0, ROOM_HEIGHT - WALL_THICKNESS, ROOM_WIDTH, WALL_THICKNESS), WALL_COLOR)  # bottom
	draw_rect(Rect2(0, 0, WALL_THICKNESS, ROOM_HEIGHT), WALL_COLOR)           # left
	draw_rect(Rect2(ROOM_WIDTH - WALL_THICKNESS, 0, WALL_THICKNESS, ROOM_HEIGHT), WALL_COLOR)  # right

func _build_walls():
	_make_wall(Vector2(ROOM_WIDTH / 2, WALL_THICKNESS / 2), ROOM_WIDTH, WALL_THICKNESS)        # top
	_make_wall(Vector2(ROOM_WIDTH / 2, ROOM_HEIGHT - WALL_THICKNESS / 2), ROOM_WIDTH, WALL_THICKNESS)  # bottom
	_make_wall(Vector2(WALL_THICKNESS / 2, ROOM_HEIGHT / 2), WALL_THICKNESS, ROOM_HEIGHT)      # left
	_make_wall(Vector2(ROOM_WIDTH - WALL_THICKNESS / 2, ROOM_HEIGHT / 2), WALL_THICKNESS, ROOM_HEIGHT) # right

func _make_wall(pos: Vector2, width: float, height: float):
	var body = StaticBody2D.new()
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(width, height)
	shape.shape = rect
	body.position = pos
	body.add_child(shape)
	add_child(body)
