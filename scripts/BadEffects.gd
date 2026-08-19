extends Node


func apply(effect_name: String, team_id: int, board = null, card_data: Dictionary = {}) -> void:
	#print("BAD APPLY CALLED")
	#print("EFFECT NAME = ", effect_name)
	#print("TEAM ID = ", team_id)

	match effect_name:
		"OPPONENT_ANSWERS_FIRST_NEXT_BATTLE": # 1
			GameManager.opponent_answers_first_next_battle(team_id, card_data)

		"BLOCK_INVESTMENT_NEXT_ROUND": # 2
			GameManager.block_investment_next_round(team_id, card_data)
			print("تم تطبيق حدث منع الاستثمار على الفريق: ", team_id)

		"CANCEL_ONE_INVESTMENT": # 3
			GameManager.cancel_one_investment(team_id, card_data)

		"BLOCK_POSITIVE_CARDS_NEXT_ROUND":
			block_positive_cards_next_round(team_id, board, card_data)

		"BLOCK_STORED_POSITIVE_CARDS_NEXT_ROUND":
			block_stored_positive_cards_next_round(team_id, card_data)

		"DISCARD_ONE_REWARD_OR_PROTECTION_CARD":
			discard_one_reward_or_protection_card(team_id, card_data)

		"SKIP_NEXT_DICE_ROLL": # 8
			skip_next_dice_roll(team_id, board, card_data)
			
		"OPPONENT_ROLLS_TWICE_BEFORE_YOU": # 7
			GameManager.opponent_rolls_twice_before_you(team_id, card_data)

		"FREEZE_TEAM_NEXT_ROUND":
			GameManager.freeze_team_next_round(team_id, card_data)
		
		"TRANSFER_ONE_OWNED_SECTOR_TO_OPPONENT":
			GameManager.transfer_sector_to_other_team(team_id, card_data)
	# حدث رقم 13
	# خلاف داخلي: منع الاستثمار في قطاع الطاقة لجولتين
	# Effect: BLOCK_ENERGY_INVESTMENT_TWO_ROUNDS
	# ==================================================
		"BLOCK_ENERGY_INVESTMENT_TWO_ROUNDS":
			GameManager.block_energy_investment_two_rounds(team_id, card_data)
		# حدث رقم 14
	# خلاف داخلي: منع الاستثمار في قطاع التعليم لجولتين		
		"BLOCK_EDUCATION_INVESTMENT_TWO_ROUNDS":
			GameManager.block_education_investment_two_rounds(team_id, card_data)
		# حدث رقم 16  منع دخول المعركة
		"BLOCK_BATTLE_NEXT_ROUND":
			GameManager.block_battle_next_round(team_id, card_data)
		# حدث رقم 10 التحكم بالاتجاهات
		"OPPONENT_CONTROLS_YOUR_DIRECTION":
			GameManager.opponent_controls_your_direction(team_id,card_data)
		
		_:
			print("Bad effect not implemented: ", effect_name)


func opponent_answers_first_next_battle(team_id: int, board = null) -> void:
	print("BAD: الخصم يجيب أولاً في المعركة القادمة ضد الفريق ", team_id)
	GameManager.add_team_effect_by_name(team_id, "OPPONENT_ANSWERS_FIRST_NEXT_BATTLE")


#func block_investment_next_round(team_id: int, board = null) -> void:
	#print("BAD: منع الاستثمار الجولة القادمة للفريق ", team_id)
	#GameManager.add_team_effect_by_name(team_id, "BLOCK_INVESTMENT_NEXT_ROUND")

# Effect Number: 2
#func block_investment_next_round(team_id: int, board = null, card_data: Dictionary = {}) -> void:
	#print("BLOCK_INVESTMENT_NEXT_ROUND Number 2")
	#if GameManager.should_skip_turn(team_id):
		#print("هذا الفريق عليه العقوبة مسبقًا، لن تتم إضافتها مرة ثانية")
		#return
	#GameManager.block_investment_next_round(team_id, card_data)
	#
 #Effect Number: 3
# يعود القطاع غير مملوك ومتاحًا للجميع.
#func cancel_one_investment(team_id: int, board = null, card_data: Dictionary = {}) -> void:
	#print("BAD: إلغاء استثمار واحد للفريق ", team_id) 
	#GameManager.cancel_one_investment(team_id, card_data)


func block_positive_cards_next_round(team_id: int, board = null, card_data: Dictionary = {}) -> void:
	print("BAD: منع استخدام البطاقات الإيجابية للفريق ", team_id)
	GameManager.add_team_effect_by_name(
		team_id,
		"BLOCK_POSITIVE_CARDS_NEXT_ROUND",
		card_data
	)

# Effect Number: 8 
# اسم الدالة بالعربي:
#تخطي رمية النرد القادمة
func skip_next_dice_roll(team_id: int, board = null, card_data: Dictionary = {}) -> void:
	print("BAD EFFECT EXECUTED Effect Number 8")
	print("TEAM = ", team_id)
	if GameManager.should_skip_turn(team_id):
		print("هذا الفريق عليه العقوبة مسبقًا، لن تتم إضافتها مرة ثانية")
		return
	GameManager.skip_next_turn(team_id, card_data)
	
#func skip_next_dice_roll(team_id: int, board = null) -> void:
	#print("BAD EFFECT EXECUTED")
	#print("TEAM = ", team_id)
	#GameManager.add_team_effect_by_name(team_id, "SKIP_NEXT_DICE_ROLL")

# Effect Number: 9
# تجميد الفريق الجولة القادمة
func freeze_team_next_round(team_id: int, board = null) -> void:
	print("BAD: تجميد الفريق الجولة القادمة ", team_id)
	#GameManager.add_team_effect_by_name(team_id, "FREEZE_TEAM_NEXT_ROUND")
	GameManager.freeze_team_next_round(team_id)


# ======================================================
# اسم الدالة: block_stored_positive_cards_next_round
# وظيفتها:
# منع الفريق من استخدام بطاقاته الإيجابية المخزنة في الجولة القادمة.
# التأثيرات تبقى في لوحة التحكم لكن لا يمكن تفعيلها
# ======================================================
func block_stored_positive_cards_next_round(team_id: int, card_data: Dictionary = {}) -> void:
	GameManagerHelper.add_effect(
		team_id,
		GameManagerHelper.EffectType.BLOCK_STORED_POSITIVE_CARDS_NEXT_ROUND,
		{
			"card_data": card_data,
			"description": "لا يمكن استخدام البطاقات الإيجابية المخزنة هذه الجولة",
			"display_turns_left": 2
		}
	)


# ======================================================
# اسم الدالة: discard_one_reward_or_protection_card
# وظيفتها:
# إلغاء إحدى بطاقات المكافأة أو الحماية المخزنة لدى الفريق.
# تختار أول بطاقة إيجابية تلقائيا بدل أن يختارها اللاعب
# ======================================================
func discard_one_reward_or_protection_card(team_id: int, card_data: Dictionary = {}) -> void:
	var reward: int = GameManagerHelper.find_first_effect_of_category(
		team_id,
		GameManagerHelper.EffectCategory.GOOD
	)

	if reward == -1:
		print("لا توجد بطاقة مكافأة أو حماية لدى الفريق ", team_id)
		return

	var reward_name: String = GameManagerHelper.get_effect_name(reward)
	GameManagerHelper.remove_effect(team_id, reward)

	print("تم إلغاء بطاقة (", reward_name, ") من الفريق ", team_id)


func opponent_controls_your_direction(team_id: int, board = null) -> void:
	print("BAD: الخصم يتحكم باتجاه حركة الفريق ", team_id)
	GameManager.add_team_effect_by_name(team_id, "OPPONENT_CONTROLS_YOUR_DIRECTION")


#func block_battle_next_round(team_id: int, board = null) -> void:
	#print("BAD: منع دخول المعركة الجولة القادمة للفريق ", team_id)
	#GameManager.add_team_effect_by_name(team_id, "BLOCK_BATTLE_NEXT_ROUND")
