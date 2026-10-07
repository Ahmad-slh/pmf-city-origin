extends SceneTree

var failed := false

func check(condition: bool, message: String) -> void:
	if not condition:
		print("FAIL: ", message)
	failed = failed or not condition

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var board = load("res://scenes/board.tscn").instantiate()
	root.add_child(board)
	await process_frame
	var count := 0
	for cell in board.sectors.get_children():
		if cell.cell_type != cell.CellType.SECTOR:
			continue
		count += 1
		for team in [1, 2, -1]:
			cell.owner_team = 2 if team == 1 else 1
			cell.is_locked = 0
			cell.close_cell(team)
			var expected_lock = cell.blue_lock_texture if team == 1 else (cell.red_lock_texture if team == 2 else cell.gray_lock_texture)
			var expected_sector = cell.blue_texture if team == 1 else (cell.red_texture if team == 2 else cell.normal_texture)
			check(cell.lock_sprite.texture == expected_lock, cell.name + ": closure lock")
			check(cell.sprite.texture == expected_sector, cell.name + ": closure sector")
			check(cell.lock_sprite.visible, cell.name + ": closed lock visible")
		for team in [1, 2]:
			cell.mark_as_team(team, Color.WHITE)
			check(cell.lock_sprite.texture == (cell.blue_lock_texture if team == 1 else cell.red_lock_texture), cell.name + ": ownership change updates lock")
			check(cell.is_closed, cell.name + ": transfer preserves closure")
		cell.is_locked = 1
		cell.owner_team = 1
		cell.close_cell(2)
		check(cell.owner_team == 1 and cell.lock_sprite.texture == cell.blue_lock_texture and cell.sprite.texture == cell.blue_texture, cell.name + ": battle lock follows actual retained owner")
		cell.close_neutral_cell()
		check(cell.lock_sprite.texture == cell.gray_lock_texture and cell.sprite.texture == cell.normal_texture, cell.name + ": neutral battle uses gray")
		cell.reset_sector()
		check(not cell.lock_sprite.visible, cell.name + ": reopened sector hides lock")
	print("RESULT: ", "FAIL" if failed else "PASS", " — lock colors verified on ", count, " sectors")
	quit(1 if failed else 0)
