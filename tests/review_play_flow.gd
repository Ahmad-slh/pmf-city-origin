extends SceneTree

var failed := false

func check(condition: bool, message: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + message)
	failed = failed or not condition

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var manager = root.get_node("GameManager")
	var good = root.get_node("GoodEffects")
	manager.has_rolled_this_turn = true
	good.firstRoll = 6
	good.secondRoll = 2
	good.v_choose_first = 1
	manager.reset_for_new_game()
	check(not manager.has_rolled_this_turn, "new match unlocks the dice after abandoning a rolled turn")
	check(good.firstRoll == 0 and good.secondRoll == 0 and good.v_choose_first == 0, "new match clears unfinished double-roll selection")
	var board = load("res://scenes/board.tscn").instantiate()
	root.add_child(board)
	await process_frame
	var card = board.SectorQuestionCard
	var cell = board.sectors_map[Vector2i.ZERO]
	manager.rearm_dice_roll()
	check(not board.is_dice_locked(), "fresh board accepts an ordinary roll")
	for correct in [true, false]:
		cell.questions_used = 0
		cell.is_closed = false
		cell.is_locked = 0
		cell.owner_team = -1
		manager.current_team = 1
		manager.g_is_battle = false
		card.show_sector_card(cell, board)
		check(card.visible and card.timer_running, "normal question opens with a running answer timer")
		card._resolve_answer(correct)
		check(cell.questions_used == 1, "normal answer consumes exactly one question")
		check(cell.owner_team == (1 if correct else -1), "normal answer ownership is correct")
		card._resolve_answer(correct)
		check(cell.questions_used == 1, "duplicate answer cannot consume another question")
		await create_timer(5.0).timeout
		check(card.info_close_button.visible, "answer flips to information with an exit button")
		card._on_close_button_pressed()
		check(not card.visible and manager.current_team == 2, "closing information advances to the red team")
	for answering_team in [1, 2]:
		for correct in [true, false]:
			cell.questions_used = 1
			cell.is_closed = false
			cell.is_locked = 0
			cell.owner_team = 2
			manager.current_team = 1
			board.BattlePopup.show_battle(cell, 1, 2, board, -1)
			board.BattlePopup._select_answerer(answering_team)
			check(card.battle_mode and card.battle_answering_team == answering_team, "battle question opens for selected team")
			card.time_left = 11.0
			board.BattlePopup._select_answerer(3 - answering_team)
			check(card.battle_answering_team == 3 - answering_team and card.time_left <= 11.0, "redirect preserves remaining answer time")
			var active_answerer: int = card.battle_answering_team
			card._resolve_answer(correct)
			# A wrong defender answer neutralizes the sector; it does not award it to the attacker.
			var winner: int = active_answerer if correct else (2 if active_answerer == 1 else -1)
			check(cell.owner_team == winner and cell.is_closed, "battle outcome closes sector for the correct winner")
			check(not board.BattlePopup.visible, "battle team selector closes after answer")
			await create_timer(5.0).timeout
			card._on_close_button_pressed()
			check(not board.is_dice_locked(), "battle completion releases dice input")
	cell.questions_used = 1
	cell.is_closed = false
	cell.is_locked = 0
	cell.owner_team = 2
	manager.current_team = 1
	board.BattlePopup.show_battle(cell, 1, 2, board, -1)
	board.BattlePopup._select_answerer(2)
	card.handle_time_out()
	check(cell.is_closed and cell.owner_team == -1, "battle timeout closes the sector neutrally")
	await create_timer(5.0).timeout
	card._on_close_button_pressed()
	check(not board.is_dice_locked(), "timeout completion releases dice input")
	board.queue_free()
	await process_frame
	print("RESULT: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
