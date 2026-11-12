extends SceneTree
## The writing lint (WO-009) over the whole game: dialogue, cutscenes, world data and the strings in code. The rules
## are in core/writing_lint.gd. Exit 1 on any problem.
##   godot --headless --path . -s tools/dialogue_lint.gd


func _initialize() -> void:
	var lint := WritingLint.new()
	lint.run_all()
	for p in lint.problems:
		print("LINT  ", p)
	print("dialogue lint: %d files, %d lines, %d problems" % [lint.files, lint.lines, lint.problems.size()])
	quit(1 if lint.problems.size() > 0 else 0)
