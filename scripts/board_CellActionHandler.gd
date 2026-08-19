# هذا الكود تابع ل Board Script 
## only used from Board Script

extends Node2D
var board: Node = null

var team_scores := {
	1: 0,
	2: 0
}

func setup(_board: Node) -> void:
	board = _board

func handle_cell(cell) -> void:
	
	
	GameManager.g_is_battle= false

	var team_id = GameManager.current_team
	var was_investment_blocked := false
	
	if GameManagerHelper.has_effect(
		team_id,
		GameManagerHelper.EffectType.IGNORE_FIRST_SECTOR_LOSS_OR_PENALTY
	):
		board.StreetCard.apply_card_effect(board)
	

		
	#if board != null and board.main_ui != null:
		#board.main_ui.hide_team_street_event(team_id)

	if cell.has_method("is_sector") and cell.is_sector():
		handle_sector(cell, was_investment_blocked)

	elif cell.has_method("is_street") and cell.is_street():
		handle_street(cell)
	

		
func handle_sector(cell, skip_investment: bool = false) -> void:
	var team_id = GameManager.current_team
	
	
	#if GameManagerHelper.has_effect(
		#team_id,
		#GameManagerHelper.EffectType.IGNORE_FIRST_SECTOR_LOSS_OR_PENALTY
	#):
		#board.StreetCard.apply_card_effect(board)
	
	var other_team=1
	if team_id==1:
		other_team=2
		
	
	
	if GameManagerHelper.has_effect(team_id, GameManagerHelper.EffectType.BLOCK_INVESTMENT_NEXT_ROUND):
		print("الفريق ", team_id, " ممنوع من الاستثمار هذه الجولة")
		GameManagerHelper.remove_effect(team_id, GameManagerHelper.EffectType.BLOCK_INVESTMENT_NEXT_ROUND)
		if board != null and board.main_ui != null:
			board.main_ui.refresh_team_effect_panel(team_id)
		GameManager.end_turn()
		return

	if cell.sector_id == 10 and  GameManagerHelper.has_effect(team_id, GameManagerHelper.EffectType.BLOCK_ENERGY_INVESTMENT_TWO_ROUNDS):
		print("الفريق ", team_id, " ممنوع من الاستثمار هذه الجولة في  قطاع الطاقة")
		if board != null and board.main_ui != null:
			board.main_ui.refresh_team_effect_panel(team_id)
		GameManager.end_turn()
		return		
	
	if (cell.sector_id == 6) \
		and  GameManagerHelper.has_effect(team_id, GameManagerHelper.EffectType.BLOCK_EDUCATION_INVESTMENT_TWO_ROUNDS):
		print("الفريق ", team_id, " ممنوع من الاستثمار هذه الجولة في  قطاع الجامعات")
		if board != null and board.main_ui != null:
			board.main_ui.refresh_team_effect_panel(team_id)
		GameManager.end_turn()
		return		
		


	if cell.is_closed:
		return
	

	## إذا القطاع مملوك لفريق آخر → تبدأ معركة
	if cell.owner_team > 0 and cell.owner_team != team_id:
		
		if GameManagerHelper.has_effect(team_id, GameManagerHelper.EffectType.BLOCK_BATTLE_NEXT_ROUND):
			#print("الفريق ", team_id, " ممنوع من دخول المعركة هذه الجولة")
			if board != null and board.main_ui != null:
				board.main_ui.refresh_team_effect_panel(team_id)
			GameManager.end_turn()
			return
		
		board.BattlePopup.play_battle_start_sound()
		await cell.shake_cell()
		await cell.flash_red()
		var team_must_begin_battle=-1
		var team1=GameManagerHelper.has_effect(1, GameManagerHelper.EffectType.OPPONENT_ANSWERS_FIRST_NEXT_BATTLE)
		var team2=GameManagerHelper.has_effect(2, GameManagerHelper.EffectType.OPPONENT_ANSWERS_FIRST_NEXT_BATTLE)
		if team1 or team2:
			if team1: # إذا كان الحظ السيء عند الفريق الازرق فالفريق الاحمر سيبدأ المعركة
				team_must_begin_battle=2
			else:
				team_must_begin_battle=1

		board.BattlePopup.show_battle(
			cell,
			team_id,
			cell.owner_team,
			board,
			team_must_begin_battle
		)
		return
	
	
	

	# بطاقة "تعطيل الخصم" تلغي الاستثمار الجديد فقط، لا المعارك.
	# كان هذا الفحص في أول الدالة فيمنع الفريق حتى من دخول معركة
	# على قطاع الخصم، وهو أوسع مما تنص عليه وثيقة البطاقات
	if GoodEffects.use_good_block_invistment_next_round(other_team):
		print("الفريق ", team_id, " ممنوع من الاستثمار بتأثير تعطيل الخصم")
		GameManager.end_turn()
		return

	if cell.questions_used < 2:
		board.SectorQuestionCard.show_sector_card(cell, board)
	else:
		print("CLOSE CELL FOR TEAM = ", GameManager.current_team)
		cell.close_cell(team_id)

func handle_street(cell) -> void:
	if cell.is_closed:
		return

	var card_data = StreetCardsData.get_random_event_card()
	
	
	cell.register_street_visit()

	board.StreetCard.show_street_card(card_data, cell, board)
		
func add_score(team_id: int, points: int) -> void:
	team_scores[team_id] += points
	
			

		

	
