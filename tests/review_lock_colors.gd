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
		# قطاع أعيد فتحه بلا مالك وقد استُهلك سؤاله الأول: نقطة الفرصة الثانية
		cell.reset_sector()
		cell.owner_team = 0
		cell.questions_used = 1
		check(cell.lock_sprite.visible and cell.lock_sprite.texture == cell.pending_dot_texture, cell.name + ": unowned sector with a used question shows the second-chance dot")
		# قطاع مفتوح لفريق مالك: لا علامة إطلاقا
		cell.owner_team = 1
		cell.update_sector_owner_image()
		check(not cell.lock_sprite.visible, cell.name + ": owned open sector carries no marker")
		# قطاع لم يُلعب بعد: لا علامة
		cell.owner_team = 0
		cell.questions_used = 0
		check(not cell.lock_sprite.visible, cell.name + ": untouched sector carries no marker")
	# ------------------------------------------------------------------
	# النقطة الوامضة والقفل يتشاركان العقدة نفسها، والوميض يبدّل صورتها
	# كل نصف ثانية. لو بقي شغّالا بعد الإغلاق لمسح القفل بعد لحظة.
	# هذه الفحوص تحرس ذلك الحد تحديدا
	# ------------------------------------------------------------------
	var all_sectors: Array = []
	for c in board.sectors.get_children():
		if c.cell_type == c.CellType.SECTOR:
			all_sectors.append(c)

	var one = all_sectors[0]
	var two = all_sectors[1]

	one.is_closed = false
	one.owner_team = 0
	one.questions_used = 1
	await create_timer(0.2).timeout
	check(one._pending_dot_blink != null and one._pending_dot_blink.is_valid(), "second-chance dot blinks while the sector is open")

	one.close_cell(2)
	await create_timer(1.6).timeout
	check(one.lock_sprite.texture == one.red_lock_texture, "lock survives longer than a full blink cycle")
	check(not (one._pending_dot_blink != null and one._pending_dot_blink.is_valid()), "blink stops once the sector closes")

	two.is_closed = false
	two.owner_team = 0
	two.questions_used = 1
	await create_timer(0.2).timeout
	two.mark_as_team(1, Color.WHITE)
	await create_timer(1.6).timeout
	check(not two.lock_sprite.visible, "blink leaves no marker once a team owns the sector")
	check(one.lock_sprite.texture == one.red_lock_texture, "one sector blinking never disturbs another sector lock")

	print("RESULT: ", "FAIL" if failed else "PASS", " — lock colors verified on ", count, " sectors")
	quit(1 if failed else 0)
