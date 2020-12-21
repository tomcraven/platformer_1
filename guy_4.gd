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
		guy.motion.y = clamp(guy.motion.y, -minmax, minmax)

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

class FuncRefExt:
	var inner: FuncRef
	var data

	func _init(instance, func_name: String, data = null):
		self.inner = funcref(instance, func_name)
		self.data = data

	func call_func(other):
		if (data != null):
			return inner.call_funcv([other] + data)
		else:
			return inner.call_func(other)

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

class State:
	enum Type {
		Idle,
		Jump,
		Falling,
		PreLandJump,
		MoveLeft,
		MoveRight,
		MoveLeftAir,
		MoveRightAir,
		Coyote,
		MoveLeftCoyote,
		MoveRightCoyote,
	}

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
	func on_enter(guy: KinematicBody2D): return StateChange.none()
	func on_exit(): pass

class Null extends State:
	func _init().("null"): pass

class Reactor:
	static func jump(guy: KinematicBody2D):
		if Input.is_action_just_pressed("ui_up"):
			return StateChange.replace(State.Type.Jump)
		return StateChange.none()
		
	static func on_floor(guy: KinematicBody2D, next_state):
		if guy.is_on_floor():
			return StateChange.replace(next_state)
		return StateChange.none()
	
	static func coyote(guy: KinematicBody2D):
		if not guy.is_on_floor():
			return StateChange.replace(State.Type.Coyote)
		return StateChange.none()

	static func exit_coyote(guy: KinematicBody2D, next_state):
		if not guy.state_by_type[State.Type.Coyote].is_coyote():
			return StateChange.replace(next_state)
		return StateChange.none()

class Idle extends State:
	static func move_reactor(guy: KinematicBody2D):
		if Input.is_action_just_pressed("ui_left"):
			return StateChange.replace(State.Type.MoveLeft)
		if Input.is_action_just_pressed("ui_right"):
			return StateChange.replace(State.Type.MoveRight)
		return StateChange.none()

	func _init().("idle", [
			Gravity.new(),
			Stop.new(Constants.SPEED_INC)
		],[
			funcref(Reactor, "jump"),
			funcref(Idle, "move_reactor"),
			funcref(Reactor, "coyote")
		]): pass

class Jump extends State:
	func _init().("jump", [
		VerticalMovementSet.new(-Constants.JUMP)
	], []): pass
	
	func process_state_changes(guy: KinematicBody2D):
		return StateChange.replace(State.Type.Falling)

class Falling extends State:
	static func pre_land_reactor(guy: KinematicBody2D):
		if Input.is_action_just_pressed("ui_up"):
			return StateChange.replace(State.Type.PreLandJump)
		return StateChange.none()

	static func on_floor(guy: KinematicBody2D):
		if guy.is_on_floor():
			if Input.is_action_pressed("ui_left"):
				return StateChange.replace(State.Type.MoveLeft)
			elif Input.is_action_pressed("ui_right"):
				return StateChange.replace(State.Type.MoveRight)
		return StateChange.none()

	static func move_reactor(guy: KinematicBody2D):
		if Input.is_action_pressed("ui_left"):
			return StateChange.replace(State.Type.MoveLeftAir)
		if Input.is_action_pressed("ui_right"):
			return StateChange.replace(State.Type.MoveRightAir)
		return StateChange.none()

	func _init().("falling", [
		Gravity.new(),
		Stop.new(Constants.AIR_SPEED_INC)
	], [
		funcref(Falling, "pre_land_reactor"),
		funcref(Falling, "on_floor"),
		funcref(Falling, "move_reactor"),
		FuncRefExt.new(Reactor, "on_floor", [State.Type.Idle])
	]): pass

	class Coyote extends State:
		var frames = 0

		static func move_reactor(guy: KinematicBody2D):
			if Input.is_action_pressed("ui_left"):
				return StateChange.replace(State.Type.MoveLeftCoyote)
			if Input.is_action_pressed("ui_right"):
				return StateChange.replace(State.Type.MoveRightCoyote)
			return StateChange.none()

		func _init().("coyote", [
			Gravity.new(),
			Stop.new(Constants.AIR_SPEED_INC)
		], [
			funcref(Falling, "on_floor"),
			funcref(Coyote, "move_reactor"),
			FuncRefExt.new(Reactor, "on_floor", [State.Type.Idle]),
			funcref(Reactor, "jump"),
			FuncRefExt.new(Reactor, "exit_coyote", [State.Type.Falling]),
		]): pass

		func on_enter(guy: KinematicBody2D):
			frames = 0
			return Coyote.move_reactor(guy)
		
		func global_update():
			frames += 1

		func is_coyote():
			return frames <= Constants.COYOTE_FRAMES

class PreLandJump extends State:
	var frames = 0

	func _init().("pre_land_jump", [
		Gravity.new()
	], [
		FuncRefExt.new(Reactor, "on_floor", [State.Type.Jump])
	]): pass
	
	func on_enter(guy: KinematicBody2D):
		frames = 0
		return .on_enter(guy)

	func process_state_changes(guy: KinematicBody2D):
		frames += 1
		if frames > Constants.PRE_LAND_JUMP_FRAMES:
			return StateChange.replace(State.Type.Falling)
		return .process_state_changes(guy)

class MoveLeft:
	static func move_reactor(guy: KinematicBody2D, opposite, key_release):
		if not Input.is_action_pressed("ui_left") and Input.is_action_pressed("ui_right"):
			return StateChange.replace(opposite)
		if not Input.is_action_pressed("ui_left"):
			return StateChange.replace(key_release)
		return StateChange.none()

	class Ground extends State:
		func _init().("move_left", [
				Gravity.new(),
				LateralMovementInc.new(-Constants.SPEED_INC),
				LateralMovementClamp.new(Constants.SPEED_MAX),
			],[
				funcref(Reactor, "coyote"),
				funcref(Reactor, "jump"),
				FuncRefExt.new(MoveLeft, "move_reactor", [State.Type.MoveRight, State.Type.Idle])
			]): pass

	class Air extends State:
		func _init().("move_left_air", [
				Gravity.new(),
				LateralMovementInc.new(-Constants.AIR_SPEED_INC),
				LateralMovementClamp.new(Constants.SPEED_MAX),
			],[
				funcref(Falling, "pre_land_reactor"),
				funcref(Falling, "on_floor"),
				FuncRefExt.new(MoveLeft, "move_reactor", [State.Type.MoveRightAir, State.Type.Falling])
			]): pass

	class Coyote extends State:
		func _init().("move_left_coyote", [
				Gravity.new(),
				LateralMovementInc.new(-Constants.AIR_SPEED_INC),
				LateralMovementClamp.new(Constants.SPEED_MAX),
			],[
				funcref(Falling, "on_floor"),
				FuncRefExt.new(MoveLeft, "move_reactor", [State.Type.MoveRightCoyote, State.Type.Coyote]),
				funcref(Reactor, "jump"),
				FuncRefExt.new(Reactor, "exit_coyote", [State.Type.MoveLeftAir]),
			]): pass

class MoveRight:
	static func move_reactor(guy: KinematicBody2D, opposite, key_release):
		if not Input.is_action_pressed("ui_right") and Input.is_action_pressed("ui_left"):
			return StateChange.replace(opposite)
		if not Input.is_action_pressed("ui_right"):
			return StateChange.replace(key_release)
		return StateChange.none()

	class Ground extends State:
		func _init().("move_right", [
				Gravity.new(),
				LateralMovementInc.new(Constants.SPEED_INC),
				LateralMovementClamp.new(Constants.SPEED_MAX),
			],[
				funcref(Reactor, "coyote"),
				funcref(Reactor, "jump"),
				FuncRefExt.new(MoveRight, "move_reactor", [State.Type.MoveLeft, State.Type.Idle])
			]): pass

	class Air extends State:
		func _init().("move_right_air", [
				Gravity.new(),
				LateralMovementInc.new(Constants.AIR_SPEED_INC),
				LateralMovementClamp.new(Constants.SPEED_MAX),
			],[
				funcref(Falling, "pre_land_reactor"),
				funcref(Falling, "on_floor"),
				FuncRefExt.new(MoveRight, "move_reactor", [State.Type.MoveLeftAir, State.Type.Falling])
			]): pass

	class Coyote extends State:
		func _init().("move_right_coyote", [
				Gravity.new(),
				LateralMovementInc.new(Constants.AIR_SPEED_INC),
				LateralMovementClamp.new(Constants.SPEED_MAX),
			],[
				funcref(Falling, "on_floor"),
				FuncRefExt.new(MoveLeft, "move_reactor", [State.Type.MoveLeftCoyote, State.Type.Coyote]),
				funcref(Reactor, "jump"),
				FuncRefExt.new(Reactor, "exit_coyote", [State.Type.MoveRightAir]),
			]): pass

var motion := Vector2.ZERO
var state: State = Null.new()

var state_by_type: Dictionary = {
	State.Type.Idle: Idle.new(),
	State.Type.Jump: Jump.new(),
	State.Type.Falling: Falling.new(),
	State.Type.PreLandJump: PreLandJump.new(),
	State.Type.MoveLeft: MoveLeft.Ground.new(),
	State.Type.MoveRight: MoveRight.Ground.new(),
	State.Type.MoveLeftAir: MoveLeft.Air.new(),
	State.Type.MoveRightAir: MoveRight.Air.new(),
	State.Type.Coyote: Falling.Coyote.new(),
	State.Type.MoveLeftCoyote: MoveLeft.Coyote.new(),
	State.Type.MoveRightCoyote: MoveRight.Coyote.new()
}

func _ready():
	_replace_state(State.Type.Idle)

func _physics_process(delta):
	for state in state_by_type.values():
		state.global_update()

	var state_change = state.process_state_changes(self)
	_handle_state_change(state_change)
	state.process_effects(self)
	
	motion = move_and_slide(motion, Vector2.UP)

	var text = ""
	text += "coyote = %s\n" % str(state_by_type[State.Type.Coyote].is_coyote())
	text += "%s\n" % state.label()
	text += str(motion)
	$Label.set_text(text)

func _handle_state_change(state_change):
	assert(state_change is StateChange)
	match state_change.type:
		StateChange.None: pass
		StateChange.Replace: _replace_state(state_change.datum)

func _replace_state(new_state_type):
	var new_state = state_by_type[new_state_type]
	
	print("change state from %s to %s" % [state.label(), new_state.label()])
	state.on_exit()
	state = new_state
	_handle_state_change(state.on_enter(self))
