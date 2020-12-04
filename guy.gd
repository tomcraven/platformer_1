extends KinematicBody2D

onready var left_ray := $left_ray
onready var right_ray := $right_ray

var motion := Vector2.ZERO
var up := Vector2(0, -1)

var jumping_speed_inc_factor := 0.5

var speed_inc := 40.0
var max_speed := 150.0

var gravity_inc := 20.0
var gravity_max := 500.0

var wall_slide_inc := 10.0
var wall_slide_max := 20.0

var jump := 350.0
var wall_jump := 300.0
var double_jump := 300.0

var was_on_wall := false
var has_wall_jumped := false
var has_double_jumped := false

var single_frame_time := 1.0 / 60.0

var trying_to_jump_max_time := 7.0 * single_frame_time
var trying_to_jump_timeout := 0.0

var was_on_floor_max_time := 4.0 * single_frame_time
var was_on_floor_timeout := 0.0

var was_on_wall_max_time := 7.0 * single_frame_time
var was_on_wall_timeout := 0.0

var _is_on_floor := false
var _is_on_wall := false
var _user_wants_to_jump := false
var _has_jumped := false

var collision_normal := Vector2.ZERO

func _update_is_on_floor(delta: float):
	was_on_floor_timeout -= delta
	if is_on_floor():
		was_on_floor_timeout = was_on_floor_max_time
	_is_on_floor = was_on_floor_timeout >= 0.0

func _update_is_on_wall(delta: float):
	was_on_wall_timeout -= delta
	if is_on_wall():
		was_on_wall_timeout = was_on_wall_max_time
		
		if right_ray.is_colliding():
			collision_normal = right_ray.get_collision_normal()
		elif left_ray.is_colliding():
			collision_normal = left_ray.get_collision_normal()

	_is_on_wall = was_on_wall_timeout >= 0.0

func _update_user_input(delta: float):
	trying_to_jump_timeout -= delta
	if Input.is_action_just_pressed("ui_up"):
		trying_to_jump_timeout = trying_to_jump_max_time
	elif Input.is_action_just_released("ui_up"):
		_has_jumped = false
	_user_wants_to_jump = trying_to_jump_timeout >= 0.0

func _update_lateral_movement(delta: float):
	var speed_inc_factor := 1.0 if _is_on_floor else jumping_speed_inc_factor
	var _speed_inc = speed_inc * speed_inc_factor
	
	if Input.is_action_pressed("ui_right"):
		motion.x += _speed_inc
	elif Input.is_action_pressed("ui_left"):
		motion.x -= _speed_inc
	else:
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

func _update_vertical_movement(delta: float):
	if _user_wants_to_jump and _can_jump():
		_jump()

	if _is_on_wall and motion.y > 0.0:
		motion.y += wall_slide_inc
		motion.y = min(motion.y, wall_slide_max)
	else:
		motion.y += gravity_inc
		motion.y = min(motion.y, gravity_max)

func _physics_process(delta: float):
	_update_is_on_floor(delta)
	_update_is_on_wall(delta)
	_update_user_input(delta)
	_update_lateral_movement(delta)
	_update_vertical_movement(delta)
	
	motion = move_and_slide(motion, up)
	
	
#	trying_to_jump_timeout -= delta
#	was_on_floor_timeout -= delta
#	was_on_wall_timeout -= delta
#
#	if is_on_floor():
#		was_on_floor_timeout := was_on_floor_max_time
#
#	if is_on_wall():
#		was_on_wall_timeout := was_on_wall_max_time
#
#	if Input.is_action_just_pressed("ui_up") or trying_to_jump_timeout > 0.0:
#		if is_on_floor() or was_on_floor_timeout > 0.0:
#			trying_to_jump_timeout := 0.0
#			motion.y := -jump
##		elif not has_double_jumped and not (is_on_wall() or was_on_wall):
##			motion.y := -double_jump
##			has_double_jumped := true
#		elif (is_on_wall() or was_on_wall_timeout > 0.0) and not has_wall_jumped:
#			motion.y -= wall_jump
#			has_wall_jumped := true
#		elif trying_to_jump_timeout <= 0.0:
#			trying_to_jump_timeout := trying_to_jump_max_time
##
#	if not is_on_wall() and not was_on_wall:
#		has_wall_jumped := false
#
##	if is_on_floor() or is_on_wall():
##		has_double_jumped := false
#
#	if Input.is_action_pressed("ui_right"):
#		was_on_wall := false
#		motion.x += speed_inc * speed_inc_factor
#	elif Input.is_action_pressed("ui_left"):
#		was_on_wall := false
#		motion.x -= speed_inc * speed_inc_factor
#	else:
#		if motion.x < 0.0:
#			motion.x += speed_inc * speed_inc_factor
#			if motion.x > 0.0: motion.x := 0.0
#		elif motion.x > 0.0:
#			motion.x -= speed_inc * speed_inc_factor
#			if motion.x < 0.0: motion.x := 0.0
#
#	motion.x := clamp(motion.x, -max_speed, max_speed)
#
#	if is_on_wall() or was_on_wall or was_on_wall_timeout > 0.0:
#		was_on_wall := true
#
#		if motion.y > 0.0:
#			motion.y += wall_slide_inc
#			if motion.y > 0.0:
#				motion.y := clamp(motion.y, 0.0, wall_slide_max)
#	elif not (is_on_wall() or was_on_wall):
#		motion.y += gravity_inc
#		if motion.y > 0.0:
#			motion.y := clamp(motion.y, 0.0, gravity_max)
#
#	motion := move_and_slide(motion, up)
