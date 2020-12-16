extends KinematicBody2D

onready var left_ray := $left_ray
onready var right_ray := $right_ray

var motion := Vector2.ZERO
var up := Vector2.UP

var jumping_speed_inc_factor := 0.5

var speed_inc := 40.0
var max_speed := 160.0

var gravity_inc := 20.0
var gravity_max := 500.0

var wall_slide_inc := 5.0
var wall_slide_max := 20.0

var jump := 350.0
var wall_jump := 300.0
var double_jump := 250.0

var physics_fps := float(str(ProjectSettings.get("physics/common/physics_fps")))
var single_frame_time := 1.0 / physics_fps

var trying_to_jump_max_time := 7.0 * single_frame_time
var trying_to_jump_timeout := 0.0

var was_on_floor_max_time := 4.0 * single_frame_time
var was_on_floor_timeout := 0.0

var was_on_wall_max_time := 7.0 * single_frame_time
var was_on_wall_timeout := 0.0

var on_wall_timeout := 0.2
var is_on_wall_timer := 0.0

var _is_on_floor := false
var _is_on_wall := false
var _user_wants_to_jump := false
var _has_jumped := false
var _has_wall_jumped := false
var _forcing_wall_slide := false
var _has_double_jumped := false
var _has_released_after_jump := false
var _has_released_after_wall_jump := false

var collision_normal := Vector2.ZERO

func _update_is_on_floor(delta: float):
	was_on_floor_timeout -= delta
	if is_on_floor():
		was_on_floor_timeout = was_on_floor_max_time
	_is_on_floor = was_on_floor_timeout >= 0.0
	if _is_on_floor:
		_has_double_jumped = false

func _update_is_on_wall(delta: float):
	was_on_wall_timeout -= delta
	if is_on_wall():
		was_on_wall_timeout = was_on_wall_max_time
	if right_ray.is_colliding():
		collision_normal = right_ray.get_collision_normal()
	elif left_ray.is_colliding():
		collision_normal = left_ray.get_collision_normal()
	else:
		collision_normal = Vector2.ZERO
	_is_on_wall = was_on_wall_timeout >= 0.0 or collision_normal != Vector2.ZERO

	if not _forcing_wall_slide:
		is_on_wall_timer -= delta

func _update_user_input(delta: float):
	trying_to_jump_timeout -= delta
	if Input.is_action_just_pressed("ui_up"):
		trying_to_jump_timeout = trying_to_jump_max_time
	elif Input.is_action_just_released("ui_up"):
		_has_jumped = false
		_has_wall_jumped = false
		_has_released_after_jump = true
	_user_wants_to_jump = trying_to_jump_timeout >= 0.0

func _update_lateral_movement(delta: float):
	var speed_inc_factor := 1.0 if _is_on_floor else jumping_speed_inc_factor
	var _speed_inc = speed_inc * speed_inc_factor

	if Input.is_action_pressed("ui_right"):
		motion.x += _speed_inc
		
		if collision_normal.x < 0.0:
			is_on_wall_timer = on_wall_timeout
			_forcing_wall_slide = true
		else:
			_forcing_wall_slide = false
	elif Input.is_action_pressed("ui_left"):
		motion.x -= _speed_inc
		
		if collision_normal.x > 0.0:
			is_on_wall_timer = on_wall_timeout
			_forcing_wall_slide = true
		else:
			_forcing_wall_slide = false
	else:
		_forcing_wall_slide = false
		if motion.x < 0.0:
			motion.x += _speed_inc
			if motion.x > 0.0: motion.x = 0.0
		elif motion.x > 0.0:
			motion.x -= _speed_inc
			if motion.x < 0.0: motion.x = 0.0

	motion.x = clamp(motion.x, -max_speed, max_speed)

func _can_jump():
	return _is_on_floor and not _has_jumped

func _jump():
	motion.y = -jump
	_has_jumped = true
	trying_to_jump_timeout = 0.0
	_has_released_after_jump = false

func _can_wall_jump():
	return _is_on_wall and collision_normal != Vector2.ZERO and \
		not _has_wall_jumped and not _has_jumped

func _wall_jump():
	print("wall jump")
	motion.y = -wall_jump
	motion.x = collision_normal.x * wall_jump
	_has_wall_jumped = true

func _can_double_jump():
	return not _has_double_jumped and not _is_on_floor and not _has_wall_jumped

func _double_jump():
	print("double jump")
	motion.y = -double_jump
	_has_double_jumped = true

func _update_vertical_movement(delta: float):
	if _user_wants_to_jump and _can_jump():
		_jump()
	elif _user_wants_to_jump and _can_wall_jump():
		_wall_jump()
	elif _user_wants_to_jump and _can_double_jump():
		_double_jump()
#
	if Input.is_action_just_released("ui_up") and motion.y < -jump / 2 and not is_on_floor():
		motion.y = -jump / 2

	if _is_on_wall and motion.y >= 0.0 and (is_on_wall_timer > 0.0 or _forcing_wall_slide):
		motion.y += wall_slide_inc
		motion.y = min(motion.y, wall_slide_max)
	else:
		motion.y += gravity_inc
		motion.y = min(motion.y, gravity_max)

func _physics_process(delta: float):
#	var t = OS.get_system_time_msecs()
	
	_update_is_on_floor(delta)
	_update_is_on_wall(delta)
	_update_user_input(delta)
	_update_lateral_movement(delta)
	_update_vertical_movement(delta)

	motion = move_and_slide(motion, up)
	
#	print(OS.get_system_time_msecs() - t)
