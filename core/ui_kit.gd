class_name UiKit
extends RefCounted
## The game's look for everything that isn't the world (owner, 2026-11-13: "A HUD art pass... revamp all of the menus,
## fonts"): two fonts, one palette, one Theme, and the drawing helpers the HUD and the menus share.
##
##   - **Fonts** (assets/ui/fonts, SIL Open Font License, the licences beside them): Lilita One for headings, titles
##     and numbers (chunky and cheerful); Nunito for everything read (round, clear at small sizes on the Deck).
##   - **The palette:** velvet plum panels, gold trim, cream text, the Claw's rose for warnings.
##   - **The Theme** (`apply`, from the Controls autoload): every Button, toggle, slider, panel and label in the game
##     takes it, so a menu built anywhere looks the same. Focus is a thick gold ring with a glow: on a pad, where you
##     are is never in doubt.
##   - **Title Case** (`title_case`): menu items and headings (owner: "Keep all menu items and text as title cased").
##   - **Glyph chips** (`draw_glyph`): the button for an action in the device in use, drawn (a coloured face button, a
##     D-pad, a keycap), for prompts.

const DISPLAY_PATH := "res://assets/ui/fonts/LilitaOne-Regular.ttf"
const BODY_PATH := "res://assets/ui/fonts/Nunito.ttf"

const PLUM := Color(0.075, 0.04, 0.09, 0.94)
const PLUM_LIGHT := Color(0.16, 0.08, 0.17, 0.96)
const VELVET := Color("6a1a34")
const GOLD := Color("f2c56a")
const GOLD_DEEP := Color("b8862e")
const CREAM := Color("f6efe0")
const DIM := Color("b8aab4")
const ROSE := Color("ff6f91")
const RED := Color("e0405a")
const GREEN := Color("6fd08c")
const INK := Color(0.02, 0.01, 0.03, 1.0)
const FACE := {"A": Color("5cbf6a"), "B": Color("e05a5a"), "X": Color("4f8fe0"), "Y": Color("e8c040")}

## Words kept small in Title Case (unless first or last).
const SMALL_WORDS := ["a", "an", "the", "and", "but", "or", "nor", "for", "so", "yet", "at", "by", "in", "of", "on",
	"to", "up", "as", "off", "per", "via", "vs"]

static var _display: Font
static var _body: Font
static var _bold: Font
static var _theme: Theme


static func display() -> Font:
	if _display == null:
		_display = load(DISPLAY_PATH)
	return _display


## Nunito at a weight (400 regular, 700 bold, 900 black).
static func body(weight := 600) -> Font:
	var base: Font = load(BODY_PATH)
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return v


static func bold() -> Font:
	if _bold == null:
		_bold = body(800)
	return _bold


static func text_font() -> Font:
	if _body == null:
		_body = body(600)
	return _body


## The whole game's look: the root window's theme, and the fallback font (the HUD's drawn text, the world's signs).
static func apply(root: Window) -> void:
	ThemeDB.fallback_font = text_font()
	ThemeDB.fallback_font_size = 20
	# Into the engine's default theme, which every Control falls back to: a theme on the root window doesn't reach the
	# menus under CanvasLayers (the pause screen, the settings, the HUD's).
	ThemeDB.get_default_theme().merge_with(theme())
	ThemeDB.get_default_theme().default_font = text_font()
	root.theme = theme()


static func title_case(s: String) -> String:
	var words := s.split(" ")
	for i in words.size():
		var w := words[i]
		if w == "":
			continue
		# The word itself, past any opening bracket or quote: "(what" is "(What".
		var k := 0
		while k < w.length() and not (w[k].to_upper() != w[k].to_lower()):
			k += 1
		if k >= w.length():
			continue
		var core := w.substr(k).rstrip(".,:;!?)\"'")
		var opens := k > 0
		if i > 0 and i < words.size() - 1 and not opens and core.to_lower() in SMALL_WORDS:
			words[i] = w.to_lower()
		else:
			words[i] = w.substr(0, k) + w[k].to_upper() + w.substr(k + 1)
	return " ".join(words)


static func flat(bg: Color, border := Color.TRANSPARENT, width := 0, radius := 12, margin := Vector4(18, 10, 18, 10)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin.x
	sb.content_margin_top = margin.y
	sb.content_margin_right = margin.z
	sb.content_margin_bottom = margin.w
	sb.anti_aliasing = true
	return sb


## A dark velvet card with a gold rim and a soft shadow: panels, the HUD's boxes.
static func card(radius := 16, alpha := 0.94) -> StyleBoxFlat:
	var sb := flat(Color(PLUM, alpha), Color(GOLD_DEEP, 0.85), 2, radius, Vector4(24, 20, 24, 20))
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 4)
	return sb


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = text_font()
	t.default_font_size = 20
	# Buttons: a velvet pill; hovered, warmer; focused, a gold ring with a glow (drawn over the normal box).
	var normal := flat(Color(0.12, 0.06, 0.13, 0.92), Color(VELVET.lightened(0.25), 0.9), 2, 14)
	var hover := flat(Color(0.2, 0.09, 0.18, 0.96), Color(GOLD, 0.7), 2, 14)
	var pressed := flat(Color(VELVET, 0.98), GOLD, 2, 14)
	var disabled := flat(Color(0.08, 0.06, 0.09, 0.7), Color(0.3, 0.25, 0.3), 2, 14)
	var focus := flat(Color(0, 0, 0, 0), GOLD, 3, 16)
	focus.draw_center = false
	focus.set_expand_margin_all(3)
	focus.shadow_color = Color(GOLD, 0.35)
	focus.shadow_size = 10
	for type: StringName in [&"Button", &"CheckButton", &"OptionButton", &"MenuButton"]:
		t.set_stylebox(&"normal", type, normal)
		t.set_stylebox(&"hover", type, hover)
		t.set_stylebox(&"pressed", type, pressed)
		t.set_stylebox(&"hover_pressed", type, pressed)
		t.set_stylebox(&"disabled", type, disabled)
		t.set_stylebox(&"focus", type, focus)
		t.set_font(&"font", type, bold())
		t.set_font_size(&"font_size", type, 22)
		t.set_color(&"font_color", type, CREAM)
		t.set_color(&"font_hover_color", type, GOLD)
		t.set_color(&"font_focus_color", type, GOLD)
		t.set_color(&"font_pressed_color", type, CREAM)
		t.set_color(&"font_hover_pressed_color", type, CREAM)
		t.set_color(&"font_disabled_color", type, DIM)
		t.set_color(&"font_outline_color", type, INK)
		t.set_constant(&"outline_size", type, 0)
		t.set_constant(&"h_separation", type, 12)
	# The toggle: a pill switch, gold when on.
	t.set_icon(&"checked", &"CheckButton", _switch(true))
	t.set_icon(&"unchecked", &"CheckButton", _switch(false))
	t.set_icon(&"checked_disabled", &"CheckButton", _switch(true))
	t.set_icon(&"unchecked_disabled", &"CheckButton", _switch(false))
	# Sliders: a dark track, gold filled to the grabber, a cream knob.
	var track := flat(Color(0.03, 0.02, 0.04, 0.95), Color(VELVET.lightened(0.2), 0.8), 1, 6, Vector4(0, 5, 0, 5))
	var fill := flat(Color(GOLD, 0.95), Color.TRANSPARENT, 0, 6, Vector4(0, 5, 0, 5))
	t.set_stylebox(&"slider", &"HSlider", track)
	t.set_stylebox(&"grabber_area", &"HSlider", fill)
	t.set_stylebox(&"grabber_area_highlight", &"HSlider", fill)
	t.set_icon(&"grabber", &"HSlider", _knob(CREAM))
	t.set_icon(&"grabber_highlight", &"HSlider", _knob(GOLD))
	var slider_focus := flat(Color(0, 0, 0, 0), GOLD, 2, 10)
	slider_focus.draw_center = false
	slider_focus.set_expand_margin_all(6)
	t.set_stylebox(&"focus", &"HSlider", slider_focus)
	# Panels and labels.
	t.set_stylebox(&"panel", &"PanelContainer", card())
	t.set_stylebox(&"panel", &"Panel", card())
	t.set_font(&"font", &"Label", text_font())
	t.set_color(&"font_color", &"Label", CREAM)
	t.set_color(&"font_outline_color", &"Label", INK)
	# A heading: Label with theme_type_variation "Heading".
	t.add_type(&"Heading")
	t.set_type_variation(&"Heading", &"Label")
	t.set_font(&"font", &"Heading", display())
	t.set_font_size(&"font_size", &"Heading", 40)
	t.set_color(&"font_color", &"Heading", GOLD)
	t.set_color(&"font_outline_color", &"Heading", INK)
	t.set_constant(&"outline_size", &"Heading", 8)
	t.set_color(&"font_shadow_color", &"Heading", Color(0, 0, 0, 0.5))
	t.set_constant(&"shadow_offset_y", &"Heading", 3)
	_theme = t
	return t


## The toggle's switch: a 52x28 pill, its knob left (off) or right and gold (on).
static func _switch(on: bool) -> ImageTexture:
	var w := 52
	var h := 28
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var bg := Color(GOLD_DEEP, 1.0) if on else Color(0.18, 0.12, 0.2, 1.0)
	var rim := GOLD if on else Color(0.45, 0.35, 0.45)
	var knob_x := w - h / 2.0 if on else h / 2.0
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			# The pill: the distance to its centre line, against its radius.
			var cx := clampf(p.x, h / 2.0, w - h / 2.0)
			var d := p.distance_to(Vector2(cx, h / 2.0))
			var r := h / 2.0
			var c := Color(0, 0, 0, 0)
			if d <= r:
				c = rim if d > r - 2.0 else bg
				c.a = clampf(r - d, 0.0, 1.0)
			var kd := p.distance_to(Vector2(knob_x, h / 2.0))
			var kr := r - 4.0
			if kd <= kr:
				var k := CREAM if on else Color("cfc4cc")
				c = c.blend(Color(k, clampf(kr - kd, 0.0, 1.0)))
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## A slider's knob: a 22 px disc with a dark rim.
static func _knob(colour: Color) -> ImageTexture:
	var s := 22
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var r := s / 2.0
	for y in s:
		for x in s:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(r, r))
			var c := Color(0, 0, 0, 0)
			if d <= r:
				c = INK if d > r - 2.0 else colour
				c.a = clampf(r - d, 0.0, 1.0)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# --- drawing helpers (the HUD's and the title's own _draw) ---------------------------------------------------------

## Text with an ink outline. `at` is the baseline's left (or, aligned, the box's left with `width`).
static func text(ci: CanvasItem, font: Font, at: Vector2, s: String, size: int, c: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 6) -> void:
	if size <= 0:
		return
	if outline > 0:
		ci.draw_string_outline(font, at, s, align, width, size, outline, Color(INK, c.a))
	ci.draw_string(font, at, s, align, width, size, c)


## The logo: "Vesper's" over "Kinky Kapers", gold and rose on ink, a velvet rope looped under them (the title screen,
## the store art). Centred on `c`, at scale `s` (1.0: about 900 px wide); `t` sways the rope.
static func draw_logo(ci: CanvasItem, c: Vector2, s: float, t := 0.0) -> void:
	var top := int(64 * s)
	var big := int(118 * s)
	var w := 1400.0 * s
	var x0 := c.x - w / 2.0
	var pts := PackedVector2Array()
	var span := 460.0 * s
	for i in 33:
		var k := i / 32.0
		pts.append(Vector2(c.x - span + k * span * 2.0, c.y + 92.0 * s + sin(k * PI) * 26.0 * s + sin(k * TAU * 3.0 + t) * 3.0 * s))
	ci.draw_polyline(pts, INK, 16.0 * s, true)
	ci.draw_polyline(pts, VELVET.lightened(0.15), 10.0 * s, true)
	for i in range(0, 32, 3):
		ci.draw_line(pts[i], pts[i + 1], Color(ROSE, 0.6), 3.0 * s, true)
	for e: Vector2 in [pts[0], pts[32]]:
		ci.draw_circle(e, 10.0 * s, GOLD)
		ci.draw_colored_polygon(PackedVector2Array([e + Vector2(-8, 6) * s, e + Vector2(8, 6) * s, e + Vector2(5, 34) * s,
			e + Vector2(-5, 34) * s]), GOLD_DEEP)
	text(ci, display(), Vector2(x0, c.y - 40.0 * s), "Vesper's", top, GOLD, HORIZONTAL_ALIGNMENT_CENTER, w, int(12 * s))
	text(ci, display(), Vector2(x0 + 4 * s, c.y + 72.0 * s), "Kinky Kapers", big, Color(0, 0, 0, 0.5),
		HORIZONTAL_ALIGNMENT_CENTER, w, 0)
	text(ci, display(), Vector2(x0, c.y + 66.0 * s), "Kinky Kapers", big, ROSE, HORIZONTAL_ALIGNMENT_CENTER, w, int(18 * s))
	ci.draw_string(display(), Vector2(x0, c.y + 62.0 * s), "Kinky Kapers", HORIZONTAL_ALIGNMENT_CENTER, w, big,
		Color(1, 0.85, 0.9, 0.35))


## How wide `action`'s glyph is at height `h`.
static func glyph_width(action: StringName, h: float) -> float:
	var g: String = _controls().call(&"glyph", action)
	if bool(_controls().get(&"using_pad")) and (FACE.has(g) or g.begins_with("D-pad") or g in ["LB", "RB", "LT", "RT"]):
		return h * (1.5 if g in ["LB", "RB", "LT", "RT"] else 1.0)
	return maxf(h, bold().get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.5)).x + h * 0.6)


## Draws `action`'s button with its left edge at `at.x`, centred on `at.y`, `h` tall; returns its width.
static func draw_glyph(ci: CanvasItem, at: Vector2, action: StringName, h: float) -> float:
	var g: String = _controls().call(&"glyph", action)
	var pad := bool(_controls().get(&"using_pad"))
	var w := glyph_width(action, h)
	var c := at + Vector2(w / 2.0, 0)
	if pad and FACE.has(g):
		ci.draw_circle(c + Vector2(0, h * 0.06), h * 0.5, Color(0, 0, 0, 0.45))
		ci.draw_circle(c, h * 0.5, FACE[g])
		ci.draw_arc(c, h * 0.5, 0, TAU, 28, Color(1, 1, 1, 0.45), maxf(1.5, h * 0.05), true)
		text(ci, display(), Vector2(c.x - h, c.y + h * 0.22), g, int(h * 0.62), CREAM, HORIZONTAL_ALIGNMENT_CENTER, h * 2.0, int(h * 0.12))
		return w
	if pad and g in ["LB", "RB", "LT", "RT"]:
		var r := Rect2(at.x, at.y - h * 0.4, w, h * 0.8)
		ci.draw_style_box(flat(Color(0.18, 0.16, 0.22), Color(1, 1, 1, 0.4), 2, int(h * 0.3), Vector4.ZERO), r)
		text(ci, display(), Vector2(r.position.x, c.y + h * 0.2), g, int(h * 0.5), CREAM, HORIZONTAL_ALIGNMENT_CENTER, w, 0)
		return w
	if pad and g.begins_with("D-pad"):
		var s := h * 0.46
		var arm := s * 0.38
		var base := Color(0.2, 0.18, 0.24)
		ci.draw_rect(Rect2(c.x - arm, c.y - s, arm * 2.0, s * 2.0), base)
		ci.draw_rect(Rect2(c.x - s, c.y - arm, s * 2.0, arm * 2.0), base)
		var d := {"D-pad up": Vector2(0, -1), "D-pad down": Vector2(0, 1), "D-pad left": Vector2(-1, 0),
			"D-pad right": Vector2(1, 0)}.get(g, Vector2.ZERO) as Vector2
		if d != Vector2.ZERO:
			var tip := c + d * s * 0.85
			var side := Vector2(-d.y, d.x) * arm * 0.7
			ci.draw_colored_polygon(PackedVector2Array([tip, tip - d * arm * 1.1 + side, tip - d * arm * 1.1 - side]), CREAM)
		return w
	# A keycap (the keyboard, or a pad button without a glyph of its own).
	var r := Rect2(at.x, at.y - h / 2.0, w, h)
	ci.draw_style_box(flat(Color("ece4d4"), Color("8a8070"), 2, int(h * 0.2), Vector4.ZERO), r)
	text(ci, bold(), Vector2(r.position.x, c.y + h * 0.18), g, int(h * 0.5), INK, HORIZONTAL_ALIGNMENT_CENTER, w, 0)
	return w


## The HUD's icons, drawn (crisp at any size, any text scale): `id` centred at `c`, about `s` across.
##   tiara   a point of Dignity (Nim's health): a little gold crown with a rose gem; `lost`, an empty outline, tipped
##   eye     the light meter: `amount` 0 shut (in shadow) to 1 wide open (lit)
##   mask    Composure (the suit)
##   rose    a Velvet Rose (a Key);  box  contraband;  zzz  someone woken;  tin  a collection tin
##   gear    the LB gear (a little bell for the Scold, a pendant, a lure)
static func icon(ci: CanvasItem, id: String, c: Vector2, s: float, colour := GOLD, amount := 1.0, lost := false) -> void:
	var w := maxf(1.5, s * 0.08)
	match id:
		"tiara":
			var pts := PackedVector2Array([c + Vector2(-0.5, 0.3) * s, c + Vector2(-0.5, -0.15) * s, c + Vector2(-0.27, 0.05) * s,
				c + Vector2(0.0, -0.4) * s, c + Vector2(0.27, 0.05) * s, c + Vector2(0.5, -0.15) * s, c + Vector2(0.5, 0.3) * s])
			if lost:
				pts.append(pts[0])
				ci.draw_polyline(pts, Color(DIM, 0.55), w, true)
				return
			ci.draw_colored_polygon(pts, colour)
			pts.append(pts[0])
			ci.draw_polyline(pts, Color(INK, 0.8), w, true)
			ci.draw_rect(Rect2(c + Vector2(-0.5, 0.2) * s, Vector2(s, s * 0.12)), colour.darkened(0.25))
			ci.draw_circle(c + Vector2(0, 0.06) * s, s * 0.11, ROSE)
			ci.draw_circle(c + Vector2(-0.03, 0.03) * s, s * 0.04, Color(1, 1, 1, 0.8))
			for tip: Vector2 in [Vector2(-0.5, -0.15), Vector2(0.0, -0.4), Vector2(0.5, -0.15)]:
				ci.draw_circle(c + tip * s, s * 0.06, CREAM)
		"eye":
			var open := clampf(amount, 0.0, 1.0)
			var lid := s * (0.06 + 0.3 * open)
			var top := PackedVector2Array()
			var bottom := PackedVector2Array()
			for i in 13:
				var x := lerpf(-0.5, 0.5, i / 12.0) * s
				var k := 1.0 - pow(x / (0.5 * s), 2.0)
				top.append(c + Vector2(x, -lid * k))
				bottom.append(c + Vector2(x, lid * k))
			var shape := top.duplicate()
			for i in range(bottom.size() - 1, -1, -1):
				shape.append(bottom[i])
			ci.draw_colored_polygon(shape, Color(CREAM, 0.25 + 0.75 * open))
			if open > 0.15:
				ci.draw_circle(c, s * 0.17 * minf(1.0, open * 1.5), colour)
				ci.draw_circle(c, s * 0.08 * minf(1.0, open * 1.5), INK)
			ci.draw_polyline(top, INK, w, true)
			ci.draw_polyline(bottom, INK, w, true)
		"mask":
			var m := PackedVector2Array([c + Vector2(-0.5, -0.12) * s, c + Vector2(-0.2, -0.24) * s, c + Vector2(0, -0.12) * s,
				c + Vector2(0.2, -0.24) * s, c + Vector2(0.5, -0.12) * s, c + Vector2(0.38, 0.18) * s, c + Vector2(0.1, 0.16) * s,
				c + Vector2(0, 0.04) * s, c + Vector2(-0.1, 0.16) * s, c + Vector2(-0.38, 0.18) * s])
			ci.draw_colored_polygon(m, colour)
			m.append(m[0])
			ci.draw_polyline(m, INK, w, true)
			for sx: float in [-1.0, 1.0]:
				ci.draw_circle(c + Vector2(sx * 0.22, -0.02) * s, s * 0.08, INK)
		"rose":
			ci.draw_line(c + Vector2(0, 0.1) * s, c + Vector2(0.05, 0.5) * s, Color("3a7a40"), w * 1.4, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.04, 0.3) * s, c + Vector2(0.3, 0.2) * s,
				c + Vector2(0.1, 0.38) * s]), Color("4a9a50"))
			for k in 5:
				ci.draw_circle(c + Vector2.from_angle(k * TAU / 5.0 - PI / 2.0) * s * 0.17 + Vector2(0, -0.08) * s, s * 0.17, colour.darkened(0.15))
			ci.draw_circle(c + Vector2(0, -0.08) * s, s * 0.15, colour)
			ci.draw_arc(c + Vector2(0, -0.08) * s, s * 0.08, 0, TAU * 0.8, 12, colour.darkened(0.35), w, true)
		"box":
			var r := Rect2(c - Vector2(0.42, 0.3) * s, Vector2(0.84, 0.66) * s)
			ci.draw_rect(r, colour)
			ci.draw_rect(r, INK, false, w)
			ci.draw_line(c + Vector2(-0.42, -0.08) * s, c + Vector2(0.42, -0.08) * s, INK, w, true)
			ci.draw_rect(Rect2(c + Vector2(-0.1, -0.3) * s, Vector2(0.2, 0.22) * s), ROSE)
		"zzz":
			for k in 3:
				var o := c + Vector2(-0.3 + k * 0.25, 0.25 - k * 0.25) * s
				var z := s * (0.2 + k * 0.06)
				ci.draw_polyline(PackedVector2Array([o + Vector2(-z, -z) * 0.5, o + Vector2(z, -z) * 0.5, o + Vector2(-z, z) * 0.5,
					o + Vector2(z, z) * 0.5]), colour, w * 1.3, true)
		"tin":
			var r := Rect2(c - Vector2(0.3, 0.38) * s, Vector2(0.6, 0.76) * s)
			ci.draw_rect(r, colour)
			ci.draw_rect(r, INK, false, w)
			ci.draw_line(c + Vector2(-0.12, -0.38) * s, c + Vector2(0.12, -0.38) * s, INK, w * 2.0, true)
			ci.draw_circle(c, s * 0.12, CREAM)
		"gear":
			# A little hand bell (the Scold's ring of authority), the default for any LB gear.
			var b := PackedVector2Array([c + Vector2(-0.4, 0.3) * s, c + Vector2(-0.3, 0.15) * s, c + Vector2(-0.25, -0.2) * s,
				c + Vector2(0, -0.38) * s, c + Vector2(0.25, -0.2) * s, c + Vector2(0.3, 0.15) * s, c + Vector2(0.4, 0.3) * s])
			ci.draw_colored_polygon(b, colour)
			b.append(b[0])
			ci.draw_polyline(b, INK, w, true)
			ci.draw_circle(c + Vector2(0, 0.38) * s, s * 0.09, colour.darkened(0.3))
		"crop":
			ci.draw_line(c + Vector2(-0.38, 0.38) * s, c + Vector2(0.3, -0.3) * s, INK, w * 2.6, true)
			ci.draw_line(c + Vector2(-0.38, 0.38) * s, c + Vector2(0.3, -0.3) * s, colour, w * 1.4, true)
			ci.draw_line(c + Vector2(-0.38, 0.38) * s, c + Vector2(-0.2, 0.2) * s, INK, w * 3.4, true)
			ci.draw_rect(Rect2(c + Vector2(0.24, -0.46) * s, Vector2(0.2, 0.14) * s), ROSE)
		"rope":
			for k in 3:
				ci.draw_arc(c + Vector2(0, (k - 1) * 0.08) * s, s * (0.36 - k * 0.04), 0, TAU, 28, colour, w * 1.6, true)
			ci.draw_line(c + Vector2(0.3, 0.1) * s, c + Vector2(0.48, 0.42) * s, colour, w * 1.6, true)
		"pendant":
			ci.draw_line(c + Vector2(-0.3, -0.45) * s, c + Vector2(0, -0.05) * s, colour.darkened(0.2), w, true)
			ci.draw_line(c + Vector2(0.3, -0.45) * s, c + Vector2(0, -0.05) * s, colour.darkened(0.2), w, true)
			ci.draw_circle(c + Vector2(0, 0.18) * s, s * 0.26, colour)
			ci.draw_arc(c + Vector2(0, 0.18) * s, s * 0.26, 0, TAU, 24, INK, w, true)
			for k in 3:
				ci.draw_arc(c + Vector2(0, 0.18) * s, s * (0.06 + k * 0.06), k * 2.0, k * 2.0 + PI * 1.3, 12, INK, w * 0.8, true)
		"lure":
			ci.draw_rect(Rect2(c - Vector2(0.3, 0.25) * s, Vector2(0.6, 0.5) * s), colour)
			ci.draw_rect(Rect2(c - Vector2(0.3, 0.25) * s, Vector2(0.6, 0.5) * s), INK, false, w)
			for sx: float in [-1.0, 1.0]:
				ci.draw_polyline(PackedVector2Array([c + Vector2(sx * 0.38, -0.2) * s, c + Vector2(sx * 0.48, -0.08) * s,
					c + Vector2(sx * 0.4, 0.04) * s, c + Vector2(sx * 0.5, 0.16) * s]), ROSE, w, true)
		"signet":
			ci.draw_arc(c + Vector2(0, 0.12) * s, s * 0.3, 0, TAU, 28, colour, w * 2.2, true)
			ci.draw_rect(Rect2(c + Vector2(-0.18, -0.42) * s, Vector2(0.36, 0.28) * s), colour)
			ci.draw_circle(c + Vector2(0, -0.28) * s, s * 0.08, ROSE)
		"paw":
			ci.draw_circle(c + Vector2(0, 0.14) * s, s * 0.24, colour)
			for k in 4:
				var a := lerpf(-2.4, -0.74, k / 3.0)
				ci.draw_circle(c + Vector2(cos(a), sin(a)) * s * 0.36 + Vector2(0, 0.06) * s, s * 0.1, colour)
		"word":
			var r := Rect2(c - Vector2(0.44, 0.32) * s, Vector2(0.88, 0.5) * s)
			ci.draw_style_box(flat(colour, INK, maxi(1, int(w)), int(s * 0.15), Vector4.ZERO), r)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.18, 0.17) * s, c + Vector2(0.02, 0.17) * s,
				c + Vector2(-0.24, 0.42) * s]), colour)
			for k in 3:
				ci.draw_circle(c + Vector2(-0.2 + k * 0.2, -0.07) * s, s * 0.05, INK)
		"bang":
			ci.draw_circle(c, s * 0.5, colour)
			ci.draw_arc(c, s * 0.5, 0, TAU, 24, INK, w, true)
			ci.draw_rect(Rect2(c + Vector2(-0.06, -0.3) * s, Vector2(0.12, 0.38) * s), INK)
			ci.draw_circle(c + Vector2(0, 0.22) * s, s * 0.07, INK)


static func _controls() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node(^"/root/Controls")
