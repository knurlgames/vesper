class_name SceneHud
extends CanvasLayer
## What the club's scenes show on screen (WO-014b; owner, Deck review 3: "the BDSM games need a much better visual and
## UI to play... the current text with timing, etc is hard to play"). Everything is drawn, nothing is typed out:
##
##   top left     the scene's name, who's who, and the safeword chip (with the hold-B ring when Nim's the one tied)
##   top right    the meters (heat with the band they want, strain, trust...), easing to their values
##   bottom       the stage: a cue line, the game's own widget, the buttons for it (in the glyphs of the device in use)
##   over it      who's speaking (the scene's own lines: the world HUD is hidden while a scene runs), and pops
##                ("Perfect!", "Late") where the timing happened
##
## The games set fields (`title`, `meters`, `kind` and `data`...) every frame and the layer draws them. Widgets, by
## `kind`:
##   "ring"   breath: {target 0..1 (hers), mine 0..1, sync, label}
##   "gauge"  a needle on a track: {marker -1..1, zone Vector2(centre, half), target (optional), target_w, good,
##            left, right}
##   "beat"   a ring closing on the mark: {t (1 = it lands), window (fraction of t), n, of}
##   "steps"  a sequence of D-pad presses: {seq [actions], at, knot, of}
##   "pads"   four choices on the D-pad: {up/right/down/left: [text, colour], hot (action), timer 0..1 or -1}
##   "cards"  the tray: {items [{id, name, tag, colour, off}], at, note}
##   "form"   the negotiation: {rows [{head, opts [{text, on, limit}]}], at, foot}
## Gamepad first (the Deck): every prompt names its button, and the keyboard's when that's what's in use.

const GOLD := Color("f2c56a")
const CREAM := Color("f6efe0")
const SOFT := Color("b8a8c0")
const DIM := Color("6c5c74")
const ROSE := Color("ff6f91")
const RED := Color("e0405a")
const GREEN := Color("6fd08c")
const AMBER := Color("f0b040")
const ICE := Color("9fdcff")
const PANEL := Color(0.06, 0.035, 0.07, 0.88)
const INK := Color(0.02, 0.01, 0.03, 1.0)

var title := ""
var subtitle := ""
## The safeword chip ("" hides it); `safeword_hold` 0..1 fills its ring while B is held, -1 hides the ring.
var word := ""
var safeword_hold := -1.0
var cue := ""
var cue_colour := CREAM
var meters: Array = []
## [[action, label], ...]: "stick" is the left stick (left / right), "stick_lr" the same.
var prompts: Array = []
var kind := ""
var data := {}
var stage_visible := true
## 0..1: how far into it the sub is. The edges darken and the panels fade back (DESIGN "Richer scenes": the world
## softens to the one thing you're doing).
var headspace := 0.0
var _vig: TextureRect
## 0..1: blindfolded, from the sub's own eyes: the world goes dark behind the panels (Lull's scenes).
var blind := 0.0
var _blind_shown := 0.0

var _c: Control
var _black: ColorRect
var _font: Font
var _k := 1.0
var _shown := {}        # meter name -> the value on screen (eased)
var _pops: Array = []
var _lines: Array = []  # [speaker, text, colour, time left]
var _t := 0.0
var _panel_box: StyleBoxFlat
var _card_box: StyleBoxFlat


func _ready() -> void:
	layer = 7
	_font = ThemeDB.fallback_font
	_c = Control.new()
	_c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_c.draw.connect(_draw_all)
	add_child(_c)
	# Headspace (DESIGN "Richer scenes"): a vignette that closes in as it rises.
	_vig = TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.03, 0.0, 0.05, 0.0))
	grad.set_color(1, Color(0.03, 0.0, 0.05, 0.92))
	grad.add_point(0.55, Color(0.03, 0.0, 0.05, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.42)
	gt.fill_to = Vector2(1.05, 1.05)
	gt.width = 256
	gt.height = 256
	_vig.texture = gt
	_vig.stretch_mode = TextureRect.STRETCH_SCALE
	_vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vig.modulate.a = 0.0
	add_child(_vig)
	move_child(_vig, 0)
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	_panel_box = StyleBoxFlat.new()
	_panel_box.bg_color = PANEL
	_panel_box.border_color = Color(GOLD, 0.75)
	_panel_box.set_border_width_all(2)
	_panel_box.set_corner_radius_all(12)
	_panel_box.shadow_color = Color(0, 0, 0, 0.45)
	_panel_box.shadow_size = 10
	_card_box = StyleBoxFlat.new()
	_card_box.set_corner_radius_all(10)
	_card_box.set_border_width_all(2)


func _process(delta: float) -> void:
	_t += delta
	for m: Dictionary in meters:
		var v: float = m.get("value", 0.0)
		_shown[m.name] = lerpf(float(_shown.get(m.name, v)), v, clampf(delta * 6.0, 0.0, 1.0))
	_vig.modulate.a = lerpf(_vig.modulate.a, clampf(headspace, 0.0, 1.0), clampf(delta * 2.0, 0.0, 1.0))
	_blind_shown = lerpf(_blind_shown, clampf(blind, 0.0, 1.0), clampf(delta * 2.5, 0.0, 1.0))
	_panel_box.bg_color.a = 0.88 - 0.35 * _vig.modulate.a
	_c.modulate.a = 1.0 - 0.3 * _vig.modulate.a
	for p: Dictionary in _pops:
		p.t += delta
	_pops = _pops.filter(func(p: Dictionary) -> bool: return p.t < 1.1)
	for l: Array in _lines:
		l[3] -= delta
	_lines = _lines.filter(func(l: Array) -> bool: return l[3] > 0.0)
	_c.queue_redraw()


## A word that pops up over the stage and rises away ("Perfect!", "Late").
func pop(text: String, colour := GOLD) -> void:
	_pops.append({"text": text, "colour": colour, "t": 0.0, "x": randf_range(-40.0, 40.0)})


## A line spoken in the scene, over the stage. Two at most on screen, the newest under.
func say(speaker: String, text: String, secs := 2.8) -> void:
	if text == "":
		return
	var colour := GOLD if speaker == "Nim" else ROSE
	_lines.append([speaker, text, colour, secs])
	while _lines.size() > 2:
		_lines.pop_front()


func fade(to_black: bool, secs := 0.4) -> void:
	var tw := create_tween()
	tw.tween_property(_black, ^"color:a", 1.0 if to_black else 0.0, secs)
	await tw.finished


# --- layout --------------------------------------------------------------------------------------------------------

func _draw_all() -> void:
	var vp := _c.size
	_k = clampf(vp.y / 800.0, 0.6, 2.0)
	if _blind_shown > 0.01:
		_c.draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, _blind_shown))
	_header()
	_meters_panel(vp)
	if stage_visible and kind != "":
		var h := _stage_height()
		var w := minf(vp.x - 40.0 * _k, 820.0 * _k)
		var r := Rect2((vp.x - w) / 2.0, vp.y - h - 22.0 * _k, w, h)
		_c.draw_style_box(_panel_box, r)
		var y := r.position.y + 14.0 * _k
		if cue != "":
			_text(Vector2(r.position.x, y + 26.0 * _k), cue, 25, cue_colour, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
			y += 40.0 * _k
		var foot := 44.0 * _k if not prompts.is_empty() else 10.0 * _k
		var area := Rect2(r.position.x + 20.0 * _k, y, r.size.x - 40.0 * _k, r.end.y - foot - y)
		_widget(area)
		if not prompts.is_empty():
			_prompts_row(Vector2(r.position.x + r.size.x / 2.0, r.end.y - 24.0 * _k))
		_speech(Vector2(vp.x / 2.0, r.position.y - 14.0 * _k))
		_draw_pops(Vector2(vp.x / 2.0, r.position.y - 60.0 * _k))
	else:
		_speech(Vector2(vp.x / 2.0, vp.y - 60.0 * _k))
		_draw_pops(Vector2(vp.x / 2.0, vp.y * 0.6))


func _stage_height() -> float:
	var base := 0.0
	match kind:
		"form":
			base = 74.0 + 34.0 * float((data.get("rows", []) as Array).size()) + 36.0
		"cards":
			base = 222.0
		"pads":
			base = 215.0
		"ring", "beat":
			base = 205.0
		"text":
			base = 20.0 + (44.0 if not prompts.is_empty() else 0.0)
		"intro":
			base = 62.0 + 34.0 * float((data.get("lines", []) as Array).size())
		_:
			base = 160.0
	return (base + (40.0 if cue != "" else 0.0)) * _k


func _header() -> void:
	if title == "":
		return
	var x := 30.0 * _k
	var y := 52.0 * _k
	_text(Vector2(x, y), title, 30, GOLD)
	if subtitle != "":
		_text(Vector2(x, y + 28.0 * _k), subtitle, 18, SOFT)
	if word != "":
		var chip_y := y + (52.0 if subtitle != "" else 26.0) * _k
		var label := "SAFEWORD   %s" % word
		var tw := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * _k)).x
		var extra := 0.0
		if safeword_hold >= 0.0:
			extra = 120.0 * _k
		var r := Rect2(x, chip_y - 4.0 * _k, tw + 30.0 * _k + extra, 30.0 * _k)
		_card_box.bg_color = Color(RED, 0.18)
		_card_box.border_color = Color(RED, 0.9)
		_c.draw_style_box(_card_box, r)
		_text(Vector2(x + 14.0 * _k, chip_y + 17.0 * _k), label, 16, Color("ffd0d8"))
		if safeword_hold >= 0.0:
			var gx := x + tw + 36.0 * _k
			var w := _glyph(Vector2(gx, chip_y + 11.0 * _k), &"crouch", 22.0 * _k)
			_text(Vector2(gx + w + 6.0 * _k, chip_y + 17.0 * _k), "hold", 15, SOFT)
			if safeword_hold > 0.0:
				_c.draw_arc(Vector2(gx + w / 2.0, chip_y + 11.0 * _k), 15.0 * _k, -PI / 2.0,
					-PI / 2.0 + TAU * clampf(safeword_hold, 0.0, 1.0), 32, RED, 3.0 * _k, true)


func _meters_panel(vp: Vector2) -> void:
	if meters.is_empty():
		return
	var w := 330.0 * _k
	var row := 36.0 * _k
	var r := Rect2(vp.x - w - 24.0 * _k, 22.0 * _k, w, row * meters.size() + 20.0 * _k)
	_c.draw_style_box(_panel_box, r)
	var y := r.position.y + 12.0 * _k
	for m: Dictionary in meters:
		var c: Color = m.get("colour", GOLD)
		_text(Vector2(r.position.x + 16.0 * _k, y + 20.0 * _k), m.name, 16, SOFT)
		var bar := Rect2(r.position.x + 108.0 * _k, y + 9.0 * _k, w - 128.0 * _k, 14.0 * _k)
		_round(bar, Color(1, 1, 1, 0.08), 7.0 * _k)
		if m.has("band"):
			var band: Vector2 = m.band
			var br := Rect2(bar.position.x + bar.size.x * band.x, bar.position.y - 3.0 * _k,
				bar.size.x * (band.y - band.x), bar.size.y + 6.0 * _k)
			_round(br, Color(GREEN, 0.18), 4.0 * _k)
			for e: float in [band.x, band.y]:
				var ex := bar.position.x + bar.size.x * e
				_c.draw_line(Vector2(ex, br.position.y), Vector2(ex, br.end.y), Color(GREEN, 0.8), 2.0 * _k)
		var v := clampf(float(_shown.get(m.name, m.get("value", 0.0))), 0.0, 1.0)
		if v > 0.01:
			_round(Rect2(bar.position, Vector2(maxf(bar.size.x * v, bar.size.y), bar.size.y)), c, 7.0 * _k)
			_round(Rect2(bar.position + Vector2(2, 2) * _k, Vector2(maxf(bar.size.x * v - 4.0 * _k, 4.0), 4.0 * _k)),
				Color(1, 1, 1, 0.25), 2.0 * _k)
		y += row


func _speech(bottom_centre: Vector2) -> void:
	var y := bottom_centre.y
	for i in range(_lines.size() - 1, -1, -1):
		var l: Array = _lines[i]
		var a := clampf(float(l[3]) / 0.4, 0.0, 1.0)
		var who := "%s   " % l[0] if String(l[0]) != "" else ""
		var size := int(22 * _k)
		var tw_who := _font.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var tw := _font.get_string_size(String(l[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var x := bottom_centre.x - (tw_who + tw) / 2.0
		_text(Vector2(x, y), who, 22, Color(l[2], a))
		_text(Vector2(x + tw_who, y), String(l[1]), 22, Color(CREAM, a))
		y -= 32.0 * _k


func _draw_pops(at: Vector2) -> void:
	for p: Dictionary in _pops:
		var u: float = p.t / 1.1
		var a := clampf(1.0 - (u - 0.6) / 0.4, 0.0, 1.0)
		var size := 34.0 * (1.0 + 0.25 * clampf(1.0 - u * 5.0, 0.0, 1.0))
		_text(Vector2(at.x - 300.0 * _k + float(p.x) * _k, at.y - u * 50.0 * _k), p.text, int(size), Color(p.colour, a),
			HORIZONTAL_ALIGNMENT_CENTER, 600.0 * _k, 6)


func _prompts_row(centre: Vector2) -> void:
	# Measure, then draw centred.
	var gap := 26.0 * _k
	var widths: Array[float] = []
	var total := 0.0
	for p: Array in prompts:
		var w := _glyph_width(StringName(p[0]), 26.0 * _k) + 8.0 * _k + _font.get_string_size(String(p[1]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * _k)).x
		widths.append(w)
		total += w + gap
	var x := centre.x - (total - gap) / 2.0
	for i in prompts.size():
		var p: Array = prompts[i]
		var gw := _glyph(Vector2(x, centre.y), StringName(p[0]), 26.0 * _k)
		_text(Vector2(x + gw + 8.0 * _k, centre.y + 6.0 * _k), String(p[1]), 17, SOFT)
		x += widths[i] + gap


# --- widgets -------------------------------------------------------------------------------------------------------

func _widget(r: Rect2) -> void:
	match kind:
		"ring":
			_w_ring(r)
		"gauge":
			_w_gauge(r)
		"beat":
			_w_beat(r)
		"steps":
			_w_steps(r)
		"pads":
			_w_pads(r)
		"cards":
			_w_cards(r)
		"form":
			_w_form(r)
		"intro":
			_w_intro(r)


## How a scene's game works, a line a step, before it starts (owner, Deck review 5: they "jump right into the
## mini-game and don't give much time to adjust or learn").
func _w_intro(r: Rect2) -> void:
	var y := r.position.y + 26.0 * _k
	for i in (data.get("lines", []) as Array).size():
		var line: String = data.lines[i]
		_c.draw_circle(Vector2(r.position.x + 30.0 * _k, y - 7.0 * _k), 11.0 * _k, Color(GOLD, 0.85))
		_text(Vector2(r.position.x + 18.0 * _k, y - 1.0 * _k), str(i + 1), 15, INK, HORIZONTAL_ALIGNMENT_CENTER, 24.0 * _k, 0)
		_text(Vector2(r.position.x + 54.0 * _k, y), line, 19, CREAM)
		y += 34.0 * _k


func _w_ring(r: Rect2) -> void:
	var c := r.get_center()
	var rmax := minf(r.size.y * 0.48, 92.0 * _k)
	var rmin := rmax * 0.3
	var target: float = data.get("target", 0.0)
	var mine: float = data.get("mine", 0.0)
	var sync: bool = data.get("sync", false)
	_c.draw_arc(c, rmax, 0, TAU, 64, Color(SOFT, 0.25), 2.0 * _k, true)
	_c.draw_arc(c, rmin, 0, TAU, 48, Color(SOFT, 0.2), 1.0 * _k, true)
	var hr := lerpf(rmin, rmax, target)
	_c.draw_circle(c, hr, Color(ROSE, 0.22))
	_c.draw_arc(c, hr, 0, TAU, 64, Color(ROSE, 0.9), 3.0 * _k, true)
	var mr := lerpf(rmin, rmax, mine)
	var mc := GREEN if sync else CREAM
	_c.draw_arc(c, mr, 0, TAU, 64, mc, 5.0 * _k, true)
	if sync:
		_c.draw_arc(c, mr + 6.0 * _k, 0, TAU, 64, Color(GREEN, 0.3), 3.0 * _k, true)
	_text(Vector2(c.x - 100.0 * _k, c.y + 10.0 * _k), String(data.get("label", "")), 26, CREAM, HORIZONTAL_ALIGNMENT_CENTER,
		200.0 * _k, 6)
	# A key at the side: whose ring is whose.
	var kx := r.position.x + 10.0 * _k
	_c.draw_arc(Vector2(kx + 8.0 * _k, r.position.y + 20.0 * _k), 7.0 * _k, 0, TAU, 20, ROSE, 3.0 * _k, true)
	_text(Vector2(kx + 22.0 * _k, r.position.y + 26.0 * _k), String(data.get("hers", "Her breath")), 16, SOFT)
	_c.draw_arc(Vector2(kx + 8.0 * _k, r.position.y + 46.0 * _k), 7.0 * _k, 0, TAU, 20, mc, 3.0 * _k, true)
	_text(Vector2(kx + 22.0 * _k, r.position.y + 52.0 * _k), "Yours", 16, SOFT)


func _w_gauge(r: Rect2) -> void:
	var w := r.size.x * 0.9
	var track := Rect2(r.position.x + (r.size.x - w) / 2.0, r.get_center().y - 9.0 * _k, w, 18.0 * _k)
	var good: bool = data.get("good", false)
	_round(track, Color(1, 1, 1, 0.07), 9.0 * _k)
	var x_of := func(v: float) -> float: return track.position.x + (clampf(v, -1.0, 1.0) + 1.0) / 2.0 * track.size.x
	if data.has("zone"):
		var z: Vector2 = data.zone
		var zr := Rect2(x_of.call(z.x - z.y), track.position.y - 8.0 * _k, x_of.call(z.x + z.y) - x_of.call(z.x - z.y),
			track.size.y + 16.0 * _k)
		_round(zr, Color(GREEN, 0.2 if not good else 0.32), 8.0 * _k)
		_c.draw_line(Vector2(x_of.call(z.x), zr.position.y), Vector2(x_of.call(z.x), zr.end.y), Color(GREEN, 0.5), 1.5 * _k)
	if data.has("target"):
		var tx: float = x_of.call(float(data.target))
		var tw: float = float(data.get("target_w", 0.2)) * track.size.x / 2.0
		for k in 6:
			_c.draw_circle(Vector2(tx, track.get_center().y), tw * (1.0 - k * 0.14), Color(ROSE, 0.07 + k * 0.03))
		_c.draw_circle(Vector2(tx, track.get_center().y), 6.0 * _k, ROSE)
	var mx: float = x_of.call(float(data.get("marker", 0.0)))
	var mc := GREEN if good else CREAM
	var cy := track.get_center().y
	_c.draw_line(Vector2(mx, cy - 26.0 * _k), Vector2(mx, cy + 26.0 * _k), mc, 4.0 * _k)
	var d := 11.0 * _k
	_c.draw_colored_polygon(PackedVector2Array([Vector2(mx, cy - 26.0 * _k - d), Vector2(mx + d, cy - 26.0 * _k),
		Vector2(mx, cy - 26.0 * _k + d), Vector2(mx - d, cy - 26.0 * _k)]), mc)
	# (A widget's data can be the last one's for a frame when the kind changes: only strings are labels.)
	var l: String = data.left if data.get("left") is String else ""
	var rt: String = data.right if data.get("right") is String else ""
	if l != "":
		_text(Vector2(track.position.x, track.end.y + 34.0 * _k), l, 16, SOFT)
	if rt != "":
		_text(Vector2(track.end.x - 300.0 * _k, track.end.y + 34.0 * _k), rt, 16, SOFT, HORIZONTAL_ALIGNMENT_RIGHT, 300.0 * _k)


func _w_beat(r: Rect2) -> void:
	var c := r.get_center() + Vector2(0, -6.0 * _k)
	var r0 := minf(r.size.y * 0.2, 34.0 * _k)
	var t: float = data.get("t", 0.0)
	var window: float = data.get("window", 0.15)
	var inside := absf(t - 1.0) <= window
	_c.draw_circle(c, r0 * (1.0 + window * 2.2), Color(GREEN, 0.1))
	_c.draw_arc(c, r0, 0, TAU, 48, GOLD, 4.0 * _k, true)
	_c.draw_circle(c, r0 * 0.45, Color(GOLD, 0.8 if inside else 0.35))
	if t >= 0.0:
		var rr := r0 * (1.0 + 2.2 * (1.0 - t)) if t <= 1.0 else r0 * maxf(1.0 - (t - 1.0) * 2.0, 0.2)
		var a := 1.0 if t <= 1.0 else clampf(1.0 - (t - 1.0) * 3.0, 0.0, 1.0)
		_c.draw_arc(c, rr, 0, TAU, 64, Color(GREEN if inside else CREAM, a), 5.0 * _k, true)
	var n: int = data.get("n", 0)
	var of: int = data.get("of", 0)
	for i in of:
		var px := c.x + (i - (of - 1) / 2.0) * 22.0 * _k
		var py := r.position.y + 6.0 * _k
		_c.draw_circle(Vector2(px, py), 6.0 * _k, GOLD if i < n else Color(SOFT, 0.3))


func _w_steps(r: Rect2) -> void:
	var seq: Array = data.get("seq", [])
	var at: int = data.get("at", 0)
	var knot: int = data.get("knot", 0)
	var of: int = data.get("of", 6)
	var cy := r.get_center().y + 8.0 * _k
	for i in of:
		var px := r.get_center().x + (i - (of - 1) / 2.0) * 26.0 * _k
		var col := GOLD if i < knot else (ROSE if i == knot else Color(SOFT, 0.3))
		_c.draw_circle(Vector2(px, r.position.y + 8.0 * _k), 7.0 * _k, col)
	var size := 64.0 * _k
	var gap := 16.0 * _k
	var x := r.get_center().x - (seq.size() * (size + gap) - gap) / 2.0
	for i in seq.size():
		var box := Rect2(x, cy - size / 2.0, size, size)
		var pulse := 0.5 + 0.5 * sin(_t * 8.0)
		if i < at:
			_card_box.bg_color = Color(GOLD, 0.85)
			_card_box.border_color = GOLD
		elif i == at:
			_card_box.bg_color = Color(0.2, 0.08, 0.14, 0.95)
			_card_box.border_color = Color(ROSE, 0.6 + 0.4 * pulse)
		else:
			_card_box.bg_color = Color(1, 1, 1, 0.05)
			_card_box.border_color = Color(SOFT, 0.3)
		_c.draw_style_box(_card_box, box.grow(3.0 * _k * pulse) if i == at else box)
		_dpad(box.get_center(), size * 0.36, StringName(seq[i]), INK if i < at else (CREAM if i == at else DIM))
		x += size + gap


func _w_pads(r: Rect2) -> void:
	var c := r.get_center() + Vector2(0, 4.0 * _k)
	var hot: String = String(data.get("hot", ""))
	_dpad(c, 30.0 * _k, StringName(hot), CREAM, true)
	var spots := {"word_up": [Vector2(0, -50), HORIZONTAL_ALIGNMENT_CENTER], "word_down": [Vector2(0, 66), HORIZONTAL_ALIGNMENT_CENTER],
		"word_left": [Vector2(-70, 8), HORIZONTAL_ALIGNMENT_RIGHT], "word_right": [Vector2(70, 8), HORIZONTAL_ALIGNMENT_LEFT]}
	for a: String in spots:
		var key := a.trim_prefix("word_")
		if not data.has(key):
			continue
		var item: Array = data[key]
		var off: Vector2 = spots[a][0] * _k
		var align: int = spots[a][1]
		var col: Color = item[1] if item.size() > 1 else CREAM
		var w := 260.0 * _k
		var x := c.x + off.x - (w / 2.0 if align == HORIZONTAL_ALIGNMENT_CENTER else (w if align == HORIZONTAL_ALIGNMENT_RIGHT else 0.0))
		var lit := hot == a
		_text(Vector2(x, c.y + off.y), String(item[0]), 24 if lit else 21, col if lit or hot == "" else Color(col, 0.65), align as HorizontalAlignment, w, 5)
	var timer: float = data.get("timer", -1.0)
	if timer >= 0.0:
		var bar := Rect2(r.position.x + r.size.x * 0.25, r.end.y - 6.0 * _k, r.size.x * 0.5, 6.0 * _k)
		_round(bar, Color(1, 1, 1, 0.08), 3.0 * _k)
		_round(Rect2(bar.position, Vector2(bar.size.x * clampf(timer, 0.0, 1.0), bar.size.y)),
			AMBER if timer > 0.35 else RED, 3.0 * _k)


func _w_cards(r: Rect2) -> void:
	var items: Array = data.get("items", [])
	var at: int = data.get("at", 0)
	if items.is_empty():
		return
	var gap := 10.0 * _k
	var cw := minf(96.0 * _k, (r.size.x - gap * (items.size() - 1)) / items.size())
	var ch := 128.0 * _k
	var x := r.get_center().x - (items.size() * (cw + gap) - gap) / 2.0
	for i in items.size():
		var it: Dictionary = items[i]
		var sel := i == at
		var box := Rect2(x, r.position.y + (4.0 if sel else 16.0) * _k, cw, ch)
		var col: Color = it.get("colour", GOLD)
		_card_box.bg_color = Color(col.darkened(0.75), 0.95) if sel else Color(1, 1, 1, 0.05)
		_card_box.border_color = GOLD if sel else Color(col, 0.35)
		if sel:
			_c.draw_style_box(_card_box, box.grow(2.0 * _k))
		else:
			_c.draw_style_box(_card_box, box)
		_icon(String(it.get("id", "")), box.get_center() + Vector2(0, -16.0 * _k), cw * 0.3, col if not it.get("off", false) else DIM)
		_text(Vector2(box.position.x, box.end.y - 30.0 * _k), String(it.get("name", "")), 16 if sel else 15,
			CREAM if sel else SOFT, HORIZONTAL_ALIGNMENT_CENTER, cw)
		_text(Vector2(box.position.x, box.end.y - 12.0 * _k), String(it.get("tag", "")), 12, Color(col, 0.85),
			HORIZONTAL_ALIGNMENT_CENTER, cw)
		x += cw + gap
	var note: String = data.get("note", "")
	if note != "":
		_text(Vector2(r.position.x, r.position.y + ch + 46.0 * _k), note, 17, SOFT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _w_form(r: Rect2) -> void:
	var rows: Array = data.get("rows", [])
	var at: int = data.get("at", 0)
	var y := r.position.y + 4.0 * _k
	var row_h := 34.0 * _k
	for i in rows.size():
		var row: Dictionary = rows[i]
		var lit := i == at
		if lit:
			_round(Rect2(r.position.x - 6.0 * _k, y, r.size.x + 12.0 * _k, row_h - 4.0 * _k), Color(GOLD, 0.1), 6.0 * _k)
			_c.draw_rect(Rect2(r.position.x - 6.0 * _k, y, 4.0 * _k, row_h - 4.0 * _k), GOLD)
		_text(Vector2(r.position.x + 8.0 * _k, y + 22.0 * _k), String(row.head), 15, GOLD if lit else SOFT)
		var x := r.position.x + 150.0 * _k
		for o: Dictionary in row.opts:
			var text: String = o.text
			var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * _k)).x
			var pill := Rect2(x, y + 3.0 * _k, tw + 26.0 * _k, row_h - 10.0 * _k)
			if o.get("limit", false):
				_card_box.bg_color = Color(0, 0, 0, 0)
				_card_box.border_color = Color(DIM, 0.5)
				_c.draw_style_box(_card_box, pill)
				_text(Vector2(x + 13.0 * _k, y + 22.0 * _k), text, 16, DIM)
				_c.draw_line(Vector2(x + 8.0 * _k, y + 17.0 * _k), Vector2(pill.end.x - 8.0 * _k, y + 17.0 * _k), Color(RED, 0.7), 2.0 * _k)
			elif o.get("on", false):
				_card_box.bg_color = GOLD if lit else Color(GOLD, 0.7)
				_card_box.border_color = GOLD
				_c.draw_style_box(_card_box, pill)
				_text(Vector2(x + 13.0 * _k, y + 22.0 * _k), text, 16, INK, HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
			else:
				_card_box.bg_color = Color(1, 1, 1, 0.04)
				_card_box.border_color = Color(SOFT, 0.35)
				_c.draw_style_box(_card_box, pill)
				_text(Vector2(x + 13.0 * _k, y + 22.0 * _k), text, 16, SOFT)
			x += pill.size.x + 8.0 * _k
		var note: String = row.get("note", "")
		if note != "":
			_text(Vector2(x + 6.0 * _k, y + 22.0 * _k), note, 14, DIM)
		y += row_h
	var foot: String = data.get("foot", "")
	if foot != "":
		_text(Vector2(r.position.x, y + 22.0 * _k), foot, 16, CREAM, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


# --- glyphs and icons ----------------------------------------------------------------------------------------------

const FACE := {"A": Color("5cbf6a"), "B": Color("e05a5a"), "X": Color("4f8fe0"), "Y": Color("e8c040")}
const DPAD := {"D-pad up": &"word_up", "D-pad down": &"word_down", "D-pad left": &"word_left", "D-pad right": &"word_right"}


func _glyph_width(action: StringName, h: float) -> float:
	if action in [&"stick", &"stick_lr"]:
		return h if Controls.using_pad else h * 2.0 + 4.0 * _k
	var g := Controls.glyph(action)
	if Controls.using_pad and (FACE.has(g) or DPAD.has(g)):
		return h
	return maxf(h, _font.get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.55)).x + h * 0.6)


## Draws `action`'s button with its left edge at `at.x`, centred on `at.y`, `h` tall; returns its width.
func _glyph(at: Vector2, action: StringName, h: float) -> float:
	var w := _glyph_width(action, h)
	var c := at + Vector2(w / 2.0, 0)
	if action in [&"stick", &"stick_lr"]:
		if Controls.using_pad:
			_c.draw_circle(c, h * 0.5, Color(0.2, 0.18, 0.24))
			_c.draw_arc(c, h * 0.5, 0, TAU, 24, SOFT, 1.5 * _k, true)
			_c.draw_circle(c, h * 0.2, CREAM)
			for s: float in [-1.0, 1.0]:
				var tip := c + Vector2(s * h * 0.42, 0)
				_c.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-s * h * 0.14, -h * 0.1),
					tip + Vector2(-s * h * 0.14, h * 0.1)]), CREAM)
		else:
			_keycap(Rect2(at.x, at.y - h / 2.0, h, h), Controls.glyph(&"move_left"))
			_keycap(Rect2(at.x + h + 4.0 * _k, at.y - h / 2.0, h, h), Controls.glyph(&"move_right"))
		return w
	var g := Controls.glyph(action)
	if Controls.using_pad and FACE.has(g):
		_c.draw_circle(c, h * 0.5, FACE[g])
		_c.draw_arc(c, h * 0.5, 0, TAU, 24, Color(1, 1, 1, 0.35), 1.5 * _k, true)
		_text(Vector2(c.x - h, c.y + h * 0.2), g, int(h * 0.6 / _k), INK, HORIZONTAL_ALIGNMENT_CENTER, h * 2.0, 0)
		return w
	if Controls.using_pad and DPAD.has(g):
		_dpad(c, h * 0.45, DPAD[g], CREAM)
		return w
	_keycap(Rect2(at.x, at.y - h / 2.0, w, h), g)
	return w


func _keycap(r: Rect2, text: String) -> void:
	_card_box.bg_color = Color("e8e0d0")
	_card_box.border_color = Color("8a8070")
	_c.draw_style_box(_card_box, r)
	_text(Vector2(r.position.x, r.get_center().y + r.size.y * 0.2), text, int(r.size.y * 0.55 / _k), INK,
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 0)


## A D-pad, `hot`'s arm lit (and pulsing if `pulse`).
func _dpad(c: Vector2, s: float, hot: StringName, colour: Color, pulse := false) -> void:
	var arm := s * 0.38
	var base := Color(0.22, 0.2, 0.26)
	_c.draw_rect(Rect2(c.x - arm, c.y - s, arm * 2.0, s * 2.0), base)
	_c.draw_rect(Rect2(c.x - s, c.y - arm, s * 2.0, arm * 2.0), base)
	var dirs := {&"word_up": Vector2(0, -1), &"word_down": Vector2(0, 1), &"word_left": Vector2(-1, 0), &"word_right": Vector2(1, 0)}
	for a: StringName in dirs:
		var d: Vector2 = dirs[a]
		var tip := c + d * s * 0.85
		var side := Vector2(-d.y, d.x) * arm * 0.7
		var lit := a == hot
		var col := colour if lit else Color(colour, 0.3)
		if lit and pulse:
			col = Color(colour, 0.65 + 0.35 * sin(_t * 9.0))
		_c.draw_colored_polygon(PackedVector2Array([tip, tip - d * arm * 1.1 + side, tip - d * arm * 1.1 - side]), col)


## The tray's pictures, drawn small and simple.
func _icon(id: String, c: Vector2, s: float, col: Color) -> void:
	var w := 3.0 * _k
	match id:
		"feather":
			var pts := PackedVector2Array()
			for k in 13:
				var u := k / 12.0
				pts.append(c + Vector2(lerpf(-s * 0.7, s * 0.7, u), -sin(u * PI) * s * 0.35 + lerpf(s * 0.6, -s * 0.6, u)))
			_c.draw_polyline(pts, col, w, true)
			for k in range(2, 11):
				var p := pts[k]
				_c.draw_line(p, p + Vector2(-s * 0.25, -s * 0.25), Color(col, 0.7), w * 0.6, true)
				_c.draw_line(p, p + Vector2(s * 0.25, s * 0.18), Color(col, 0.7), w * 0.6, true)
		"ice":
			var hex := PackedVector2Array()
			for k in 7:
				hex.append(c + Vector2.from_angle(PI / 6.0 + k * TAU / 6.0) * s * 0.75)
			_c.draw_polyline(hex, col, w, true)
			for k in [1, 3, 5]:
				_c.draw_line(c, c + Vector2.from_angle(PI / 6.0 + k * TAU / 6.0) * s * 0.75, Color(col, 0.7), w * 0.7, true)
		"whisper":
			for k in 3:
				_c.draw_arc(c + Vector2(-s * 0.5, 0), s * (0.3 + k * 0.28), -0.7, 0.7, 12, Color(col, 1.0 - k * 0.25), w, true)
		"flogger":
			_c.draw_line(c + Vector2(-s * 0.7, s * 0.7), c + Vector2(-s * 0.15, s * 0.15), col, w * 1.8, true)
			for k in 5:
				var a := -PI / 4.0 + (k - 2) * 0.16
				_c.draw_line(c + Vector2(-s * 0.15, s * 0.15), c + Vector2(-s * 0.15, s * 0.15) + Vector2.from_angle(a) * s, col, w * 0.8, true)
		"crop":
			_c.draw_line(c + Vector2(-s * 0.75, s * 0.75), c + Vector2(s * 0.55, -s * 0.55), col, w, true)
			_c.draw_line(c + Vector2(-s * 0.75, s * 0.75), c + Vector2(-s * 0.4, s * 0.4), col, w * 2.2, true)
			_c.draw_rect(Rect2(c + Vector2(s * 0.45, -s * 0.85), Vector2(s * 0.4, s * 0.3)), col)
		"paddle":
			_round(Rect2(c + Vector2(-s * 0.4, -s * 0.85), Vector2(s * 0.8, s * 1.0)), col, s * 0.2)
			_c.draw_line(c + Vector2(0, s * 0.15), c + Vector2(0, s * 0.85), col, w * 2.0, true)
		"praise":
			_c.draw_circle(c + Vector2(-s * 0.32, -s * 0.15), s * 0.36, col)
			_c.draw_circle(c + Vector2(s * 0.32, -s * 0.15), s * 0.36, col)
			_c.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.67, 0), c + Vector2(s * 0.67, 0), c + Vector2(0, s * 0.75)]), col)
		"check":
			_c.draw_arc(c, s * 0.8, 0, TAU, 32, col, w, true)
			_text(Vector2(c.x - s, c.y + s * 0.35), "?", int(s * 1.2 / _k), col, HORIZONTAL_ALIGNMENT_CENTER, s * 2.0, 0)
		"enough":
			var oct := PackedVector2Array()
			for k in 9:
				oct.append(c + Vector2.from_angle(PI / 8.0 + k * TAU / 8.0) * s * 0.8)
			_c.draw_polyline(oct, col, w, true)
			_c.draw_line(c + Vector2(-s * 0.35, 0), c + Vector2(s * 0.35, 0), col, w * 1.6, true)


# --- primitives ----------------------------------------------------------------------------------------------------

func _text(at: Vector2, text: String, size: int, c: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0,
		outline := 4) -> void:
	var s := int(size * _k)
	if s <= 0:
		return   # a tiny window (the headless probes' 64 px) rounds the font to nothing
	if outline > 0:
		_c.draw_string_outline(_font, at, text, align, width, s, int(outline * _k), Color(INK, c.a))
	_c.draw_string(_font, at, text, align, width, s, c)


func _round(r: Rect2, c: Color, radius: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(int(radius))
	_c.draw_style_box(sb, r)
