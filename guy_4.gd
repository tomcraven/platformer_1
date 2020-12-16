extends KinematicBody2D

class Effect:
	func instance(): assert(false)
	func process(guy: KinematicBody2D): pass

class LateralMovementInc extends Effect:
	var inc: float
	
	func _init(inc: float):
		self.inc = inc

	func process(guy: KinematicBody2D):
		guy.motion.x += inc

class LateralMovementClamp extends Effect:
	var minmax: float
	
	func _init(minmax: float):
		self.minmax = minmax

	func process(guy: KinematicBody2D):
		guy.motion.x = clamp(guy.motion.x, -minmax, minmax)

class VerticalMovementInc extends Effect:
	var inc: float
	
	func _init(inc: float):
		self.inc = inc

	func process(guy: KinematicBody2D):
		guy.motion.y += inc
		
class VerticalMovementClamp extends Effect:
	var minmax: float
	
	func _init(minmax: float):
		self.minmax = minmax

	func process(guy: KinematicBody2D):
		guy.motion.x = clamp(guy.motion.x, -minmax, minmax)

class VerticalMovementSet extends Effect:
	var val: float
	
	func _init(val: float):
		self.val = val

	func process(guy: KinematicBody2D):
		guy.motion.y = val

class Gravity extends Effect:
	var vertical_inc = VerticalMovementInc.new(Constants.GRAVITY_INC)
	var vertical_clamp = VerticalMovementClamp.new(Constants.GRAVITY_MAX)
	
	func process(guy: KinematicBody2D):
		vertical_inc.process(guy)
		vertical_clamp.process(guy)

class Stop extends Effect:
	var inc: float

	func _init(inc: float):
		self.inc = inc

	func process(guy: KinematicBody2D):
		if guy.motion.x > 0.0:
			guy.motion.x -= inc
			if guy.motion.x < 0.0: guy.motion.x = 0.0
		elif guy.motion.x < 0.0:
			guy.motion.x += inc
			if guy.motion.x > 0.0: guy.motion.x = 0.0

class FuncRefExt extends FuncRef:
	var inner: FuncRef
	var data

	func _init(instance, func_name: String, data):
		self.inner = funcref(instance, func_name)
		self.data = data
		
	func call_func():
		if (data):
			return inner.call_funcv(data)
		else:
			return inner.call_func()

class StateChange:
	enum {
		None,
		Replace
	}
	var type
	var datum

	func _init(type, datum = null):
		self.type = type
		self.datum = datum

	static func none():
		return StateChange.new(None)

	static func replace(datum):
		assert(datum != null)
		return StateChange.new(Replace, datum)

enum StateType {
	Idle,
	Jump,
	Falling,
	PreLandJump,
}

class Reactor:
	func check(): pass

class State:
	var effects = []
	var state_changes = []
	var label = ""
	var can_activate = true

	func _init(label: String = "unknown", effects = [], state_changes = []):
		self.label = label
		self.effects = effects
		self.state_changes = state_changes

	func label():
		return label

	func process_effects(guy: KinematicBody2D):
		for effect in effects:
			effect.process(guy)
	
	func process_state_changes(guy: KinematicBody2D):
		for state_change in state_changes:
			var change = state_change.call_func(guy)
			var change_state = guy.state_by_type[change.type]
			if change.type != StateChange.None && change_state.can_activate():
				return change
		return StateChange.none()

	func can_activate(): return true
	func global_update(): pass
	func on_enter(): pass
	func on_exit(): pass

class Null extends State:
	func _init().("null"): pass

class Idle extends State:
	static func create() -> State:
		return Idle.new()

	static func jump_reactor(guy: KinematicBody2D):
		if Input.is_action_just_pressed("ui_up"):
			return StateChange.replace(guy.StateType.Jump)
		return StateChange.none()

	func _init().("idle", [
			Gravity.new()
		],[
			funcref(Idle, "jump_reactor")
		]): pass

class Jump extends State:
	static func create() -> State:
		return Jump.new()

	static func ping(guy: KinematicBody2D):
		return StateChange.replace(guy.StateType.Falling)

	func _init().("jump", [
		VerticalMovementSet.new(-Constants.JUMP)
	], [
		funcref(Jump, "ping")
	]): pass
	
class Falling extends State:
	static func create() -> State:
		return Falling.new()
	
	static func on_floor_reactor(guy: KinematicBody2D):
		if guy.is_on_floor():
			return StateChange.replace(guy.StateType.Idle)
		return StateChange.none()

	static func pre_land_reactor(guy: KinematicBody2D):
		if Input.is_action_just_pressed("ui_up"):
			return StateChange.replace(guy.StateType.PreLandJump)
		return StateChange.none()

	func _init().("falling", [
		Gravity.new()
	], [
		funcref(Falling, "pre_land_reactor"),
		funcref(Falling, "on_floor_reactor"),
	]): pass

class PreLandJump extends State:
	var frames = 0
	
	static func create() -> State:
		var pre_land_jump = PreLandJump.new()
		pre_land_jump.state_changes.append(
			funcref(pre_land_jump, "ping")
		)
		return pre_land_jump

	static func on_floor_reactor(guy: KinematicBody2D):
		if guy.is_on_floor():
			return StateChange.replace(guy.StateType.Jump)
		return StateChange.none()	

	func _init().("pre_land_jump", [
		Gravity.new()
	], [
		funcref(PreLandJump, "on_floor_reactor"),
	]): pass
	
	func on_enter():
		frames = 0

	func ping(guy: KinematicBody2D):
		frames += 1
		if frames > Constants.PRE_LAND_JUMP_FRAMES:
			return StateChange.replace(guy.StateType.Falling)
		return StateChange.none()

class MoveLeft extends State:
	static func create() -> State:
		return MoveLeft.new()

	static func jump_reactor(guy: KinematicBody2D):
		if Input.is_action_just_pressed("ui_up"):
			return StateChange.replace(guy.StateType.Jump)
		return StateChange.none()

	func _init().("move_left", [
			Gravity.new(),
			LateralMovementInc.new(-Constants.SPEED_INC),
			LateralMovementClamp.new(Constants.SPEED_MAX),
		],[
			funcref(Idle, "jump_reactor")
		]): pass

var motion := Vector2.ZERO
var state: State = Null.new()

var state_by_type: Dictionary = {
	StateType.Idle: Idle.create(),
	StateType.Jump: Jump.create(),
	StateType.Falling: Falling.create(),
	StateType.PreLandJump: PreLandJump.create()
}

func _ready():
	state = state_by_type[StateType.Idle]

func _physics_process(delta):
	for state in state_by_type.values():
		state.global_update()

	var state_change = state.process_state_changes(self)
	assert(state_change is StateChange)
	match state_change.type:
		StateChange.None: pass
		StateChange.Replace: _replace_state(state_change.datum)
	state.process_effects(self)
	
	motion = move_and_slide(motion, Vector2.UP)

func _replace_state(new_state_type):
	var new_state = state_by_type[new_state_type]
	
	print("change state from %s to %s" % [state.label(), new_state.label()])
	state.on_exit()
	state = new_state
	state.on_enter()
