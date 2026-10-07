extends SceneTree


var failed := false


func check(condition: bool, label: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + label)
	if not condition:
		failed = true


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var board = load("res://scenes/board.tscn").instantiate()
	root.add_child(board)
	await process_frame
	var manager = root.get_node("GameManager")
	var helper = root.get_node("GameManagerHelper")
	var unique_cells := {}
	for cell in board.sectors_map.values():
		unique_cells[cell.get_instance_id()] = cell
	for cell in unique_cells.values():
		cell.is_closed = true

	check(not board.highlight_reachable_sectors(6, Vector2i.ZERO), "no open destination is reported")
	manager.current_team = 1
	board._on_dice_rolled(6)
	await process_frame
	check(helper.active_input_blockers().has("direction_walk_failed"), "no-destination message is shown")
	var ok_button = board.find_child("WalkFailedOk", true, false)
	check(ok_button != null, "message offers an OK button")
	if ok_button != null:
		ok_button.pressed.emit()
		await process_frame
		check(manager.current_team == 2, "confirming the message advances to the other team")
		check(not helper.active_input_blockers().has("direction_walk_failed"), "input lock is released")

	for cell in unique_cells.values():
		cell.is_closed = false
	check(board.highlight_reachable_sectors(1, Vector2i.ZERO), "normal reachable movement remains available")
	print("RESULT: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
