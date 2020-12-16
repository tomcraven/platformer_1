extends KinematicBody2D

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
	
	func _init(inc: float, minmax: float).("lateral_movement_inc"):
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
	var label
	var effects
	
	func _init(label, effects = []):
		if label == null:
			label = "unknown_state"
		self.label = label
		self.effects = effects

	func process_effects(guy: KinematicBody2D):
		for effect in effects:
			effect.process(guy)
	
	func process_state_changes(guy: KinematicBody2D) -> StateChange:
		return StateChange.none()
	
	func label():
		return label

class StateCollection extends State:
	var states = []
	
	func _init(label: String, states = []).(label):
		self.states = states

	func process_effects(guy: KinematicBody2D):
		for state in states:
			state.process_effects(guy)
	
	func process_state_changes(guy: KinematicBody2D) -> StateChange:
		for state in states:
			var state_change = state.process_state_changes(guy)
			if state_change.type != StateChange.None:
				return state_change
		return .process_state_changes(guy)

	func label() -> String:
		var default_label = .label()
		if default_label != null:
			return default_label

		var labels: PoolStringArray = []
		for state in states:
			labels.append(state.label())
		return "state_collection(%s)" % labels.join(", ")

class Null extends State:
	func _init().("null"): pass

class KeyPressHandler extends State:
	class Pair:
		enum KeyStateType {
			Pressed,
			NotPressed,
		}
		
		class HandlerBase:
			func _init(key, type, callback):
				self.key = key
				self.type = type
				self.callback = callback

			var key: String
			var type
			var callback

			func check():
				match type:
					KeyStateType.Pressed:
						return Input.is_action_pressed(key)
					KeyStateType.NotPressed:
						return not Input.is_action_pressed(key)

		class Replace extends HandlerBase:
			static func pressed(key, callback):
				return KeyPressHandler.Pair.Replace.new(
					key,
					KeyPressHandler.Pair.KeyStateType.Pressed,
					callback
				)

			static func notPressed(key, callback):
				return KeyPressHandler.Pair.Replace.new(
					key,
					KeyPressHandler.Pair.KeyStateType.NotPressed,
					callback
				)
				
			func _init(key, type, callback).(key, type, callback): pass

			func state_change(context: Context):
				return StateChange.replace(callback.call_func(context))

		class None extends HandlerBase:
			static func pressed(key, callback):
				return KeyPressHandler.Pair.None.new(
					key,
					KeyPressHandler.Pair.KeyStateType.Pressed,
					callback
				)

			static func notPressed(key, callback):
				return KeyPressHandler.Pair.None.new(
					key,
					KeyPressHandler.Pair.KeyStateType.NotPressed,
					callback
				)

			func _init(key, type, callback).(key, type, callback): pass

			func state_change(context: Context):
				callback.call_func(context)
				return StateChange.none()

	var handlers

	func _init(handlers).("key_press_handler", []):
		self.handlers = handlers

	func process_state_changes(guy: KinematicBody2D) -> StateChange:
		for handler in handlers:
			if handler.check():
				return handler.state_change(guy.context)
		return .process_state_changes(guy)

class Idle extends State:
	static func create(context: Context):
		var idle = context.idle.create(context)
		return StateCollection.new("idle/" + idle.label(), [
			Idle.new(),
			KeyPressHandler.new([
				KeyPressHandler.Pair.Replace.pressed("ui_left", funcref(MoveLeft.Ground, "create")),
				KeyPressHandler.Pair.Replace.pressed("ui_right", funcref(MoveRight.Ground, "create")),
			]),
			idle
		])

	class Default extends Idle:
		func label(): "default"
		
		static func create(contex: Context):
			return StateCollection.new("default", [
				KeyPressHandler.new([
					KeyPressHandler.Pair.Replace.pressed("ui_up", funcref(Jump, "create"))
				])
			])

	class AfterJump extends Idle:
		func label(): "after_jump"
		
		static func create(context: Context):
			return StateCollection.new("after_jump", [
				KeyPressHandler.new([
					KeyPressHandler.Pair.Replace.notPressed("ui_up", funcref(Idle, "create")),
				])
			])

	func _init().("idle", [
		Gravity.new(),
		Stop.new(Constants.STOP_INC)
	]): pass

class Falling extends State:
	static func create(context: Context):
		return context.falling.create(context)
	
	class Default extends Falling:
		static func create(context: Context):
			return StateCollection.new("falling", [
				Falling.new(),
				KeyPressHandler.new([
					KeyPressHandler.Pair.Replace.pressed("ui_left", funcref(MoveLeft.Air, "create")),
					KeyPressHandler.Pair.Replace.pressed("ui_right", funcref(MoveRight.Air, "create")),
				])
			])

	class AfterJump extends Falling:
		static func create(context: Context):
			return StateCollection.new("falling/after_jump", [
				AfterJump.new(),
				KeyPressHandler.new([
					KeyPressHandler.Pair.Replace.pressed("ui_left", funcref(MoveLeft.Air, "create")),
					KeyPressHandler.Pair.Replace.pressed("ui_right", funcref(MoveRight.Air, "create")),
					KeyPressHandler.Pair.Replace.notPressed("ui_up", funcref(Falling.Default, "create")),
				])
			])

	func _init(label: String = "falling").(label, [
		Gravity.new(),
		Stop.new(Constants.AIR_STOP_INC)
	]): pass

	func process_state_changes(guy: KinematicBody2D):
		if guy.is_on_floor():
			return StateChange.replace(Idle.create(guy.context))
		return .process_state_changes(guy)

class Coyote extends Falling:
	var frames = 4
	var next: State

	static func create_with(context: Context):
		return Coyote.new(context.falling.create(context))

	func _init(next: State).("coyote"):
		self.next = next

	func process_state_changes(guy: KinematicBody2D):
		frames -= 1
		if frames <= 0:
			return StateChange.replace(next)
		return .process_state_changes(guy)

class Move extends State:
	var direction_key := ""
	var other_direction_key := ""
	func _init(label: String, effects = []).(label, effects): pass

class MoveRight extends Move:
	func _init(label: String, speed_inc: float).("move_right/" + label, [
		Gravity.new(),
		LateralMovementInc.new(speed_inc, Constants.SPEED_MAX)
	]):
		direction_key = "ui_right"
		other_direction_key = "ui_left"

	class Ground extends MoveRight:
		static func create(context: Context):
			return StateCollection.new("move_right/ground", [
				Ground.new(),
				KeyPressHandler.new([
					KeyPressHandler.Pair.Replace.pressed("ui_up", funcref(Jump, "create"))
				])
			])

		func _init().("ground", Constants.SPEED_INC): pass
		
		func process_state_changes(guy: KinematicBody2D):
			if not Input.is_action_pressed(direction_key) and Input.is_action_pressed(other_direction_key):
				return StateChange.replace(MoveLeft.Ground.create(guy.context))
			if not Input.is_action_pressed(direction_key):
				return StateChange.replace(Idle.create(guy.context))
			return .process_state_changes(guy)

	class Air extends MoveRight:
		static func create(context: Context): return Air.new()
		func _init().("air", Constants.AIR_SPEED_INC): pass
		
		func process_state_changes(guy: KinematicBody2D):
			if guy.is_on_floor():
				return StateChange.replace(Ground.create(guy.context))
			if not Input.is_action_pressed(direction_key) and Input.is_action_pressed(other_direction_key):
				return StateChange.replace(MoveLeft.Air.create(guy.context))
			if not Input.is_action_pressed(direction_key):
				return StateChange.replace(Falling.create(guy.context))
			return .process_state_changes(guy)

class MoveLeft extends Move:
	func _init(label: String, speed_inc: float).("move_left/" + label, [
		Gravity.new(),
		LateralMovementInc.new(speed_inc, Constants.SPEED_MAX)
	]):
		direction_key = "ui_left"
		other_direction_key = "ui_right"

	class Ground extends MoveLeft:
		static func create(context: Context):
			return StateCollection.new("move_left/ground", [
				Ground.new(),
				KeyPressHandler.new([
					KeyPressHandler.Pair.Replace.pressed("ui_up", funcref(Jump, "create"))
				])
			])

		func _init().("ground", -Constants.SPEED_INC): pass

		func process_state_changes(guy: KinematicBody2D):
			if not Input.is_action_pressed(direction_key) and Input.is_action_pressed(other_direction_key):
				return StateChange.replace(MoveRight.Ground.create(guy.context))
			if not Input.is_action_pressed(direction_key):
				return StateChange.replace(Idle.create(guy.context))
			return .process_state_changes(guy)

	class Air extends MoveLeft:
		static func create(context: Context): return Air.new()
		func _init().("air", -Constants.AIR_SPEED_INC): pass
		
		func process_state_changes(guy: KinematicBody2D):
			if guy.is_on_floor():
				return StateChange.replace(Ground.create(guy.context))
			if not Input.is_action_pressed(direction_key) and Input.is_action_pressed(other_direction_key):
				return StateChange.replace(MoveRight.Air.create(guy.context))
			if not Input.is_action_pressed(direction_key):
				return StateChange.replace(Falling.create(guy.context))
			return .process_state_changes(guy)

class Jump extends State:
	static func create(context: Context):
		return Jump.new()

	func _init().("jump", [
		VerticalMovementSet.new(-Constants.JUMP)
	]): pass

	func process_state_changes(guy: KinematicBody2D):
		guy.context.idle = Idle.AfterJump
		guy.context.falling = Falling.AfterJump
		return StateChange.replace(Falling.create(guy.context))

class Context:
	var idle = Idle.Default
	var falling = Falling.Default

var motion: Vector2
var state = Null.new()
var context = Context.new()
var key_press_handler = KeyPressHandler.new([
	KeyPressHandler.Pair.None.notPressed("ui_up", funcref(self, "on_ui_up_not_pressed"))
])

func _ready():
	_replace_state(Idle.create(context))

func on_ui_up_not_pressed(context: Context):
	context.idle = Idle.Default
	context.falling = Falling.Default

func _physics_process(delta: float):
#	var t = OS.get_system_time_msecs()

	key_press_handler.process_state_changes(self)

	var state_change = state.process_state_changes(self)
	assert(state_change is StateChange)
	match state_change.type:
		StateChange.None: pass
		StateChange.Replace: _replace_state(state_change.datum)

	state.process_effects(self)
	motion = move_and_slide(motion, Vector2.UP)

#	print(OS.get_system_time_msecs() - t)

	var text = ""
	text += "%s\n" % state.label()
	text += str(motion)
	$Label.set_text(text)

func _replace_state(new_state):
	print("change state from %s to %s" % [state.label(), new_state.label()])
#	state.on_exit()
	state = new_state
#	state.on_enter()
