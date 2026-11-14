extends SceneTree
## The store and Steam Deck art (owner, 2026-11-13: "generate new title and icon art to show in the Store and on the
## Steam Deck"). From the key art made in Meshy off our own renders (.wip/art: key_wide_3, key_wide_1, key_tall_1,
## icon_1) and the game's own logo (UiKit.draw_logo, drawn here into a transparent viewport), every size Steam asks for:
##
##   marketing/store/  header_capsule 920x430, small_capsule 462x174, main_capsule 1232x706, vertical_capsule 748x896,
##                     library_capsule 600x900, library_hero 3840x1240 (no text), library_logo 1280x720 (transparent),
##                     page_background 1438x810, community_icon 184x184, client_icon 32x32
##   marketing/deck/   a non-Steam shortcut's grid art: portrait 600x900, wide 920x430, hero 3840x1240, logo, icon
##                     (tools/deck_art.sh names them by the shortcut's app id and copies them over)
##   assets/ui/icon.png  the game's own window and export icon (256)
## Windowed (the logo is rendered):  godot --path . -s tools/store_art.gd

const SRC := "res://.wip/art/%s.png"
const OUT := "res://marketing/"

var _logo_vp: SubViewport
var _logo_c: Control


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(640, 400))
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "store"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "deck"))
	# Godot skips a folder with .gdignore in it: none of this is imported or shipped with the game.
	var f := FileAccess.open(OUT + ".gdignore", FileAccess.WRITE)
	f.close()
	var wide := _load("key_wide_3")      # open sky, the moon, Vesper and Nim on the ledge, the crew behind
	var group := _load("key_wide_1")     # the crew under the neon rope and rose
	var tall := _load("key_tall_1")      # Vesper behind, Nim crouched on the ledge
	var badge := _load("icon_1")         # Nim's masked face on a velvet badge
	# Wide capsules: the sky's the logo's, top right, over the moon's glow.
	# (Right of Vesper's head: the logo's rope ran across her face.)
	await _capsule(wide, Rect2(0, 60, 1376, 643), Vector2(920, 430), Vector2(0.71, 0.27), 0.46, "store/header_capsule")
	await _capsule(wide, Rect2(0, 120, 1376, 520), Vector2(462, 174), Vector2(0.69, 0.42), 0.25, "store/small_capsule")
	await _capsule(wide, Rect2(0, 0, 1340, 768), Vector2(1232, 706), Vector2(0.7, 0.24), 0.6, "store/main_capsule")
	# Tall capsules: the logo in the dark band over their heads.
	await _capsule(tall, Rect2(0, 110, 768, 920), Vector2(748, 896), Vector2(0.5, 0.11), 0.68, "store/vertical_capsule")
	await _capsule(tall, Rect2(0, 100, 768, 1152), Vector2(600, 900), Vector2(0.5, 0.11), 0.56, "store/library_capsule")
	# The library hero: no text (Steam lays the logo over it).
	_save(_crop(group, Rect2(0, 170, 1376, 444), Vector2(3840, 1240)), "store/library_hero")
	_save(_darken(_crop(group, Rect2(0, 0, 1376, 768), Vector2(1438, 810)), 0.45), "store/page_background")
	var logo := await _logo(Vector2(1280, 720), Vector2(640, 300), 1.3)
	_save(logo, "store/library_logo")
	var icon := _circle(badge)
	_save(_sized(icon, 184), "store/community_icon")
	_save(_sized(icon, 32), "store/client_icon")
	# The Deck's set (the same art).
	_copy("store/library_capsule", "deck/portrait")
	_copy("store/header_capsule", "deck/wide")
	_copy("store/library_hero", "deck/hero")
	_copy("store/library_logo", "deck/logo")
	_save(_sized(icon, 256), "deck/icon")
	# The game's own icon.
	_sized(icon, 256).save_png("res://assets/ui/icon.png")
	print("store art: done, in ", ProjectSettings.globalize_path(OUT))
	quit()


func _load(name: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC % name))
	img.convert(Image.FORMAT_RGBA8)
	return img


func _crop(img: Image, r: Rect2, size: Vector2) -> Image:
	var c := img.get_region(Rect2i(r))
	c.resize(int(size.x), int(size.y), Image.INTERPOLATE_LANCZOS)
	return c


func _sized(img: Image, s: int) -> Image:
	var c := img.duplicate() as Image
	c.resize(s, s, Image.INTERPOLATE_LANCZOS)
	return c


func _darken(img: Image, k: float) -> Image:
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(p.r * (1.0 - k), p.g * (1.0 - k), p.b * (1.0 - k), p.a))
	return img


## The badge cut out of its white square: everything outside the gold rim's circle made clear (a soft edge).
func _circle(img: Image) -> Image:
	var out := img.duplicate() as Image
	var c := Vector2(img.get_width(), img.get_height()) / 2.0
	var r := minf(c.x, c.y) * 0.955
	for y in out.get_height():
		for x in out.get_width():
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var p := out.get_pixel(x, y)
			p.a *= clampf(r - d, 0.0, 1.0)
			out.set_pixel(x, y, p)
	return out


## A capsule: the art cropped and sized, a soft dark pool behind where the logo goes, the logo over it.
func _capsule(img: Image, r: Rect2, size: Vector2, at: Vector2, scale: float, name: String) -> void:
	var art := _crop(img, r, size)
	var centre := size * at
	# The pool: darker toward the logo's middle, so it reads over the moon and the clouds.
	var rx := 560.0 * scale
	var ry := 190.0 * scale
	for y in art.get_height():
		for x in art.get_width():
			var d := Vector2((x - centre.x) / rx, (y - centre.y - 40.0 * scale) / ry).length()
			if d < 1.0:
				var k := 0.55 * (1.0 - d * d)
				var p := art.get_pixel(x, y)
				art.set_pixel(x, y, Color(p.r * (1.0 - k), p.g * (1.0 - k), p.b * (1.0 - k), p.a))
	var logo := await _logo(size, centre, scale)
	art.blend_rect(logo, Rect2i(Vector2i.ZERO, Vector2i(size)), Vector2i.ZERO)
	_save(art, name)


## The game's logo, drawn at `scale` round `centre` on a clear canvas `size` big.
func _logo(size: Vector2, centre: Vector2, scale: float) -> Image:
	if _logo_vp:
		_logo_vp.queue_free()
	_logo_vp = SubViewport.new()
	_logo_vp.size = Vector2i(size)
	_logo_vp.transparent_bg = true
	_logo_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_logo_vp)
	_logo_c = Control.new()
	_logo_c.size = size
	_logo_vp.add_child(_logo_c)
	_logo_c.draw.connect(func() -> void: UiKit.draw_logo(_logo_c, centre - Vector2(0, 40.0 * scale), scale, 0.6))
	_logo_c.queue_redraw()
	for i in 4:
		await process_frame
	var img := _logo_vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _save(img: Image, name: String) -> void:
	img.save_png(OUT + name + ".png")


func _copy(from: String, to: String) -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(OUT + from + ".png"))
	img.save_png(OUT + to + ".png")
