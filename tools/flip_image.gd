extends SceneTree
## Mirrors an image left to right (a concept view whose side came out the wrong way round):
##   godot --headless --path . -s tools/flip_image.gd -- <in.png> <out.png>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var img := Image.load_from_file(args[0])
	img.flip_x()
	img.save_png(args[1])
	print("flipped ", args[0], " -> ", args[1])
	quit()
