extends CanvasLayer
## A small performance readout for test scenes (the cast stage has one on by default). Top left, under the health box,
## sized for the Deck's 1280x800. F3 or L3 (left stick click) hides and shows it.
##
##   fps          Engine.get_frames_per_second()
##   frame        frame time over the last 2 s: average and worst (ms)
##   cpu / gpu    the viewport's measured render time (ms): which side is the bottleneck
##   draws        draw calls this frame (RenderingServer)
##   prims        primitives (triangles) this frame
##   vram         video memory in use (MB)
##
## Reads Input events directly, never Controls or Game: probes compile this before autoloads exist.

const WINDOW := 2.0       # seconds of frame times kept for the average and the worst
const REFRESH := 0.25     # seconds between text updates

var shown := true
var _panel: PanelContainer
var _label: Label
## [time, delta] pairs, oldest first.
var _frames: Array[Vector2] = []
var _clock := 0.0
var _since := 0.0
var _vp_rid: RID


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.position = Vector2(16, 100)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.02, 0.01, 0.05, 0.72)
	box.set_corner_radius_all(6)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	_panel.add_theme_stylebox_override(&"panel", box)
	add_child(_panel)
	_label = Label.new()
	_label.add_theme_font_size_override(&"font_size", 16)
	_label.add_theme_color_override(&"font_color", Color("e8f0d8"))
	_label.add_theme_color_override(&"font_outline_color", Color("0d0814"))
	_label.add_theme_constant_override(&"outline_size", 4)
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["monospace", "Consolas", "DejaVu Sans Mono", "Liberation Mono"])
	_label.add_theme_font_override(&"font", mono)
	_panel.add_child(_label)
	_vp_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp_rid, true)
	_label.text = "measuring..."


func _exit_tree() -> void:
	if _vp_rid.is_valid():
		RenderingServer.viewport_set_measure_render_time(_vp_rid, false)


func _unhandled_input(event: InputEvent) -> void:
	var toggle := false
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_F3:
		toggle = true
	elif event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_LEFT_STICK:
		toggle = true
	if toggle:
		shown = not shown
		_panel.visible = shown
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_clock += delta
	_frames.append(Vector2(_clock, delta))
	while not _frames.is_empty() and _frames[0].x < _clock - WINDOW:
		_frames.pop_front()
	_since += delta
	if _since < REFRESH or not shown:
		return
	_since = 0.0
	_label.text = readout()


## The current numbers as text (the probe prints this too).
func readout() -> String:
	var total := 0.0
	var worst := 0.0
	for f in _frames:
		total += f.y
		worst = maxf(worst, f.y)
	var avg := total / maxf(1.0, _frames.size())
	var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var objects := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	var vram := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
	var cpu := RenderingServer.viewport_get_measured_render_time_cpu(_vp_rid) + RenderingServer.get_frame_setup_time_cpu()
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid)
	var text := "%3d fps\nframe %5.1f ms  worst %5.1f\nrender cpu %4.1f  gpu %4.1f\ndraws %5d  objs %4d\nprims %8d\nvram  %5.0f MB" % [
		Engine.get_frames_per_second(), avg * 1000.0, worst * 1000.0, cpu, gpu, draws, objects, prims,
		vram / 1048576.0]
	# Nim's clip, her speed and the playback rate: so a Deck clip shows which animation is playing (a walk at its
	# 2x cap was mistaken for a jittery run, 2026-11-12).
	var level := get_parent()
	var nim: Node = level.get(&"nim") if level else null
	var model: Node = nim.get(&"model") if nim else null
	if model:
		var v: Vector3 = nim.get(&"velocity")
		text += "\nnim %s  %.1f m/s  x%.2f" % [model.call(&"clip_name"), Vector2(v.x, v.z).length(),
			model.call(&"clip_scale")]
	return text
