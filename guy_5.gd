extends KinematicBody2D

class_name Guy

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
		Null,
		
		VerticalMovement_Idle,
		VerticalMovement_Fall,
		VerticalMovement_Jump,
		VerticalMovement_PreLandJump,
		VerticalMovement_Coyote,
		VerticalMovement_HangTime,
		
		HorizontalMovement_Idle,
		HorizontalMovement_Left,
		HorizontalMovement_Right,
	}

	var label: String

	func _init(label: String = "unknown"): self.label = label
	func label(): return label
	func process_state_changes(guy: Guy): return StateChange.none()
	func physics_process(delta: float, guy: Guy): pass
	func on_enter(): pass
	func on_exit(): pass

class Null extends State:
	func _init().("null"): pass

class VerticalMovement extends State:
	func _init(label: String = "unknown_vertical_state").(label): pass
	
	class Idle extends VerticalMovement:
		func _init().("idle"): pass
		
		func physics_process(delta: float, guy: Guy):
			guy.motion.y += Constants.GRAVITY_INC
			guy.motion.y = clamp(guy.motion.y, -Constants.GRAVITY_MAX, Constants.GRAVITY_MAX)

		func process_state_changes(guy: Guy):
			if not guy.is_on_floor():
				return StateChange.replace(State.Type.VerticalMovement_Coyote)
			if guy.is_on_floor() and Input.is_action_just_pressed("ui_up"):
				return StateChange.replace(State.Type.VerticalMovement_Jump)
			return StateChange.none()

	class Fall extends VerticalMovement:
		func _init(label: String = "fall").(label): pass
		
		func physics_process(delta: float, guy: Guy):
			guy.motion.y += Constants.GRAVITY_INC
			guy.motion.y = clamp(guy.motion.y, -Constants.GRAVITY_MAX, Constants.GRAVITY_MAX)

		func process_state_changes(guy: Guy):
			# If we end up on the floor then transition to idle
			if guy.is_on_floor():
				return StateChange.replace(State.Type.VerticalMovement_Idle)
			
			# If we aren't on the floor yet and the user is trying to jump, then
			# we may be just about to land and should honor the jump, we let
			# the user buffer up a jump for a few frames in PreLandJump
			if not guy.is_on_floor() and Input.is_action_just_pressed("ui_up"):
				return StateChange.replace(State.Type.VerticalMovement_PreLandJump)
				
			# If we are still moving upwards, and our momentum is below a
			# threshold (Constants.HAND_TIME_VERTICAL_MOTION), and if the user
			# is still holding up, then we transition to HangTime and give a
			# little bit less gravity at the peak of the jump whilst also moving
			# upwards
			if guy.motion.y < 0 and guy.motion.y > -Constants.HAND_TIME_VERTICAL_MOTION and Input.is_action_pressed("ui_up"):
				return StateChange.replace(State.Type.VerticalMovement_HangTime)
			return StateChange.none()

	class PreLandJump extends VerticalMovement.Fall:
		var frames = 0
		
		func _init().("pre_land_jump"): pass

		func on_enter(): frames = 0

		func process_state_changes(guy: Guy):
			# Transition to falling if we have released the jump key, or if the
			# player has been in the PreLandJump state for too long
			if Input.is_action_just_released("ui_up"):
				return StateChange.replace(State.Type.VerticalMovement_Fall)
			frames += 1
			if frames >= Constants.PRE_LAND_JUMP_FRAMES:
				return StateChange.replace(State.Type.VerticalMovement_Fall)
				
			# If we end up on the floor in this state, then:
			# 1. the jump button is still pressed
			# 2. the jump button has been pressed for a small number of frames
			#    (Constants.PRE_LAND_JUMP_FRAMES)
			# If we hit the floor along with the conditions above, then we
			# should transition to jumping
			if guy.is_on_floor():
				return StateChange.replace(State.Type.VerticalMovement_Jump)
			
			return StateChange.none()
	
	class Coyote extends VerticalMovement.Fall:
		var frames = 0
		
		func _init().("coyote"): pass

		func on_enter(): frames = 0
		
		func process_state_changes(guy: Guy):
			# Transition to falling if the player has been in coyote state for
			# too long
			frames += 1
			if frames >= Constants.COYOTE_FRAMES:
				return StateChange.replace(State.Type.VerticalMovement_Fall)
			
			# Our drop was small enough that we've ended up on the floor,
			# we can transition to idle now
			if guy.is_on_floor():
				return StateChange.replace(State.Type.VerticalMovement_Idle)
			
			# 1. not on the floor
			# 2. we've been in coyote state for a small number of frames
			#    (Constants.COYOTE_FRAMES)
			# 3. the user has just requested to jump
			# This is the coyote feature, the user has just left a ledge and
			# have mis-timed their jump, but let them jump anyway
			if Input.is_action_just_pressed("ui_up"):
				return StateChange.replace(State.Type.VerticalMovement_Jump)
			
			return StateChange.none()

	class Jump extends VerticalMovement:
		func _init().("jump"): pass

		func physics_process(delta: float, guy: Guy):
			guy.motion.y = -Constants.JUMP
			
		func process_state_changes(guy: Guy):
			# The jump's physics process has performed its duty, we can
			# immediately transition to falling from here, we'll just be falling
			# upwards temporarily
			# TODO: consider if ascending after a jump should have its own state
			return StateChange.replace(State.Type.VerticalMovement_Fall)

	class HangTime extends VerticalMovement:
		func _init(label: String = "hang_time").(label): pass
		
		func physics_process(delta: float, guy: Guy):
			guy.motion.y += Constants.GRAVITY_INC_HANG_TIME
			guy.motion.y = clamp(guy.motion.y, -Constants.GRAVITY_MAX, Constants.GRAVITY_MAX)

		func process_state_changes(guy: Guy):
			# Hangtime halves the effect of gravity whilst the player is at the
			# apex of their jump, still moving upwards and while they have the
			# jump key pressed
			
			# Transition to falling if any of these are true:
			# 1. we start falling downwards
			# 2. user released the up key
			# 3. the player is back on the floor
			var transition_to_falling = \
				guy.motion.y > 0.0 or \
				Input.is_action_just_released("ui_up") or \
				guy.is_on_floor()

			if transition_to_falling:
				return StateChange.replace(State.Type.VerticalMovement_Fall)
			return StateChange.none()

class HorizontalMovement extends State:
	func _init(label: String = "unknown_horizontal_state").(label): pass
	
	class Idle extends HorizontalMovement:
		func _init().("idle"): pass

		func physics_process(delta: float, guy: Guy):
			if guy.motion.x > 0.0:
				guy.motion.x -= Constants.SPEED_DEC
				if guy.motion.x < 0.0: guy.motion.x = 0.0
			elif guy.motion.x < 0.0:
				guy.motion.x += Constants.SPEED_DEC
				if guy.motion.x > 0.0: guy.motion.x = 0.0

		func process_state_changes(guy: Guy):
			if Input.is_action_just_pressed("ui_left"):
				return StateChange.replace(State.Type.HorizontalMovement_Left)
			elif Input.is_action_just_pressed("ui_right"):
				return StateChange.replace(State.Type.HorizontalMovement_Right)
			return StateChange.none()

	class Left extends HorizontalMovement:
		func _init().("left"): pass
		
		func physics_process(delta: float, guy: Guy):
			# If we're currently moving right, give a little bump to the
			# speed that we stop moving in that direction to make the player
			# feel less slidy
			if guy.motion.x > 0.0:
				if guy.is_on_floor():
					guy.motion.x -= Constants.SPEED_DEC
				else:
					guy.motion.x -= Constants.AIR_SPEED_DEC

			if guy.is_on_floor():
				guy.motion.x -= Constants.SPEED_INC
			else:
				guy.motion.x -= Constants.AIR_SPEED_INC
			guy.motion.x = clamp(guy.motion.x, -Constants.SPEED_MAX, Constants.SPEED_MAX)

		func process_state_changes(guy: Guy):
			if Input.is_action_just_released("ui_left"):
				if Input.is_action_pressed("ui_right"):
					return StateChange.replace(State.Type.HorizontalMovement_Right)
				return StateChange.replace(State.Type.HorizontalMovement_Idle)
			return StateChange.none()
			
	class Right extends HorizontalMovement:
		func _init().("right"): pass

		func physics_process(delta: float, guy: Guy):
			# If we're currently moving left, give a little bump to the
			# speed that we stop moving in that direction to make the player
			# feel less slidy
			if guy.motion.x < 0.0:
				if guy.is_on_floor():
					guy.motion.x += Constants.SPEED_DEC
				else:
					guy.motion.x += Constants.AIR_SPEED_DEC

			if guy.is_on_floor():
				guy.motion.x += Constants.SPEED_INC
			else:
				guy.motion.x += Constants.AIR_SPEED_INC
			guy.motion.x = clamp(guy.motion.x, -Constants.SPEED_MAX, Constants.SPEED_MAX)

		func process_state_changes(guy: Guy):
			if Input.is_action_just_released("ui_right"):
				if Input.is_action_pressed("ui_left"):
					return StateChange.replace(State.Type.HorizontalMovement_Left)
				return StateChange.replace(State.Type.HorizontalMovement_Idle)
			return StateChange.none()

class StateGraph:
	var state = Null.new()
	var label: String
	
	func _init(guy: Guy, initial_state, label: String):
		self.label = label
		replace_state(guy, initial_state)
	
	func label(): return "%s (%s)" % [label, state.label()]
	
	func physics_process(delta: float, guy: Guy):
		var state_change = state.process_state_changes(guy)
		handle_state_change(guy, state_change)
		state.physics_process(delta, guy)

	func handle_state_change(guy: Guy, state_change: StateChange):
		match state_change.type:
			StateChange.None: pass
			StateChange.Replace: replace_state(guy, state_change.datum)

	func replace_state(guy: Guy, new_state_type):
		var new_state = guy.state_by_type[new_state_type]
		
		print("%s change state from %s to %s" % [label, state.label(), new_state.label()])
		state.on_exit()
		state = new_state
		new_state.on_enter()

class VerticalMovementGraph extends StateGraph:
	func _init(guy: Guy).(guy, State.Type.VerticalMovement_Idle, "vertical_movement"): pass

class HorizontalMovementGraph extends StateGraph:
	func _init(guy: Guy).(guy, State.Type.HorizontalMovement_Idle, "horizontal_movement"): pass

var motion := Vector2.ZERO

var state_graphs = []

onready var state_by_type: Dictionary = {
	State.Type.Null: Null.new(),
	
	State.Type.VerticalMovement_Idle: VerticalMovement.Idle.new(),
	State.Type.VerticalMovement_Fall: VerticalMovement.Fall.new(),
	State.Type.VerticalMovement_Jump: VerticalMovement.Jump.new(),
	State.Type.VerticalMovement_PreLandJump: VerticalMovement.PreLandJump.new(),
	State.Type.VerticalMovement_Coyote: VerticalMovement.Coyote.new(),
	State.Type.VerticalMovement_HangTime: VerticalMovement.HangTime.new(),
	
	State.Type.HorizontalMovement_Idle: HorizontalMovement.Idle.new(),
	State.Type.HorizontalMovement_Left: HorizontalMovement.Left.new(),
	State.Type.HorizontalMovement_Right: HorizontalMovement.Right.new(),
}

func _ready():
	state_graphs.append(VerticalMovementGraph.new(self))
	state_graphs.append(HorizontalMovementGraph.new(self))

class Average:
	var points: PoolIntArray
	var num: int
	var capacity: int
	func _init(size: int):
		points.resize(size)
		capacity = size
	func push(val: int):
		points[num % capacity] = val
		num += 1
	func average():
		return float(_sum()) / min(num, capacity)
	func _sum():
		var s = 0
		for i in range(min(num, capacity)): s += points[i]
		return s

var frame_times = Average.new(10)

func _physics_process(delta: float):
	var t = OS.get_ticks_usec()

	for state_graph in state_graphs:
		state_graph.physics_process(delta, self)
	motion = move_and_slide(motion, Vector2.UP)

	var process_time = OS.get_ticks_usec() - t
	frame_times.push(process_time)

	var text = ""
	text += "update time average (%sus)\n" % frame_times.average()
	for state_graph in state_graphs:
		text += "%s\n" % state_graph.label()
	text += "motion %s" % str(motion)
	$Label.set_text(text)
