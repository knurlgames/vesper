extends SceneTree
## Tiles every PNG in a folder into one sheet, in name order, left to right (for checking a batch of concepts at once):
##   godot --headless --path . -s tools/contact_sheet.gd -- <dir> <out.png> [columns] [cell px]
## Prints each tile's name and its place, so a sheet without labels can still be read.

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var dir: String = a[0]
	var out: String = a[1]
	var cols := int(a[2]) if a.size() > 2 else 5
	var cell := int(a[3]) if a.size() > 3 else 320
	var names: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.get_extension().to_lower() == "png":
			names.append(f)
	names.sort()
	var rows := ceili(names.size() / float(cols))
	var sheet := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.5, 0.5, 0.5))
	for i in names.size():
		var img := Image.load_from_file(dir.path_join(names[i]))
		if img == null:
			continue
		img.convert(Image.FORMAT_RGB8)
		img.resize(cell - 4, cell - 4, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i % cols) * cell + 2, (i / cols) * cell + 2))
		print("%2d  row %d col %d  %s" % [i, i / cols, i % cols, names[i]])
	sheet.save_png(out)
	print("sheet: ", out)
	quit()
