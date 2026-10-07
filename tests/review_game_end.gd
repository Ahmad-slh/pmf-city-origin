extends SceneTree

var failed := false

func check(condition: bool, message: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + message)
	failed = failed or not condition

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var manager = root.get_node("GameManager")
	for scenario in ["all_closed", "neutral_draw", "time"]:
		manager.reset_for_new_game()
		var scene = load("res://scenes/board_background.tscn").instantiate()
		root.add_child(scene)
		await process_frame
		var sectors: Array = []
		for cell in scene.board.sectors.get_children():
			if cell.cell_type == cell.CellType.SECTOR:
				sectors.append(cell)
		check(sectors.size() == 14, "only the 14 sectors determine closure")
		if scenario == "time":
			scene.remaining_seconds = 1
			scene._on_game_timer_timeout()
			check(scene.remaining_seconds == 0, "timer reaches zero")
		else:
			for i in range(sectors.size() - 1):
				if scenario == "neutral_draw":
					sectors[i].close_neutral_cell()
				else:
					sectors[i].mark_as_team(1 if i < 8 else 2, Color.WHITE)
					sectors[i].close_cell(sectors[i].owner_team)
			await process_frame
			await process_frame
			check(not manager.game_finished, "one open sector keeps the match running")
			check(not scene.game_over_popup.visible, "result not shown prematurely")
			if scenario == "neutral_draw":
				sectors[-1].close_neutral_cell()
			else:
				sectors[-1].mark_as_team(2, Color.WHITE)
				sectors[-1].close_cell(2)
			await process_frame
			await process_frame
		check(manager.game_finished, scenario + ": match ends")
		check(scene.game_timer.is_stopped(), scenario + ": match clock stops")
		check(scene.game_over_popup.visible, scenario + ": result is visible")
		check(not scene.board.SectorQuestionCard.visible, scenario + ": question card is hidden")
		var current_team: int = manager.current_team
		var rounds: int = manager.total_rounds
		manager.end_turn()
		check(manager.current_team == current_team and manager.total_rounds == rounds, scenario + ": no further turns")
		if scenario == "all_closed":
			check(scene.game_over_popup.current_winner == 1, "8 blue vs 6 red selects blue winner")
		else:
			check(scene.game_over_popup.current_winner == 0, scenario + ": tie retains decisive-question flow")
		scene._on_game_timer_timeout()
		check(scene.game_timer.is_stopped(), scenario + ": repeated finish is harmless")
		if scenario == "neutral_draw":
			scene.game_over_popup._on_return_button_pressed()
			check(scene.board.BattlePopup.visible, "tie allows team selection after match ends")
			scene.board.BattlePopup.attacker_button.pressed.emit()
			check(scene.board.SectorQuestionCard.final_tie_breaker_mode, "decisive question opens after match ends")
			check(scene.board.SectorQuestionCard.timer_running, "decisive question timer still runs")
		scene.queue_free()
		await process_frame
	manager.reset_for_new_game()
	check(not manager.game_finished, "new match resets finish state")
	quit(1 if failed else 0)
