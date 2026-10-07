extends SceneTree

var failed := false

func check(condition: bool, message: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + message)
	failed = failed or not condition

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var board = load("res://scenes/board.tscn").instantiate()
	root.add_child(board)
	await process_frame
	var cells = get_nodes_in_group("board_sectors")
	var target = null
	var street = null
	for cell in cells:
		if cell.cell_type == cell.CellType.SECTOR and target == null:
			target = cell
		if cell.cell_type == cell.CellType.STREET and street == null:
			street = cell
	var helper = root.get_node("GameManagerHelper")
	var data = root.get_node("StreetCardsData")
	var card: Dictionary = {}
	for candidate in data.all_cards:
		if candidate.get("id") == 130:
			card = candidate
	check(card.get("effect") == "TRANSFER_ONE_OWNED_SECTOR_TO_OPPONENT", "card 130 requests transfer")
	for source_team in [1, 2]:
		for closed in [false, true]:
			for cell in cells:
				cell.owner_team = 0
				if cell.cell_type == cell.CellType.SECTOR:
					cell.reset_sector()
					if closed:
						cell.close_cell(0)
			street.owner_team = source_team
			target.mark_as_team(source_team, board.team_colors[source_team])
			target.questions_used = 2 if closed else 1
			if closed:
				target.close_cell(source_team)
			var other_team: int = 2 if source_team == 1 else 1
			root.get_node("BadEffects").apply(card["effect"], source_team, board, card)
			var prefix := "team %d, closed=%s: " % [source_team, closed]
			check(target.owner_team == other_team, prefix + "ownership moves to opponent")
			check(target.is_closed == closed, prefix + "open/closed state preserved")
			check(target.questions_used == (2 if closed else 1), prefix + "question progress preserved")
			check(target.sprite.texture == (target.red_texture if other_team == 2 else target.blue_texture), prefix + "sector color matches new owner")
			check(target.lock_sprite.visible == closed, prefix + "lock visibility preserved")
			if closed:
				check(target.lock_sprite.texture == (target.red_lock_texture if other_team == 2 else target.blue_lock_texture), prefix + "lock color matches new owner")
			check(street.owner_team == source_team, prefix + "streets unaffected")
			var effect_data: Dictionary = helper.get_team_effect_data(source_team, helper.EffectType.TRANSFER_ONE_OWNED_SECTOR_TO_OPPONENT)
			check(effect_data.get("sector_name", "").begins_with("قطاع"), prefix + "event uses actual sector name")
	for cell in cells:
		cell.owner_team = 0
	helper.remove_effect(1, helper.EffectType.TRANSFER_ONE_OWNED_SECTOR_TO_OPPONENT)
	board.apply_cancel_investment_for_other_team(1, card)
	check(not helper.has_effect(1, helper.EffectType.TRANSFER_ONE_OWNED_SECTOR_TO_OPPONENT), "no owned sector produces no false transfer")
	quit(1 if failed else 0)
