extends KinematicBody2D

#func _apply_and_clamp_gravity():
#	motion.y += GRAVITY_INC
#	motion.y = min(motion.y, GRAVITY_MAX)
#
#func _apply_and_clamp_lateral_movement(inc: float, minmax: float):
#	motion.x += inc
#	motion.x = clamp(motion.x, -minmax, minmax)

class StateChange:
	enum {
		None,
		Replace,
		Push,
		Pop,
		PopReplace
	}
	var type
	var datum

	func _init(type, datum = null):
		self.type = type
		self.datum = datum

	static func none():
		return StateChange.new(None)

	static func replace(datum):
		return StateChange.new(Replace, datum)
	
	static func push(datum):
		return StateChange.new(Push, datum)
	
	static func pop():
		return StateChange.new(Pop)
	
	static func popReplace(datum):
		return StateChange.new(PopReplace, datum)

# Effects
class Effect:
	var label = "effect"

	func _init(label: String):
		self.label = label

	func process(guy: KinematicBody2D): pass

class Gravity extends Effect:
	func _init().("gravity"): pass
	
	func process(guy: KinematicBody2D):
		guy.motion.y += Constants.GRAVITY_INC
		guy.motion.y = min(guy.motion.y, Constants.GRAVITY_MAX)

class LateralMovementInc extends Effect:
	var inc: float
	var minmax: float
	
	func _init(inc: float, minmax: float).("lateral_movement"):
		self.inc = inc
		self.minmax = minmax

	func process(guy: KinematicBody2D):
		guy.motion.x += inc
		guy.motion.x = clamp(guy.motion.x, -minmax, minmax)

class VerticalMovementSet extends Effect:
	var val: float
	
	func _init(val: float).("vertical_movement"):
		self.val = val

	func process(guy: KinematicBody2D):
		guy.motion.y = val

class Stop extends Effect:
	var inc: float
	
	func _init(inc: float).("stop"):
		self.inc = inc

	func process(guy: KinematicBody2D):
		if guy.motion.x > 0.0:
			guy.motion.x -= inc
			if guy.motion.x < 0.0: guy.motion.x = 0.0
		elif guy.motion.x < 0.0:
			guy.motion.x += inc
			if guy.motion.x > 0.0: guy.motion.x = 0.0

class State:
	var label = "state"
	var effects
	func _init(label: String, effects = []):
		self.label = label
		self.effects = effects

	func process_effects(guy: KinematicBody2D):
		for effect in effects:
			effect.process(guy)
	
	func process_state_changes(guy: KinematicBody2D):
		return StateChange.none()
		
	func on_enter(): pass
	func on_exit(): pass

class Null extends State:
	func _init().("null"): pass

class Idle extends State:
	func _init().("idle", [
		Gravity.new(),
		Stop.new(Constants.SPEED_INC)
	]): pass

	func process_state_changes(guy: KinematicBody2D):
		if not guy.is_on_floor():
			return StateChange.replace(Falling.new())
		if Input.is_action_pressed("ui_right"):
			return StateChange.replace(MovingRightOnGround.new())
		elif Input.is_action_pressed("ui_left"):
			return StateChange.replace(MovingLeftOnGround.new())
		elif Input.is_action_just_pressed("ui_up"):
			return StateChange.replace(Jump.new())
		return .process_state_changes(guy)

class Falling extends State:
	var has_attempted_pre_land_jump = true

	func _init(label: String = "falling", effects = []).(label, [
		Gravity.new()
	]): pass

	func process_state_changes(guy: KinematicBody2D):
		if Input.is_action_just_released("ui_up"):
			has_attempted_pre_land_jump = false
		if Input.is_action_pressed("ui_up") and not has_attempted_pre_land_jump:
			has_attempted_pre_land_jump = true
			return StateChange.push(PreLandJump.new())
		if guy.is_on_floor():
			return StateChange.replace(Idle.new())
		if Input.is_action_pressed("ui_right"):
			return StateChange.replace(MovingRightInAir.new(has_attempted_pre_land_jump))
		if Input.is_action_pressed("ui_left"):
			return StateChange.replace(MovingLeftInAir.new(has_attempted_pre_land_jump))
		return .process_state_changes(guy)

class Coyote extends State:
	var frames = 4

	func _init().("coyote", [
		Gravity.new()
	]): pass

	func process_state_changes(guy: KinematicBody2D):
		frames -= 1
		if frames <= 0:
			return StateChange.replace(Falling.new())
		if Input.is_action_just_pressed("ui_up"):
			return StateChange.replace(Jump.new())
		if guy.is_on_floor():
			return StateChange.replace(Idle.new())
		return .process_state_changes(guy)

class PreLandJump extends Falling:
	const FRAMES = 10
	var current_frame = FRAMES

	func _init().("pre_land_jump"): pass

	func process_state_changes(guy: KinematicBody2D):
		if guy.is_on_floor():
			return StateChange.popReplace(Jump.new())
		else:
			current_frame -= 1
			if current_frame <= 0:
				return StateChange.pop()
		return StateChange.none()

class MovingLaterally extends State:
	var direction_key := ""
	var other_direction_key := ""

	func _init(label: String, effects = []).(label, effects): pass

	func process_state_changes(guy: KinematicBody2D):
		if not Input.is_action_pressed(direction_key) and Input.is_action_pressed(other_direction_key):
			return StateChange.replace(new_opposite_direction_state())
		if not Input.is_action_pressed(direction_key):
			if guy.is_on_floor():
				return StateChange.replace(Idle.new())
			else:
				return StateChange.replace(new_falling_state())
		return .process_state_changes(guy)
	
	func new_opposite_direction_state(): assert(false)
	
	func new_falling_state():
		return Falling.new()

class MovingLaterallyOnGround extends MovingLaterally:
	func _init(label: String, effects = []).(label, effects): pass

	func process_state_changes(guy: KinematicBody2D):
		if not guy.is_on_floor():
			return StateChange.replace(Coyote.new())
		if Input.is_action_just_pressed("ui_up"):
			return StateChange.replace(Jump.new())
		return .process_state_changes(guy)

class MovingRightOnGround extends MovingLaterallyOnGround:
	func _init().("moving_right_on_ground", [
		Gravity.new(),
		LateralMovementInc.new(Constants.SPEED_INC, Constants.SPEED_MAX)
	]):
		direction_key = "ui_right"
		other_direction_key = "ui_left"

	func new_opposite_direction_state():
		return MovingLeftOnGround.new()

class MovingLeftOnGround extends MovingLaterallyOnGround:
	func _init().("moving_left_on_ground", [
		Gravity.new(),
		LateralMovementInc.new(-Constants.SPEED_INC, Constants.SPEED_MAX)
	]):
		direction_key = "ui_left"
		other_direction_key = "ui_right"
	
	func new_opposite_direction_state():
		return MovingRightOnGround.new()

class MovingInAir extends MovingLaterally:
	var has_attempted_pre_land_jump = true
	
	func _init(label: String, effects = []).(label, effects): pass

	func process_state_changes(guy: KinematicBody2D):
		if Input.is_action_just_released("ui_up"):
			has_attempted_pre_land_jump = false
		if Input.is_action_pressed("ui_up") and not has_attempted_pre_land_jump:
			has_attempted_pre_land_jump = true
			return StateChange.push(PreLandJump.new())
		if guy.is_on_floor():
			return StateChange.replace(Idle.new())
		return .process_state_changes(guy)

	func new_falling_state():
		var falling = Falling.new()
		falling.has_attempted_pre_land_jump = has_attempted_pre_land_jump
		return falling

class MovingRightInAir extends MovingInAir:
	func _init(has_attempted_pre_land_jump: bool).("moving_right_in_air", [
		Gravity.new(),
		LateralMovementInc.new(Constants.SPEED_INC / 2, Constants.SPEED_MAX)
	]):
		direction_key = "ui_right"
		other_direction_key = "ui_left"
		self.has_attempted_pre_land_jump = has_attempted_pre_land_jump
	
	func new_opposite_direction_state():
		return MovingLeftInAir.new(has_attempted_pre_land_jump)

class MovingLeftInAir extends MovingInAir:
	func _init(has_attempted_pre_land_jump: bool).("moving_left_in_air", [
		Gravity.new(),
		LateralMovementInc.new(-Constants.SPEED_INC / 2, Constants.SPEED_MAX)
	]):
		direction_key = "ui_left"
		other_direction_key = "ui_right"
		self.has_attempted_pre_land_jump = has_attempted_pre_land_jump

	func new_opposite_direction_state():
		return MovingRightInAir.new(has_attempted_pre_land_jump)

class Jump extends State:
	func _init().("jump", [
		VerticalMovementSet.new(-Constants.JUMP)
	]): pass

	func process_state_changes(guy: KinematicBody2D):
		return StateChange.replace(Falling.new())

# Variables
var motion: Vector2
var state = [Null.new()]

var pmin = 999
var pmax = 0

func _ready():
	state = [Idle.new()]

func _physics_process(delta: float):
#	var t = OS.get_system_time_msecs()

	var state_change = state[0].process_state_changes(self)
	assert(state_change is StateChange)
	match state_change.type:
		StateChange.None: pass
		StateChange.Replace: _replace_state(state_change.datum)
		StateChange.Push: _push_state(state_change.datum)
		StateChange.Pop: _pop_state()
		StateChange.PopReplace:
			_pop_state()
			_replace_state(state_change.datum)

	state[0].process_effects(self)
	motion = move_and_slide(motion, Vector2.UP)
	
#	print(OS.get_system_time_msecs() - t)

	var text = ""
	for s in state:
		text += "%s\n" % s.label
	text += str(motion)
	$Label.set_text(text)

func _replace_state(new_state):
	print("change state from %s to %s" % [state[0].label, new_state.label])
	state[0].on_exit()
	state[0] = new_state
	state[0].on_enter()

func _push_state(new_state):
	print("push state %s" % new_state.label)
	state[0].on_exit()
	state.push_front(new_state)
	state[0].on_enter()

func _pop_state():
	print("pop state %s" % state[0].label)
	state[0].on_exit()
	state.pop_front()
	state[0].on_enter()
