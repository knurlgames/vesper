extends "res://core/rich_scene.gd"
## Grizelda's, Lull's, Dash's and Rivet's scenes, both ways round, on the rich scenes' framework (core/rich_scene.gd:
## the asking form, phases with their own intros and cameras, Headspace or Connection, a gag and its bell, aftercare
## you take part in). Owner, 2026-11-13: "proceed with Grizelda, Lull, Dash, and Rivet". DESIGN "Richer scenes".
##
##   grizelda switch: polish her boots (circle the stick) / lace them, crossing (the D-pad, in order) / your colour /
##                    present each boot when she calls for it, hold it up while she looks, down when she says. If the
##                    shine wasn't good enough: "Again." (a boot more, and present again)
##   grizelda domme:  your orders, said as her will swings into the green / her answering back: pick the tone her line
##                    wants (firm, amused, gentle: when she goes quiet, she means it) / ask her / let her sit in it
##   lull switch:     blindfolded, from Nim's eyes (dark): she touches; say where, from her voice alone. Sometimes she
##                    touches nothing, and the right answer is to wait / her count / your colour / warm and cold: still
##                    for the ice, lean into the warm cloth
##   lull domme:      where your hand goes next (new places, never rushed) / ice or the warm cloth, by her breathing
##                    (quick: warm her; settled: the ice) / ask her / let her sit in it
##   dash switch:     her drill at the bag / your colour / the play-wrestle: break her holds, then pin her
##   dash domme:      hold her still while she wriggles / tickling, until she says her word: stopping is the skill /
##                    ask her / let her sit in it
##   rivet switch:    the fitting, cuff by cuff (say when it's snug) / try to get out of them: you can't, that's the point
##                    / your colour / does anything pinch? Say where. She lets it out
##   rivet domme:     buckle and check every cuff / she tests them herself: watch her hands for the release signal
##                    (two flicks) / ask her / let her sit in it
## `hint()` says what input is right just now: the probes follow it. OWNER REVIEW: every line here.

const MOUTH := ["mouth", "MOUTH", [["none", "Nothing"], ["ball", "Ball gag"], ["bit", "Bit gag"], ["tape", "Tape"]]]
const FORMS_LATER := {
	"grizelda_switch": [MOUTH, ["how", "HOW", [["firm", "Strict"], ["gentle", "Gentle"]]]],
	"grizelda_domme": [MOUTH, ["how", "HOW", [["firm", "Strict"], ["gentle", "Gentle"]]]],
	"lull_switch": [MOUTH, ["how", "HOW", [["gentle", "Gentle"], ["firm", "Firm"]]]],
	"lull_domme": [MOUTH, ["how", "HOW", [["gentle", "Gentle"], ["firm", "Firm"]]]],
	"dash_switch": [MOUTH, ["how", "HOW", [["gentle", "Playful"], ["firm", "Rough and tumble"]]]],
	"dash_domme": [["word", "HER TICKLE WORD", [["Mercy", "\"Mercy\""], ["Uncle", "\"Uncle\""], ["Pineapple", "\"Pineapple\""]]],
		MOUTH],
	"rivet_switch": [["set", "CUFFS", [["wrists", "Wrists"], ["full", "Wrists and ankles"]]], MOUTH,
		["how", "HOW", [["gentle", "Gentle"], ["firm", "Firm"]]]],
	"rivet_domme": [["set", "CUFFS", [["wrists", "Wrists"], ["full", "Wrists and ankles"]]], MOUTH],
}
const OPENERS_LATER := {
	"grizelda_switch": "Boots tonight. Tell me how hard I'm to be, and what's in your mouth while you work.",
	"grizelda_domme": "You want the throne. Fine. Set the terms, and we'll see if you can keep it.",
	"lull_switch": "I'll take your eyes away. Tell me what else, and how gently.",
	"lull_domme": "Blindfold me. ...And tell me what you'll do with my mouth, so I can look forward to it.",
	"dash_switch": "Drill, then wrestling! Pick how rough. I'm going to win, by the way.",
	"dash_domme": "Okay. Tickling. Pick my word, and I'll say it when I've had enough. Probably. Eventually.",
	"rivet_switch": "I've made you a set. Pick which, and how firm. I'll do the fitting.",
	"rivet_domme": "My cuffs, your hands. Pick the set. Then I test them, and you watch me.",
}
const PHASES_LATER := {
	"grizelda_switch": ["polish", "lace", "colour", "present"],
	"grizelda_domme": ["orders", "answer", "check", "sit"],
	"lull_switch": ["senses", "count", "colour", "warmth"],
	"lull_domme": ["where", "ice", "check", "sit"],
	"dash_switch": ["drill", "colour", "wrestle"],
	"dash_domme": ["hold_her", "tickle", "check", "sit"],
	"rivet_switch": ["fitting", "test", "colour", "adjust"],
	"rivet_domme": ["buckles", "signal", "check", "sit"],
}
const INTROS_LATER := {
	"polish": ["Her boots", ["Kneel at her feet and polish: circle the stick, steadily.", "The needle is your speed: keep it in the green and the shine comes up.",
		"She tells you which boot."]],
	"lace": ["The laces", ["Lace each boot, crossing: the D-pad, in the order shown.", "Up pulls it snug at the top."]],
	"present": ["Present them", ["Wait for her to call a boot. Then hold A to lift it while she looks.",
		"Let go when she says \"Down.\", not before. Her pace, not yours."]],
	"orders": ["The throne", ["She kneels; she won't make it easy. Her will swings like a needle.", "Say each order (A) as it swings into the green."]],
	"answer": ["She answers back", ["She'll talk back. Answer in the tone her line wants: up firm, right amused, down gentle.",
		"When she goes quiet and asks something real, she means it."]],
	"senses": ["Blindfolded", ["You can't see. She touches you somewhere: say where, from her voice.",
		"Cheek: up. Wrist: right. Back: down. Shoulder: left.", "Sometimes she touches nothing. Then wait."]],
	"count": ["Her count", ["She counts, slowly. A on each count.", "Keep the stick still."]],
	"warmth": ["Warm and cold", ["\"Cold.\": the ice. Keep perfectly still: no stick, no buttons.", "\"Warm.\": the cloth. Hold A to lean into it."]],
	"where": ["Where next", ["She's blindfolded. Pick where your hand goes with the D-pad.",
		"Never the same place twice, and never in a hurry: the waiting is half of it."]],
	"ice": ["Ice, or the cloth", ["Ice (left) or the warm cloth (right), a touch at a time.",
		"Listen to her breathe: quick and shallow, she needs warming. Slow and settled, she wants the ice."]],
	"drill": ["Her drill", ["She calls a direction. Hit it on the D-pad before the bar runs out.", "It gets faster."]],
	"wrestle": ["Wrestling", ["She grabs you: break the hold by pressing its direction, three times, fast.",
		"Then pin her: keep the needle in the green with the stick."]],
	"hold_her": ["Hold on to her", ["She wriggles. Lean against her with the stick to keep the needle in the green.", "If she slips loose, A catches her."]],
	"tickle": ["Tickling", ["A tickles. She'll laugh, and laugh.", "When she says her word, stop. At once. That's the whole skill."]],
	"fitting": ["The fitting", ["Each cuff tightens and loosens as the strap slides through.", "A when it's snug: in the green. Not loose, not tight."]],
	"test": ["Try to get out", ["Pull against the cuffs: swing the stick left and right.", "You won't get out. That's the point."]],
	"adjust": ["Does it pinch?", ["Tell her what pinches, if anything. Left wrist: left. Right wrist: right. An ankle: down.",
		"Nothing: up. Honest is right."]],
	"buckles": ["Her cuffs", ["Line each strap up with its hole using the stick, and A fastens it.", "Then check it: Y. Every buckle."]],
	"signal": ["She tests them", ["She pulls against the cuffs herself. Watch her hands.",
		"Two quick flicks of her hand is her signal: release her (A). Not before."]],
}
const CARE_LATER := {
	"grizelda": {"water": "Hm. Cold. Good.", "blanket": "I'm not cold. ...Leave it there.",
		"words": "Say that again and I'll deny I heard it. ...Say it again.", "close": "Fine. Here. Don't fuss."},
	"lull": {"water": "Thank you... a sip at a time.", "blanket": "Oh, the soft one. You remembered.",
		"words": "Your voice is nicer than the dark. Keep talking.", "close": "Stay. I can hear your heart from here."},
	"dash": {"water": "Okay. Okay! ...Water. Yes. Good call.", "blanket": "I'm a burrito now. This is my life.",
		"words": "Really? ...Say the best bit again.", "close": "C'mere. Squish."},
	"rivet": {"water": "Hydration. Very important. Noted.", "blanket": "Did you warm this? You warmed this.",
		"words": "Rated: excellent. Would hand you my cuffs again.", "close": "Lean. Yeah. Leaning's good."},
}

## Grizelda: polishing speed (radians a second of stick circling in the middle of the green), and her inspection.
const SPIN := 5.5
const GLEAM_LINES := ["Hm. Adequate.", "Other boot.", "You missed a spot. ...No. You didn't. Carry on.", "Better.", "The heel. Yes."]
const LACE := [&"word_left", &"word_right", &"word_left", &"word_right", &"word_left", &"word_right", &"word_up"]
const ORDERS := [["Kneel up.", "...Fine."], ["Eyes down.", "Hmph."], ["Hands behind you.", "They were already."],
	["Still.", "I am still. I'm always still."], ["Thank me.", "...Thank you. Mistress. Don't get used to it."]]
## Her back-talk: [her line, the tone it wants, Nim's reply by tone, her answer when it lands]. Tones: firm, amused,
## gentle. A tone that misses isn't punished: she just wins that one.
const BACKTALK := [
	["Is that how you sit a throne? Lean back. Own it.", "amused",
		{"firm": "I'll sit how I like.", "amused": "Taking notes from the floor, are we?", "gentle": "Like this? Better?"}, "Ha. ...Cheek. Good."],
	["You won't make me say it.", "firm",
		{"firm": "Say it.", "amused": "Won't I?", "gentle": "You don't have to."}, "...Thank you, Mistress. There. Happy?"],
	["(quietly) ...Am I doing this right? It's been a long while since I knelt for anyone.", "gentle",
		{"firm": "Eyes down.", "amused": "You'll get the hang of it.", "gentle": "You're doing beautifully. Breathe."}, "...Mm. Thank you."],
	["I could stand up whenever I liked, you know.", "firm",
		{"firm": "You could. You won't.", "amused": "Go on, then.", "gentle": "Do you want to?"}, "...No. I won't."],
]
const TONES := {&"word_up": "firm", &"word_right": "amused", &"word_down": "gentle"}

## Lull: where she touches Nim, by the D-pad, and what she says (from her voice alone).
const TOUCHES := {&"word_up": ["Your cheek", ["Soft... right by your whiskers.", "Here. Where you'd blush, if I could see it."]],
	&"word_right": ["Your wrist", ["Your pulse. Quick. ...Slowing.", "There. I can count you."]],
	&"word_down": ["Your back", ["Down your spine... slowly.", "Between your shoulder blades. Breathe out."]],
	&"word_left": ["Your shoulder", ["Here. Where you carry everything.", "Mm. Tense, there. Let it go."]]}
const BEAT := 2.4
const COUNT_TO := 8
const NUMS := ["One.", "Two.", "Three.", "Four.", "Five.", "Six.", "Seven.", "Eight."]
const SPOTS_LULL := {&"word_up": ["Her cheek", "Oh. There."], &"word_right": ["Her wrist", "Mm. My pulse is telling on me."],
	&"word_down": ["Her back", "Ah... I didn't hear you move."], &"word_left": ["Her shoulder", "Mm. Stay."]}

## Dash.
const DASH_CALLS := {&"word_up": "High!", &"word_right": "Right!", &"word_down": "Low!", &"word_left": "Left!"}
const DRILL_N := 12
const HOLDS := {&"word_left": "your left wrist", &"word_right": "your right wrist", &"word_down": "round your middle"}

# phase state
var _good_t := 0.0
var _all_t := 0.0
var _polish_q := 1.0
var _again := false
var _pstate := ""
var _p_t := 0.0
var _touch: StringName = &""
var _nothing := false
var _warm := false
var _laugh := 0.0
var _mercy := false
var _mercy_t := 0.0
var _mercy_at := 0.8
var _quick := false
var _tugs := 0
var _tug_side := 0
var _pinch := -1
var _errs: Array = []
var _sig := false
var _sig_t := 0.0
var _rounds := 0
var _links: Array = []
var _pin := false
var _pin_t := 0.0
var _presses := 0
var _hold_side: StringName = &""
var _wait_t := 0.0


# --- the tables --------------------------------------------------------------------------------------------------------

func _form_rows() -> Array:
	return FORMS_LATER.get(_key(), [MOUTH])


func _opener() -> String:
	return OPENERS_LATER.get(_key(), "")


func _phase_list() -> Array:
	return PHASES_LATER.get(_key(), ["check", "sit"])


func _intro(p: String) -> Array:
	return INTROS_LATER.get(p, super(p))


func _care_lines() -> Dictionary:
	return CARE_LATER.get(sister, super())


## Nim's hand does the work at Grizelda's boots and at Dash's bag; otherwise the one leading.
func _hand_rig() -> RigGear:
	return _rig if _sub_is_nim() and sister in ["grizelda", "dash"] else _top_rig


## The tickling shows her laugh beside Connection.
func _feel_show() -> void:
	super()
	if phase == "tickle":
		hud.meters.append({"name": "Laughing", "value": _laugh, "colour": SceneHud.AMBER})


func _buckle_n() -> int:
	return 4 if picks.get("set", "wrists") == "full" else 2


# --- phases: starting, the camera, each frame --------------------------------------------------------------------------

func _phase_start(p: String) -> void:
	_count = 0
	_gap = 1.0
	_wait_t = 0.0
	_touch = &""
	match p:
		"polish":
			_shine = 0.0
			_good_t = 0.0
			_all_t = 0.0
		"lace":
			_boot = 0
			_seq = LACE.duplicate()
			_seq_i = 0
		"present":
			_boot = 0
			_pstate = "wait"
			_p_t = randf_range(1.0, 1.8)
		"senses":
			hud.blind = 0.9
		"count":
			hud.blind = 0.9
			_scored = -1
		"warmth":
			hud.blind = 0.75
		"where":
			_since = 0.0
			_last_pick = []
		"ice":
			_since = 0.0
			_quick = false
		"drill":
			_call = &""
			_gap = 0.8
		"wrestle":
			_wrestle_start()
		"hold_her":
			_balance = 0.0
			_loose = false
		"tickle":
			_laugh = 0.0
			_mercy = false
			_rounds = 0
			_mercy_at = randf_range(0.65, 0.9)
		"fitting":
			_target = randf_range(-0.4, 0.4)
			_notch = -1.0
			_notch_dir = 1.0
			_errs = []
		"test":
			_tugs = 0
			_tug_side = 0
			_link_cuffs()
		"adjust":
			_pinch = -1
			var worst := 0.09
			for i in _errs.size():
				if float(_errs[i]) > worst:
					worst = float(_errs[i])
					_pinch = i
		"buckles":
			_fastened = false
			_checked = 0
		"signal":
			_rounds = 0
			_sig = false
			_p_t = randf_range(3.0, 4.5)
			_link_cuffs()


func _more_camera(hall: Vector3) -> void:
	if _rig == null:
		return
	var side := hall.cross(Vector3.UP)
	match phase:
		"senses", "count", "warmth":
			# Close on Nim's face: the blindfold, her listening.
			_cam_from = _rig.pos("head") + hall * 1.15 + Vector3.UP * 0.05 + side * 0.45
			_cam_at = _rig.pos("neck")
		"ice", "tickle":
			_cam_from = _rig.pos("chest") + hall * 1.5 + Vector3.UP * 0.3 + side * 0.5
			_cam_at = _rig.pos("chest")
		"answer":
			_cam_from = _rig.pos("head") + hall * 1.6 + Vector3.UP * 0.15 - side * 0.5
			_cam_at = _rig.pos("head")


func _more_phase(delta: float) -> bool:
	match phase:
		"polish": return _polish(delta)
		"lace": return _lace(delta)
		"present": return _present(delta)
		"orders": return _orders(delta)
		"answer": return _answer(delta)
		"senses": return _senses(delta)
		"count": return _count_phase(delta)
		"warmth": return _warmth(delta)
		"where": return _where(delta)
		"ice": return _ice(delta)
		"drill": return _drill_phase(delta)
		"wrestle": return _wrestle(delta)
		"hold_her": return _hold_her(delta)
		"tickle": return _tickle(delta)
		"fitting": return _fitting_phase(delta)
		"test": return _test_cuffs(delta)
		"adjust": return _adjust(delta)
		"buckles": return _buckles_phase(delta)
		"signal": return _signal(delta)
	return true


# --- Grizelda, she leads -----------------------------------------------------------------------------------------------

## Polish: circle the stick; the needle is how fast. In the green, the spot comes up.
func _polish(delta: float) -> bool:
	var spots := 2 if _again else 4
	_header("Her boots", "Kneel. Polish. She inspects.")
	var v := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if v.length() > 0.4:
		var a := v.angle()
		_spin = lerpf(_spin, absf(wrapf(a - _angle, -PI, PI)) / maxf(delta, 0.001), clampf(delta * 6.0, 0.0, 1.0))
		_angle = a
	else:
		_spin = lerpf(_spin, 0.0, clampf(delta * 4.0, 0.0, 1.0))
	var marker := clampf(_spin / SPIN, 0.0, 2.0) - 1.0
	var good := absf(marker) < 0.4
	_all_t += delta
	if good:
		_good_t += delta
		_shine += delta / 2.2
		_grow(0.01 * delta)
	elif marker > 0.6 and randf() < delta * 0.4:
		_say("Grizelda", "Gently. It's leather, not a floor.", 2.0)
	if _shine >= 1.0:
		_shine = 0.0
		_count += 1
		_boot = 1 - _boot
		_grow(0.05)
		hud.pop("Gleaming", SceneHud.GOLD)
		_say("Grizelda", GLEAM_LINES[_count % GLEAM_LINES.size()], 2.2)
		if _count >= spots:
			_polish_q = _good_t / maxf(_all_t, 0.001)
			return true
	hud.kind = "gauge"
	hud.cue = "The %s boot. %s" % ["left" if _boot == 0 else "right", "Steady circles." if good else ("Faster." if marker < 0.0 else "Slower.")]
	hud.data = {"marker": marker, "zone": Vector2(0.0, 0.4), "good": good, "left": "too slow", "right": "too fast"}
	hud.prompts = [[&"stick", "Circle the stick"]]
	if _top_rig:
		var foot := _top_rig.pos("footL" if _boot == 0 else "footR")
		_reach = foot + Vector3.UP * 0.1 + Vector3(cos(_angle), 0.0, sin(_angle)) * 0.05
		_aim_cam(foot, 1.3)
	return false


## A point on the front of her boot, `up` (0 at the ankle) of the way to the knee, `across` (-1..1) side to side.
func _boot_point(boot: int, up: float, across: float) -> Vector3:
	if _top_rig == null:
		return _frame
	var s := "L" if boot == 0 else "R"
	var ankle := _top_rig.pos("foot" + s)
	var knee := _top_rig.pos("shin" + s)
	var axis := (knee - ankle).normalized()
	var front := axis.cross(_top_rig.left()).normalized()
	if front.dot(_top_rig.fwd() + Vector3.UP) < 0.0:
		front = -front
	var side := axis.cross(front).normalized()
	return ankle.lerp(knee, 0.08 + up * 0.4) + front * 0.055 + side * across * 0.03


## Lace each boot: the crossing on the D-pad, in order; each cross goes on her boot.
func _lace(_delta: float) -> bool:
	_header("The laces", "Over, under. Crossing.")
	var a := _pressed(WORDS)
	if a != &"":
		if a == _seq[_seq_i]:
			if _seq_i > 0 and _seq_i < LACE.size() - 1:
				_lace_cross(_boot, _seq_i)
			_seq_i += 1
			if _seq_i >= _seq.size():
				_grow(0.08)
				hud.pop("Laced", SceneHud.GOLD)
				_say("Grizelda", ["Snug. Not strangled. Good." , "Hm. Even. I'll allow it."][_boot], 2.0)
				_boot += 1
				_seq_i = 0
				if _boot >= 2:
					return true
		else:
			_grow(-0.03)
			hud.pop("Crossed wrong", SceneHud.AMBER)
			_say("Grizelda", "Over, then under. From there.", 1.8)
	hud.kind = "steps"
	hud.cue = "The %s boot." % ["left", "right"][mini(_boot, 1)]
	hud.data = {"seq": _seq, "at": _seq_i, "knot": _boot, "of": 2}
	hud.prompts = [[&"word_up", "The D-pad, in order"]]
	var b := mini(_boot, 1)
	_reach = _boot_point(b, float(_seq_i) / LACE.size(), -1.0 if _seq_i % 2 == 0 else 1.0)
	_aim_cam(_boot_point(b, 0.3, 0.0), 1.1)
	return false


## One crossing of the lace on her boot, from one side to the other a step up.
func _lace_cross(boot: int, i: int) -> void:
	var y0 := float(i - 1) / LACE.size()
	var y1 := float(i) / LACE.size()
	var s0 := -1.0 if i % 2 == 0 else 1.0
	var line := RigGear.line_between(Vector3.ZERO, Vector3.UP, 0.005, Look.toon(Color("e8dcc0"), 0.2))
	hub.add_child(line)
	RigGear.set_line(line, _boot_point(boot, y0, s0), _boot_point(boot, y1, -s0))
	_lines.append(line)


## Present each boot: wait for her call, hold it up (A) while she looks, down when she says. Her pace.
func _present(delta: float) -> bool:
	_header("Present them", "Her pace, not yours.")
	_p_t -= delta
	var held := Input.is_action_pressed(&"jump")
	var boot_name: String = ["left", "right"][mini(_boot, 1)]
	match _pstate:
		"wait":
			if Input.is_action_just_pressed(&"jump"):
				_grow(-0.03)
				hud.pop("Wait for her", SceneHud.AMBER)
				_say("Grizelda", "Did I ask? Wait.", 1.6)
			elif _p_t <= 0.0:
				_pstate = "call"
				_p_t = 2.6
				_say("Grizelda", "The %s. Show me." % boot_name, 2.0)
		"call":
			if held:
				_pstate = "held"
				_p_t = 2.6
				_grow(0.04)
			elif _p_t <= 0.0:
				_say("Grizelda", "I'm waiting. The %s." % boot_name, 1.8)
				_grow(-0.02)
				_p_t = 2.0
		"held":
			if not held:
				_grow(-0.05)
				hud.pop("Too soon", SceneHud.AMBER)
				_say("Grizelda", "I wasn't finished. Up.", 1.6)
				_pstate = "call"
				_p_t = 2.6
			elif _p_t <= 0.0:
				var q := _polish_q
				_say("Grizelda", "...Acceptable. Down." if q >= 0.55 else "Streaky. Down.", 1.8)
				_pstate = "down"
				_p_t = 1.0
		"down":
			if not held:
				_grow(0.04)
				hud.pop("Lowered", SceneHud.GREEN)
				_boot += 1
				_pstate = "wait"
				_p_t = randf_range(1.0, 1.8)
				if _boot >= 2:
					if _polish_q < 0.55 and not _again:
						# "Again." is a real outcome (DESIGN): another polish, and present them again.
						_again = true
						_say("Grizelda", "Again.", 1.6)
						_phases.insert(_pi + 1, "polish")
						_phases.insert(_pi + 2, "present")
					else:
						_say("Grizelda", "...They'll do. You'll do.", 2.0)
						_grow(0.06)
					return true
			elif _p_t <= 0.0:
				_grow(-0.02)
				_say("Grizelda", "Down, I said.", 1.4)
				_p_t = 1.0
	hud.kind = "text"
	hud.cue = {"wait": "Kneel. Wait for her.", "call": "\"The %s. Show me.\"" % boot_name, "held": "Hold it up while she looks.",
		"down": "\"Down.\""}[_pstate]
	hud.prompts = [[&"jump", "Hold it up"]]
	if _top_rig:
		var s := "L" if _boot % 2 == 0 else "R"
		if _pstate in ["held", "down"]:
			_reach = _top_rig.pos("foot" + s) + Vector3.DOWN * 0.05
			_top_rig.turn("head", _top_rig.left(), 0.25)   # she looks down at it
		_aim_cam(_top_rig.pos("foot" + s), 1.6)
	return false


# --- Grizelda, Nim leads -----------------------------------------------------------------------------------------------

func _orders_zone() -> float:
	return 0.2 + _count * 0.03


## Say each order as her will swings into the green.
func _orders(_delta: float) -> bool:
	_header("The throne", "Yours, tonight. Make her mean it.")
	var zone := _orders_zone()
	_will = sin(_ph_t * (1.7 - _count * 0.15) + sin(_ph_t * 0.7) * 1.2)
	var good := absf(_will) < zone
	if Input.is_action_just_pressed(&"jump"):
		var c: Array = ORDERS[mini(_count, ORDERS.size() - 1)]
		_say("Nim", c[0], 1.8)
		if good:
			_count += 1
			_grow(0.07)
			hud.pop("She obeys", SceneHud.GREEN)
			_say("Grizelda", c[1], 2.4)
			if _count >= ORDERS.size():
				return true
		else:
			hud.pop("She laughs", SceneHud.AMBER)
			_say("Grizelda", ["Hm. Again. Mean it.", "Was that an order? It sounded like a question.", "No."][randi() % 3], 2.2)
			_grow(-0.02)
	hud.kind = "gauge"
	hud.cue = "Next: \"%s\"" % ORDERS[mini(_count, ORDERS.size() - 1)][0]
	hud.data = {"marker": _will, "zone": Vector2(0.0, zone), "good": good, "left": "defiant", "right": "defiant"}
	hud.prompts = [[&"jump", "Say it"]]
	if _rig:
		_rig.turn("head", Vector3.UP, _will * 0.4 * (1.0 - _count / 5.0))
		if _count >= 2:
			_rig.turn("head", _rig.left(), 0.25)
	return false


## Her back-talk, and the tone it wants.
func _answer(delta: float) -> bool:
	_header("She answers back", "Read her. Answer in kind.")
	if _ask >= BACKTALK.size():
		return true
	var b: Array = BACKTALK[_ask]
	if _ask_t <= 0.0 and _wait_t <= 0.0:
		_say("Grizelda", b[0], 3.6)
		_ask_t = 5.0
	if _wait_t > 0.0:
		_wait_t -= delta
		if _wait_t <= 0.0:
			_ask += 1
			_ask_t = 0.0
	else:
		_ask_t -= delta
		var a := _pressed(TONES.keys())
		if a != &"":
			var tone: String = TONES[a]
			_say("Nim", (b[2] as Dictionary)[tone], 2.0)
			if tone == b[1]:
				_grow(0.08)
				hud.pop("It lands", SceneHud.GREEN)
				_say("Grizelda", b[3], 2.4)
			else:
				hud.pop("She wins that one", SceneHud.AMBER)
				_say("Grizelda", ["Hm.", "...If you say so.", "Ha."][randi() % 3], 1.8)
			_wait_t = 2.4
		elif _ask_t <= 0.0:
			hud.pop("Lost your nerve", SceneHud.AMBER)
			_say("Grizelda", "...Cat got your tongue?", 1.8)
			_wait_t = 1.8
	hud.kind = "pads"
	hud.cue = "Answer her." if _wait_t <= 0.0 else ""
	hud.data = {"up": ["Firm", SceneHud.CREAM], "right": ["Amused", SceneHud.CREAM], "down": ["Gentle", SceneHud.CREAM], "hot": "",
		"timer": clampf(_ask_t / 5.0, 0.0, 1.0) if _wait_t <= 0.0 else -1.0}
	hud.prompts = [[&"word_up", "Your tone"]]
	if _rig and _ask < BACKTALK.size():
		# Her chin up when she's sparring; down, and still, when she asks something real.
		_rig.turn("head", _rig.left(), 0.3 if b[1] == "gentle" else -0.12)
	return false


# --- Lull, she leads ---------------------------------------------------------------------------------------------------

## A place on Nim for Lull's hand.
func _spot_on(r: RigGear, a: StringName) -> Vector3:
	if r == null:
		return _frame
	var f := r.fwd()
	match a:
		&"word_up":
			return r.pos("head") + f * 0.1 - r.left() * 0.08
		&"word_right":
			return r.pos("handR")
		&"word_down":
			return r.pos("chest") - f * 0.12
	return r.pos("armL") + Vector3.UP * 0.06


## Blindfolded: she touches; say where, from her voice. Sometimes nowhere: then wait.
func _senses(delta: float) -> bool:
	_header("Blindfolded", "Listen. Where is she?")
	hud.blind = 0.9
	if _touch == &"" and not _nothing:
		_gap -= delta
		if _gap <= 0.0:
			if _count >= 2 and randf() < 0.22:
				_nothing = true
				_say("Lull", "...And now?", 2.0)
			else:
				_touch = WORDS[randi() % 4]
				_say("Lull", (TOUCHES[_touch][1] as Array)[randi() % 2], 2.6)
			_p_t = 4.0
	else:
		_p_t -= delta
		var a := _pressed(WORDS)
		if _nothing:
			if a != &"":
				_grow(-0.03)
				hud.pop("Nowhere", SceneHud.AMBER)
				_say("Lull", "I wasn't touching you at all. ...You wanted me to be.", 2.2)
				_next_touch()
			elif _p_t <= 1.0:
				_grow(0.07)
				hud.pop("You waited", SceneHud.GREEN)
				_say("Lull", "Nowhere. I was only watching you. ...You didn't guess. Good.", 2.4)
				_next_touch()
		elif a == _touch:
			_grow(0.06)
			hud.pop(TOUCHES[_touch][0], SceneHud.ICE)
			_say("Lull", "Mm. There.", 1.4)
			_next_touch()
		elif a != &"" or _p_t <= 0.0:
			_grow(-0.02)
			hud.pop("Not there", SceneHud.AMBER)
			_say("Lull", "No... here.", 1.4)
			_next_touch()
		if _touch != &"" and _top_rig:
			_reach = _spot_on(_rig, _touch)
	if _count >= 6:
		return true
	hud.kind = "pads"
	hud.cue = "Where is she?" if _touch != &"" or _nothing else "Listen..."
	hud.data = {"up": ["Your cheek", SceneHud.CREAM], "right": ["Your wrist", SceneHud.CREAM], "down": ["Your back", SceneHud.CREAM],
		"left": ["Your shoulder", SceneHud.CREAM], "hot": "", "timer": clampf(_p_t / 4.0, 0.0, 1.0) if _touch != &"" else -1.0}
	hud.prompts = [[&"word_up", "Where she is"]]
	return false


func _next_touch() -> void:
	_count += 1
	_touch = &""
	_nothing = false
	_gap = randf_range(1.0, 1.8)


## Her count, slowly: A on each, the stick still.
func _count_phase(delta: float) -> bool:
	_header("Her count", "Blindfolded. A on each count.")
	hud.blind = 0.9
	var k := int(_ph_t / BEAT)
	var progress := fmod(_ph_t, BEAT) / BEAT
	if k > _count and k <= COUNT_TO:
		_count = k
		_say("Lull", NUMS[k - 1], 1.6)
	var still := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down").length() < 0.3
	if Input.is_action_just_pressed(&"jump"):
		var near := k if progress < 0.5 else k + 1
		var off := absf(_ph_t - near * BEAT)
		if near >= 1 and near <= COUNT_TO and near != _scored and off <= 0.35 and still:
			_scored = near
			_grow(0.03)
			hud.pop("Mm", SceneHud.ICE)
		else:
			hud.pop("Not yet" if off > 0.35 else "Still...", SceneHud.AMBER)
	if not still and randf() < delta * 0.5:
		_say("Lull", "Shh. Still. Only listen.", 2.0)
	hud.kind = "beat"
	hud.cue = "Listen..." if still else "Still, now."
	hud.data = {"t": progress, "window": 0.35 / BEAT, "n": _count, "of": COUNT_TO}
	hud.prompts = [[&"jump", "On her count"], [&"stick", "Keep still"]]
	if _rig:
		_reach = _rig.pos("armR") + Vector3.UP * 0.06   # her hand on Nim's shoulder
	return _ph_t >= BEAT * (COUNT_TO + 0.5)


## Warm and cold: still for the ice, lean into the cloth.
func _warmth(delta: float) -> bool:
	_header("Warm and cold", "She tells you which.")
	hud.blind = 0.75
	if _touch == &"":
		_gap -= delta
		if _gap <= 0.0:
			_touch = &"on"
			_warm = randf() < 0.5
			_good_t = 0.0
			_p_t = 2.2
			_say("Lull", "Warm." if _warm else "Cold.", 1.8)
	else:
		_p_t -= delta
		var moved := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down").length() > 0.3 or _pressed(WORDS) != &""
		if _warm:
			if Input.is_action_pressed(&"jump"):
				_good_t += delta
				if _rig:
					_rig.turn("head", _rig.fwd(), -0.18)   # leaning into her hand
		elif moved or Input.is_action_pressed(&"jump"):
			_grow(-0.03)
			hud.pop("You flinched", SceneHud.AMBER)
			_say("Lull", "Mm. Cold's cold. Again.", 1.6)
			_end_touch()
		if _touch != &"" and _p_t <= 0.0:
			if not _warm:
				_grow(0.06)
				hud.pop("Perfectly still", SceneHud.ICE)
				_say("Lull", "Good. Not a twitch.", 1.6)
			elif _good_t >= 1.2:
				_grow(0.06)
				hud.pop("Leaned in", SceneHud.GREEN)
				_say("Lull", "There. Lean.", 1.4)
			else:
				_grow(-0.01)
				_say("Lull", "You can lean, you know. I've got you.", 1.8)
			_end_touch()
		if _rig:
			_reach = _rig.pos("head") + _rig.fwd() * 0.1 - _rig.left() * 0.08 if _warm else _rig.pos("armL") + Vector3.UP * 0.05
	if _count >= 5:
		return true
	hud.kind = "text"
	hud.cue = ("\"Warm.\"  Lean into it." if _warm else "\"Cold.\"  Don't move.") if _touch != &"" else "Listen..."
	hud.prompts = [[&"jump", "Lean in (warm)"], [&"stick", "Still (cold)"]]
	return false


func _end_touch() -> void:
	_count += 1
	_touch = &""
	_gap = randf_range(0.9, 1.6)


# --- Lull, Nim leads ---------------------------------------------------------------------------------------------------

## Where Nim's hand goes next: somewhere new, never rushed.
func _where(delta: float) -> bool:
	_header("Where next", "She's blindfolded. She likes not knowing.")
	_since += delta
	var a := _pressed(WORDS)
	if a != &"":
		if _since < 1.0:
			hud.pop("Too soon", SceneHud.AMBER)
			_say("Lull", "Slower... let me wonder.", 2.0)
			_grow(-0.03)
		elif a in _last_pick:
			hud.pop("She knew", SceneHud.AMBER)
			_say("Lull", "Mm. There again.", 1.8)
			_grow(0.01)
		else:
			hud.pop("She shivers", SceneHud.GREEN)
			_say("Lull", SPOTS_LULL[a][1], 2.2)
			_grow(0.07)
		_count += 1
		var recent: Array[StringName] = [a]
		if not _last_pick.is_empty():
			recent.append(_last_pick[0])
		_last_pick = recent
		_since = 0.0
		_call = a
		_jab_t = 1.6
		if _count >= 6:
			return true
	_jab_t -= delta
	hud.kind = "pads"
	hud.cue = "Wait... let her wonder." if _since < 1.2 else "Now. Somewhere new."
	hud.data = {"up": [SPOTS_LULL[&"word_up"][0], SceneHud.CREAM], "right": [SPOTS_LULL[&"word_right"][0], SceneHud.CREAM],
		"down": [SPOTS_LULL[&"word_down"][0], SceneHud.CREAM], "left": [SPOTS_LULL[&"word_left"][0], SceneHud.CREAM],
		"hot": String(_call) if _jab_t > 0.0 else "", "timer": clampf(_since / 4.0, 0.0, 1.0)}
	hud.prompts = [[&"word_up", "Where your hand goes"]]
	if _rig and _jab_t > 0.0:
		_reach = _spot_on(_rig, _call)
	return false


## Ice or the warm cloth, by her breathing.
func _ice(delta: float) -> bool:
	_header("Ice, or the cloth", "Listen to her breathe.")
	_since += delta
	var period := 1.5 if _quick else 4.4
	var breath := 0.5 - 0.5 * cos(fmod(_ph_t, period) / period * TAU)
	if _rig:
		_rig.turn("chest", _rig.left(), -(0.12 if _quick else 0.08) * breath)
		_rig.turn("head", _rig.left(), -0.05 * breath)
	var a := _pressed([&"word_left", &"word_right"])
	if a != &"":
		if _since < 1.4:
			hud.pop("Too soon", SceneHud.AMBER)
			_say("Lull", "Mm... slower.", 1.6)
			_grow(-0.02)
		elif a == &"word_left":
			if _quick:
				_grow(-0.04)
				hud.pop("Too much", SceneHud.AMBER)
				_say("Lull", "Ah-! ...Warm, now. Please.", 2.0)
			else:
				_grow(0.07)
				hud.pop("She gasps", SceneHud.ICE)
				_say("Lull", "Oh... yes. Cold.", 1.8)
				_quick = randf() < 0.6
			_count += 1
		else:
			if _quick:
				_grow(0.07)
				hud.pop("She settles", SceneHud.GREEN)
				_say("Lull", "Mm... that's better. Thank you.", 2.0)
				_quick = false
			else:
				_grow(0.01)
				_say("Lull", "Lovely. ...A little boring. Surprise me.", 2.0)
			_count += 1
		_since = 0.0
		_call = a
		_jab_t = 1.4
		if _count >= 6:
			return true
	_jab_t -= delta
	if _since > 2.5 and fmod(_ph_t, 2.0) < delta:
		_say("Lull", "(quick, shallow breaths)" if _quick else "(slow breaths, settled)", 1.6)
	hud.kind = "pads"
	hud.cue = "Hah. Hah. Hah." if _quick else "Mmm...  mmm..."
	hud.data = {"left": ["Ice", SceneHud.ICE], "right": ["Warm cloth", SceneHud.AMBER], "hot": String(_call) if _jab_t > 0.0 else "",
		"timer": -1.0}
	hud.prompts = [[&"word_left", "Ice"], [&"word_right", "The cloth"]]
	if _rig and _jab_t > 0.0:
		_reach = _rig.pos("armL") + Vector3.UP * 0.05 + _rig.fwd() * 0.05
	return false


# --- Dash, she leads ---------------------------------------------------------------------------------------------------

## Her drill: she calls it, you hit it. Faster as it goes.
func _drill_phase(delta: float) -> bool:
	_header("Her drill", "She calls it. You hit it.")
	_jab_t -= delta
	if _call == &"":
		_gap -= delta
		if _gap <= 0.0:
			_call = WORDS[randi() % 4]
			_call_len = lerpf(1.5, 0.75, clampf(_count / float(DRILL_N), 0.0, 1.0))
			_call_t = _call_len
			_say("Dash", DASH_CALLS[_call], 0.9)
	else:
		_call_t -= delta
		var a := _pressed(WORDS)
		if a == _call:
			_count += 1
			_grow(0.03)
			hud.pop("Hit!", SceneHud.GREEN)
			_jab_t = 0.25
			_last_call = _call
			_call = &""
			_gap = 0.3
		elif a != &"" or _call_t <= 0.0:
			_grow(-0.015)
			hud.pop("Too slow" if _call_t <= 0.0 else "Miss", SceneHud.AMBER)
			_say("Dash", ["Faster! ...Okay, slower.", "Other way! Your other way!", "Ha! Again!"][randi() % 3], 1.6)
			_call = &""
			_gap = 0.3
	if _count >= DRILL_N:
		_say("Dash", "Yes! Okay. Warm-up done. Now the fun bit.", 2.2)
		return true
	hud.kind = "pads"
	hud.cue = "Go!" if _call != &"" else "Ready..."
	hud.data = {"up": ["High", SceneHud.CREAM], "right": ["Right", SceneHud.CREAM], "down": ["Low", SceneHud.CREAM],
		"left": ["Left", SceneHud.CREAM], "hot": String(_call), "timer": _call_t / _call_len if _call != &"" else -1.0}
	hud.prompts = [[&"word_up", "What she calls"]]
	if _rig and _jab_t > 0.0:
		var bag := _frame + _rig.fwd() * 0.9 + Vector3.UP * 1.15
		_reach = bag + {&"word_up": Vector3.UP * 0.25, &"word_down": Vector3.DOWN * 0.3, &"word_left": _rig.left() * 0.2,
			&"word_right": -_rig.left() * 0.2}.get(_last_call, Vector3.ZERO)
	return false


var _last_call: StringName = &"word_up"


## Dash steps in from the bag to face Nim, close enough to grab.
func _wrestle_start() -> void:
	_pin = false
	_pin_t = 0.0
	_hold_side = &""
	_presses = 0
	if _sis == null or _rig == null:
		return
	# Side by side as the camera sees it (between Nim and the bag, she hid Nim from the camera): Nim turns to face her.
	var hall := _cam_home.origin - _frame
	hall.y = 0.0
	var across := hall.normalized().cross(Vector3.UP)
	var at := _frame + across * 0.62
	_place(_sis, at, _frame)
	_place(_nim, _frame, at)
	if _top_rig == null:
		_top_rig = _pose(_sis, "stand")


## Break her holds (her direction, three times, fast), then pin her (the needle).
func _wrestle(delta: float) -> bool:
	_header("Wrestling", "All laughter. Break her holds, then pin her.")
	if _rig and _top_rig:
		var mid := (_rig.pos("chest") + _top_rig.pos("chest")) / 2.0
		_aim_cam(mid, 2.0)
	if not _pin:
		if _hold_side == &"":
			_gap -= delta
			if _gap <= 0.0:
				_hold_side = [&"word_left", &"word_right", &"word_down"][randi() % 3]
				_presses = 0
				_p_t = 3.0 if picks.get("how", "gentle") == "gentle" else 2.4
				var hold: String = HOLDS[_hold_side]
				_say("Dash", "Gotcha! %s%s!" % [hold.left(1).to_upper(), hold.substr(1)], 1.6)
		else:
			_p_t -= delta
			var a := _pressed(WORDS)
			if a == _hold_side:
				_presses += 1
				hud.pop("Twist", SceneHud.CREAM)
				if _presses >= 3:
					_count += 1
					_grow(0.07)
					hud.pop("Broke it!", SceneHud.GREEN)
					_say("Dash", ["Hey! Ha!", "No fair! ...Totally fair.", "Okay, okay, you're good!"][mini(_count - 1, 2)], 1.8)
					_hold_side = &""
					_gap = 1.1
					if _count >= 3:
						_pin = true
						_balance = 0.0
						_say("Dash", "Bet you can't pin me!", 1.8)
			elif _p_t <= 0.0:
				hud.pop("She's got you", SceneHud.AMBER)
				_say("Dash", "Ha! Pinned! ...Again! Again!", 1.8)
				_hold_side = &""
				_gap = 1.1
			# Her hands on Nim where she's got hold; Nim twisting against it.
			if _top_rig and _rig:
				var target := _rig.pos("handL") if _hold_side == &"word_left" else (_rig.pos("handR") if _hold_side == &"word_right" else _rig.pos("chest"))
				_top_rig.reach(target)
				_top_rig.reach(target + _rig.left() * 0.1, "L")
				_rig.turn("hips", Vector3.UP, sin(_ph_t * 12.0) * 0.06 * _presses)
				_rig.turn("chest", Vector3.UP, -sin(_ph_t * 12.0) * 0.08 * _presses)
		hud.kind = "pads"
		hud.cue = "She's got %s! Break it!" % HOLDS[_hold_side] if _hold_side != &"" else "She's circling..."
		hud.data = {"left": ["Left wrist", SceneHud.CREAM], "right": ["Right wrist", SceneHud.CREAM], "down": ["Middle", SceneHud.CREAM],
			"hot": String(_hold_side), "timer": clampf(_p_t / 3.0, 0.0, 1.0) if _hold_side != &"" else -1.0}
		hud.prompts = [[&"word_up", "Her hold's direction, x3"]]
		return false
	# The pin: she wriggles; keep her in the green.
	_drift = lerpf(_drift, randf_range(-1.6, 1.6), delta * 1.6)
	_balance = clampf(_balance + (_drift * 1.0 + Input.get_axis(&"move_left", &"move_right") * 1.9) * delta, -1.0, 1.0)
	var good := absf(_balance) < 0.35
	if good:
		_pin_t += delta
	if _top_rig:
		_top_rig.turn("hips", _top_rig.fwd(), _balance * 0.28)
		_top_rig.turn("chest", _top_rig.fwd(), -_balance * 0.18)
		_reach = _top_rig.pos("armL") + Vector3.UP * 0.04   # Nim's hand on her shoulder
	hud.kind = "gauge"
	hud.cue = "Pin her! %d..." % maxi(1, 3 - int(_pin_t)) if good else "She's wriggling free!"
	hud.data = {"marker": _balance, "zone": Vector2(0.0, 0.35), "good": good}
	hud.prompts = [[&"stick", "Lean against her"]]
	if _pin_t >= 3.0:
		_grow(0.1)
		hud.pop("Pinned!", SceneHud.GOLD)
		_say("Dash", "Okay! Okay! You win! ...Rematch. Later. After a nap.", 2.4)
		return true
	return false


# --- Dash, Nim leads ---------------------------------------------------------------------------------------------------

## Hold her still while she wriggles. If she gets loose, A catches her.
func _hold_her(delta: float) -> bool:
	_header("Hold on to her", "She wriggles. A lot. That's not a colour, that's just her.")
	if _loose:
		_loose_t -= delta
		if Input.is_action_just_pressed(&"jump"):
			_loose = false
			_balance = 0.0
			hud.pop("Caught!", SceneHud.GREEN)
			_say("Dash", "Hey! ...Okay. Good catch.", 1.8)
			_grow(0.03)
		elif _loose_t <= 0.0:
			_loose = false
			_balance = 0.0
			hud.pop("She's off", SceneHud.AMBER)
			_say("Dash", "Ha! Free! ...Okay, okay. Back. I'm back.", 2.2)
			_grow(-0.02)
		hud.kind = "text"
		hud.cue = "She's loose! Catch her!"
		hud.prompts = [[&"jump", "Catch her"]]
	else:
		_drift = lerpf(_drift, randf_range(-1.7, 1.7), delta * 1.6)
		_balance = clampf(_balance + (_drift * 1.1 + Input.get_axis(&"move_left", &"move_right") * 1.9) * delta, -1.0, 1.0)
		var good := absf(_balance) < 0.35
		if good:
			_grow(0.014 * delta)
		if absf(_balance) >= 1.0:
			_loose = true
			_loose_t = 0.9
			hud.pop("Loose!", SceneHud.RED)
		hud.kind = "gauge"
		hud.cue = "Hold her." if good else "She's getting away..."
		hud.data = {"marker": _balance, "zone": Vector2(0.0, 0.35), "good": good}
		hud.prompts = [[&"stick", "Lean against her"]]
	if _rig:
		_rig.turn("hips", _rig.fwd(), _balance * 0.28)
		_rig.turn("chest", _rig.fwd(), -_balance * 0.18)
		_reach = (_rig.pos("handL") + _rig.pos("handR")) / 2.0
	return _ph_t >= 18.0


## Her word, or (gagged) the bell shaken.
func _tickle_word() -> String:
	return String(picks.get("word", "Mercy"))


## Tickling until she says her word; then stop, at once.
func _tickle(delta: float) -> bool:
	_header("Tickling", "Stop the moment she says \"%s\"." % _tickle_word())
	_laugh = maxf(_laugh - delta * 0.05, 0.0)
	var a := Input.is_action_just_pressed(&"jump")
	if not _mercy:
		if a:
			_laugh = minf(_laugh + 0.11, 1.0)
			if randf() < 0.45:
				_say("Dash", ["Ha—haha! No! ...Yes!", "Hee! Not there! There! No!", "Pfft—hahaha!", "I'm not ticklish! I'm not! Hahaha!"][randi() % 4], 1.2)
		if _laugh >= _mercy_at:
			_mercy = true
			_mercy_t = 0.0
			if gagged():
				hud.pop("She shakes the bell", SceneHud.RED)
				_say("Dash", "(the bell, shaken hard)", 1.6)
			else:
				hud.pop(_tickle_word().to_upper() + "!", SceneHud.RED)
				_say("Dash", "%s! %s!" % [_tickle_word(), _tickle_word()], 1.6)
	else:
		_mercy_t += delta
		if a:
			_grow(-0.12)
			hud.pop("She said it", SceneHud.RED)
			_say("Dash", "Hey. I said it. ...When I say it, you stop. Okay?", 2.4)
			_say("Nim", "Okay. I'm sorry. Stopped.", 1.8)
			_round_over()
		elif _mercy_t >= 1.2:
			_grow(0.1)
			hud.pop("Stopped", SceneHud.GREEN)
			_say("Dash", "Haah... okay. Okay. Thank you. ...Again in a minute.", 2.4)
			_round_over()
	if _rounds >= 2:
		return true
	hud.kind = "text"
	hud.cue = "\"%s!\"" % _tickle_word() if _mercy else ("She's giggling..." if _laugh < 0.5 else "She's howling.")
	hud.prompts = [] if _mercy else [[&"jump", "Tickle"]]
	if _rig:
		var shake := sin(_ph_t * 22.0) * 0.07 * _laugh
		_rig.turn("chest", _rig.fwd(), shake)
		_rig.turn("head", _rig.left(), -0.25 * _laugh)
		if not _mercy and _top_rig:
			var side := _rig.left() * 0.13
			var ribs := _rig.pos("chest") + Vector3.DOWN * 0.08
			_top_rig.reach(ribs + side, "L")
			_reach = ribs - side
	return false


func _round_over() -> void:
	_rounds += 1
	_mercy = false
	_laugh = 0.0
	_mercy_at = randf_range(0.65, 0.9)


# --- Rivet, she leads --------------------------------------------------------------------------------------------------

## The fitting: the strap slides through its notches; A when it's snug. How far off each one was is kept: one may
## pinch.
func _fitting_phase(delta: float) -> bool:
	_header("The fitting", "She made you cuffs. Tell her when they're right.")
	_notch += _notch_dir * delta * (0.9 + _count * 0.15)
	if absf(_notch) >= 1.0:
		_notch = clampf(_notch, -1.0, 1.0)
		_notch_dir = -_notch_dir
	var good := absf(_notch - _target) < 0.18
	_fit_strap(_count, (_notch + 1.0) / 2.0)
	_aim_cam(_buckle_at())
	if Input.is_action_just_pressed(&"jump"):
		if good:
			_errs.append(_notch - _target)
			_count += 1
			_grow(0.32 / _buckle_n())
			hud.pop("Snug", SceneHud.GREEN)
			_say("Rivet", ["Snug. Good.", "Holds. Don't pull on it. ...You pulled on it.", "That one's perfect. I'm a genius.",
				"Last one. There."][mini(_count - 1, 3)], 2.0)
			_target = randf_range(-0.45, 0.45)
			if _count >= _buckle_n():
				return true
		else:
			hud.pop("Too tight" if _notch > _target else "Too loose", SceneHud.AMBER)
			_grow(-0.02)
			_say("Rivet", "Too tight. I'll let it out. Say when." if _notch > _target else "Loose. You'd slip that. Say when.", 2.0)
	hud.kind = "gauge"
	hud.cue = "The %s. Say when it's snug." % BUCKLES[mini(_count, 3)][1]
	hud.data = {"marker": _notch, "zone": Vector2(_target, 0.18), "good": good, "left": "loose", "right": "tight"}
	hud.prompts = [[&"jump", "That's it"]]
	_reach = _buckle_at()
	return false


## A short chain between the cuffed wrists (and ankles, if she fitted those), kept on the bodies each frame.
func _link_cuffs() -> void:
	for l in _links:
		if is_instance_valid(l):
			(l as Node).queue_free()
	_links = []
	var pairs := [["handL", "handR"]]
	if _buckle_n() >= 4:
		pairs.append(["footL", "footR"])
	for p: Array in pairs:
		var line := RigGear.line_between(Vector3.ZERO, Vector3.UP, 0.007, Look.toon(Color("9a9aa4"), 0.5))
		hub.add_child(line)
		_lines.append(line)
		_links.append([line, p[0], p[1]])


func _update_links() -> void:
	if _rig == null:
		return
	for l: Array in _links:
		if is_instance_valid(l[0]):
			RigGear.set_line(l[0] as MeshInstance3D, _rig.pos(l[1]), _rig.pos(l[2]))


## Try to get out: swing the stick; each pull's a tug against the cuffs, and they hold.
func _test_cuffs(_delta: float) -> bool:
	_header("Try to get out", "Pull. You won't.")
	var x := Input.get_axis(&"move_left", &"move_right")
	var side := 1 if x > 0.6 else (-1 if x < -0.6 else 0)
	if side != 0 and side != _tug_side:
		_tug_side = side
		_tugs += 1
		_grow(0.03)
		hud.pop("Holds", SceneHud.GOLD)
		if _tugs % 3 == 0:
			_say("Rivet", ["Go on. Harder.", "Nope.", "Told you. Genius.", "You're not going anywhere. Isn't that nice?"][mini(_tugs / 3 - 1, 3)], 1.8)
	if _rig:
		_rig.turn("forearmL", Vector3.UP, x * 0.22)
		_rig.turn("forearmR", Vector3.UP, x * 0.22)
		_rig.turn("chest", Vector3.UP, -x * 0.08)
		_aim_cam((_rig.pos("handL") + _rig.pos("handR")) / 2.0, 1.1)
	_update_links()
	hud.kind = "gauge"
	hud.cue = "Pull against them." if _tugs < 8 else "They hold."
	hud.data = {"marker": x, "zone": Vector2(0.0, 0.25), "good": false, "left": "pull", "right": "pull"}
	hud.prompts = [[&"stick", "Pull, left and right"]]
	if _tugs >= 8 or _ph_t > 16.0:
		_say("Rivet", "See? Built to hold. ...You look good in them.", 2.2)
		return true
	return false


## Does anything pinch? Say what (it's on Nim's own body: she'd feel it). Honest is right.
func _adjust(_delta: float) -> bool:
	_header("Does it pinch?", "Tell her.")
	_update_links()
	var names := ["Your left wrist", "Your right wrist", "Your left ankle", "Your right ankle"]
	if _rig and _pinch >= 0:
		var role: String = BUCKLES[_pinch][0]
		_rig.turn(role, _rig.left(), sin(_ph_t * 10.0) * 0.18)   # it twitches: pins and needles
	if _ask_t <= 0.0 and _ph_t < 0.2:
		_say("Rivet", "Anything pinch? Tell me. Always.", 2.0)
		_ask_t = 1.0
	var want: StringName = &"word_up"
	if _pinch == 0:
		want = &"word_left"
	elif _pinch == 1:
		want = &"word_right"
	elif _pinch >= 2:
		want = &"word_down"
	var a := _pressed([&"word_up", &"word_left", &"word_right", &"word_down"])
	if a != &"":
		if a == want:
			_grow(0.1)
			hud.pop("Told her", SceneHud.GREEN)
			_say("Nim", "All good." if _pinch < 0 else "My %s. It's tingling." % names[_pinch].trim_prefix("Your ").to_lower(), 1.8)
			_say("Rivet", "Good. Then they're perfect." if _pinch < 0 else "There. Let it out a notch. Thank you for saying.", 2.2)
		else:
			_grow(-0.05)
			hud.pop("Not quite", SceneHud.AMBER)
			_say("Rivet", "That one? ...I'm checking them all. You were going to let something go numb. Tell me. Always.", 2.6)
		if _pinch >= 0:
			_fit_strap(_pinch, 0.65)
		return true
	hud.kind = "pads"
	hud.cue = ("%s tingles." % names[_pinch]) if _pinch >= 0 else "Everything feels right."
	hud.data = {"left": ["Left wrist", SceneHud.CREAM], "right": ["Right wrist", SceneHud.CREAM], "down": ["An ankle", SceneHud.CREAM],
		"up": ["All good", SceneHud.CREAM], "hot": "", "timer": -1.0}
	hud.prompts = [[&"word_up", "Tell her"]]
	return false


# --- Rivet, Nim leads --------------------------------------------------------------------------------------------------

## Buckle each cuff (line it up, A), then check it (Y). Every buckle.
func _buckles_phase(delta: float) -> bool:
	_header("Her cuffs", "Fasten each one. Then check it. She'll know.")
	if not _fastened:
		_target = sin(_ph_t * 0.8 + _count * 1.7) * 0.55
		_notch = Input.get_axis(&"move_left", &"move_right")
		var good := absf(_notch - _target) < 0.16
		_fit_strap(_count, 0.2 + 0.6 * clampf(1.0 - absf(_notch - _target) / 0.8, 0.0, 1.0))
		if Input.is_action_just_pressed(&"jump"):
			if good:
				_fit_strap(_count, 0.82)
				_fastened = true
				_phase_t = 0.0
				hud.pop("Fastened", SceneHud.GOLD)
			else:
				hud.pop("Off the hole", SceneHud.AMBER)
				_say("Rivet", "That's not the hole. Look at it.", 1.8)
		hud.kind = "gauge"
		hud.cue = "The %s: line the strap up." % BUCKLES[mini(_count, 3)][1]
		hud.data = {"marker": _notch, "target": _target, "target_w": 0.16, "zone": Vector2(_target, 0.16), "good": good}
		hud.prompts = [[&"stick", "Line it up"], [&"jump", "Fasten"]]
	else:
		_phase_t += delta
		var checked := Input.is_action_just_pressed(&"interact")
		var skipped := _pressed(WORDS) != &"" or Input.is_action_just_pressed(&"jump") or _phase_t > 4.0
		if checked:
			_checked += 1
			_grow(0.36 / _buckle_n())
			hud.pop("Checked", SceneHud.GREEN)
			_say("Nim", "Checking it.", 1.2)
			_say("Rivet", ["Holds.", "Good. Twice, though.", "...Yes. That's how you do it.", "All four. I'm impressed. Don't tell anyone."][mini(_checked - 1, 3)], 2.0)
		elif skipped:
			hud.pop("Unchecked", SceneHud.RED)
			_say("Rivet", "You didn't check that one. I made them, so I'll know.", 2.4)
			_grow(-0.08)
		if checked or skipped:
			_count += 1
			_fastened = false
			if _count >= _buckle_n():
				return true
		hud.kind = "text"
		hud.cue = "Fastened. Now check it."
		hud.prompts = [[&"interact", "Check it"]]
	_reach = _buckle_at()
	_aim_cam(_buckle_at())
	return false


## She tests them herself: she pulls, and her signal is two quick flicks of her right hand. Release her then (A).
func _signal(delta: float) -> bool:
	_header("She tests them", "Watch her hands.")
	_update_links()
	if _rig:
		_aim_cam((_rig.pos("handL") + _rig.pos("handR")) / 2.0, 1.2)
	var a := Input.is_action_just_pressed(&"jump")
	if not _sig:
		_p_t -= delta
		# Pulling against them, hard, with a grin: that's not the signal.
		var tug := sin(_ph_t * 3.1) * 0.5 + sin(_ph_t * 7.3) * 0.2
		if _rig:
			_rig.turn("forearmL", Vector3.UP, tug * 0.25)
			_rig.turn("forearmR", Vector3.UP, tug * 0.25)
			_rig.turn("chest", Vector3.UP, -tug * 0.1)
		if a:
			_grow(-0.04)
			hud.pop("Not yet", SceneHud.AMBER)
			_say("Rivet", "I wasn't done! ...Watch for it.", 1.8)
		elif _p_t <= 0.0:
			_sig = true
			_sig_t = 0.0
	else:
		_sig_t += delta
		if _rig:
			# Two flicks of her right hand, then still: the signal.
			var flick := 0.6 if fmod(_sig_t, 0.7) < 0.15 and _sig_t < 1.4 else 0.0
			_rig.turn("handR", _rig.left(), flick)
		if a:
			_grow(0.1)
			hud.pop("Released", SceneHud.GREEN)
			_say("Rivet", ["Thanks. ...Again. Tighter.", "Mm. Quick hands. Again?", "Perfect. You watched. Okay, I'm done."][mini(_rounds, 2)], 2.0)
			_release_round()
		elif _sig_t > 2.8:
			_grow(-0.08)
			hud.pop("Missed it", SceneHud.RED)
			_say("Rivet", "...Nim. That was the signal. Release.", 2.0)
			_release_round()
	if _rounds >= 3:
		return true
	hud.kind = "text"
	hud.cue = "Watch her hands."
	hud.prompts = [[&"jump", "Release her"]]
	return false


func _release_round() -> void:
	_rounds += 1
	_sig = false
	_p_t = randf_range(2.5, 4.5)
	# The cuffs loosen as she's let out, and snug up again for the next round.
	for i in _buckle_n():
		_fit_strap(i, 0.0)
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if is_instance_valid(self) and not _done:
			for i in _buckle_n():
				_fit_strap(i, 0.82))


# --- the probes --------------------------------------------------------------------------------------------------------

func hint() -> Dictionary:
	if stage in ["form", "intro", "colour", "care"] or not PHASES_LATER.get(_key(), []).has(phase) or phase in ["colour", "check", "sit"]:
		return super()
	match phase:
		"polish":
			var a := _ph_t * SPIN * 0.95
			return {"stick2": Vector2(cos(a), sin(a))}
		"lace":
			return {"tap": _seq[_seq_i]}
		"present":
			return {"hold": &"jump", "on": _pstate in ["call", "held"]}
		"orders":
			return {"tap": &"jump"} if absf(_will) < _orders_zone() * 0.5 else {}
		"answer":
			if _wait_t > 0.0 or _ask_t > 4.0 or _ask >= BACKTALK.size():
				return {}
			var want: String = BACKTALK[_ask][1]
			for k: StringName in TONES:
				if TONES[k] == want:
					return {"tap": k}
		"senses":
			return {"tap": _touch} if _touch != &"" and _p_t < 3.2 else {}
		"count":
			return {"tap": &"jump", "stick": 0.0} if fmod(_ph_t, BEAT) < 0.06 and _ph_t > 1.0 else {"stick": 0.0}
		"warmth":
			return {"hold": &"jump", "on": _touch != &"" and _warm, "stick": 0.0}
		"where":
			if _since > 1.4:
				for k: StringName in WORDS:
					if not k in _last_pick:
						return {"tap": k}
		"ice":
			return {"tap": &"word_right" if _quick else &"word_left"} if _since > 1.6 else {}
		"drill":
			return {"tap": _call} if _call != &"" and _call_t < _call_len - 0.25 else {}
		"wrestle":
			if _pin:
				return {"stick": clampf(-_balance * 3.0 - _drift * 0.5, -1.0, 1.0)}
			return {"tap": _hold_side} if _hold_side != &"" else {}
		"hold_her":
			if _loose:
				return {"tap": &"jump", "stick": 0.0}
			return {"stick": clampf(-_balance * 3.0 - _drift * 0.6, -1.0, 1.0)}
		"tickle":
			return {} if _mercy else {"tap": &"jump"}
		"fitting":
			return {"tap": &"jump"} if absf(_notch - _target) < 0.08 else {}
		"test":
			return {"stick": -1.0 if _tug_side > 0 else 1.0}
		"adjust":
			if _ph_t < 1.0:
				return {}
			return {"tap": [&"word_left", &"word_right", &"word_down", &"word_down"][_pinch] if _pinch >= 0 else &"word_up"}
		"buckles":
			if _fastened:
				return {"tap": &"interact", "stick": 0.0}
			return {"tap": &"jump", "stick": _target} if absf(_notch - _target) < 0.08 else {"stick": _target}
		"signal":
			return {"tap": &"jump"} if _sig and _sig_t > 0.5 else {}
	return {}
