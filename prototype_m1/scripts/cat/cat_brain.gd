class_name CatBrain
extends RefCounted
## Pure decision logic for the cat (no scene access) so it can be unit-tested.
## The CatController feeds a Perception each tick and acts on the returned state + target.

enum State { VIGIL, PATROL, INVESTIGATE, STALK, CHASE, SEARCH }

class Perception:
	var rhyme_singing := false          ## Children are singing: the cat sits facing the altar.
	var sees_rat := false               ## Rat inside view cone with line of sight.
	var rat_exposure := 0.0             ## 0..1 light on the rat (from ExposureSampler).
	var rat_hidden := false             ## Rat is inside a hide spot and still.
	var rat_pos := Vector3.ZERO
	var rat_in_sanctuary := false       ## Rat is inside a lit incense zone.
	var heard_strength := 0.0           ## Strongest noise this tick, 0..1.
	var heard_pos := Vector3.ZERO
	var dist_to_rat := INF
	var reached_target := false

const AWARE_RISE := 1.6        ## awareness/sec at full exposure in view
const AWARE_DECAY := 0.25
const STALK_AT := 0.35
const CHASE_AT := 0.8
const HEAR_INVESTIGATE := 0.15
const SEARCH_TIME := 9.0
const INVESTIGATE_TIME := 12.0
const MAX_CHASE_TIME := 22.0   ## Director-style mercy: give up a long chase.

var state: State = State.PATROL
var awareness := 0.0           ## 0..1 how sure the cat is the rat is there
var target := Vector3.ZERO
var last_known := Vector3.ZERO
var state_time := 0.0
var _patrol_points: Array[Vector3] = []
var _patrol_i := 0

func set_patrol(points: Array[Vector3]) -> void:
	_patrol_points = points
	if not points.is_empty():
		target = points[0]

func tick(dt: float, p: Perception) -> State:
	state_time += dt
	# --- awareness from sight ---
	var visible := p.sees_rat and not p.rat_hidden
	if visible:
		# Even in darkness a close rat is noticed: floor exposure by proximity.
		var near := clampf(1.0 - p.dist_to_rat / 12.0, 0.0, 1.0)
		var e := maxf(p.rat_exposure, near * 0.6)
		awareness = minf(1.0, awareness + AWARE_RISE * e * dt)
		last_known = p.rat_pos
	else:
		awareness = maxf(0.0, awareness - AWARE_DECAY * dt)

	# --- the rhyme overrides everything except an active chase ---
	if p.rhyme_singing and state != State.CHASE:
		_go(State.VIGIL)
		return state

	match state:
		State.VIGIL:
			if not p.rhyme_singing:
				_go(State.PATROL)
				target = _next_patrol()
		State.PATROL:
			if awareness >= STALK_AT:
				_go(State.STALK)
			elif p.heard_strength >= HEAR_INVESTIGATE:
				_investigate(p.heard_pos)
			elif p.reached_target:
				target = _next_patrol()
		State.INVESTIGATE:
			if awareness >= STALK_AT:
				_go(State.STALK)
			elif p.heard_strength >= HEAR_INVESTIGATE:
				target = p.heard_pos
			elif p.reached_target or state_time > INVESTIGATE_TIME:
				_go(State.SEARCH)
		State.STALK:
			target = last_known
			if awareness >= CHASE_AT:
				_go(State.CHASE)
			elif awareness <= 0.05:
				_go(State.SEARCH)
		State.CHASE:
			if visible:
				target = p.rat_pos
			else:
				target = last_known
			if p.rat_in_sanctuary or state_time > MAX_CHASE_TIME:
				awareness = 0.3
				_go(State.SEARCH)
			elif not visible and p.reached_target:
				_go(State.SEARCH)
		State.SEARCH:
			if awareness >= CHASE_AT:
				_go(State.CHASE)
			elif p.heard_strength >= HEAR_INVESTIGATE:
				_investigate(p.heard_pos)
			elif state_time > SEARCH_TIME:
				_go(State.PATROL)
				target = _next_patrol()
			elif p.reached_target:
				# Sniff around the last known spot.
				target = last_known + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
	return state

func _investigate(pos: Vector3) -> void:
	_go(State.INVESTIGATE)
	target = pos

func _go(s: State) -> void:
	if s != state:
		state = s
		state_time = 0.0

func _next_patrol() -> Vector3:
	if _patrol_points.is_empty():
		return target
	_patrol_i = (_patrol_i + 1) % _patrol_points.size()
	return _patrol_points[_patrol_i]

## Movement speed (units/sec) per state; rat runs at ~9.
static func speed_for(s: State) -> float:
	match s:
		State.VIGIL: return 0.0
		State.PATROL: return 3.2
		State.INVESTIGATE: return 4.5
		State.STALK: return 2.0
		State.CHASE: return 10.5
		State.SEARCH: return 3.0
	return 3.0
