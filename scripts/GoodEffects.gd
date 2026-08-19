extends Node

func apply(effect_name: String, team_id: int, board = null, card_data: Dictionary = {}) -> void:
	match effect_name:
		"SECOND_CHANCE_BATTLE":
			#GameManager.opponent_answers_first_next_battle(team_id, card_data)
			second_chance_battle(team_id, card_data)
		
		"PROTECT_INVESTED_SECTOR":
			protect_invested_sector(team_id, card_data)

		"EXTRA_DICE_ROLL":
			extra_dice_roll(team_id, card_data)

		"CHOOSE_NEXT_DICE_NUMBER":
			choose_next_dice_number(team_id, card_data)

		"CONTROL_OPPONENT_DIRECTION":
			control_opponent_direction(team_id, card_data)

		"TEMPORARY_IMMUNITY":
			temporary_immunity(team_id, card_data)

		"IGNORE_NEXT_BAD_CARD":
			ignore_next_bad_card(team_id, card_data)

		"IGNORE_FIRST_SECTOR_LOSS_OR_PENALTY":
			ignore_first_sector_loss_or_penalty(team_id, card_data)

		"TRANSFER_PENALTY_TO_OPPONENT":
			transfer_penalty_to_opponent(team_id, card_data)

		"SWAP_GOOD_WITH_BAD_CARD":
			swap_good_with_bad_card(team_id, card_data)

		"ROLL_TWICE_CHOOSE_BEST":
			roll_twice_choose_best(team_id, card_data)
		
		"CHOOSE_NEXT_STARTING_TEAM":
			choose_next_starting_team(team_id, card_data)
		
		"DOUBLE_INVESTMENT_LOCK_SECTOR":
			can_double_invest_in_sector(team_id, card_data)
		
		"RECOVER_LOST_SECTOR":
			recover_lost_sector(team_id, card_data)
		
		"GOOD_BLOCK_INVESTMENT_NEXT_ROUND":
			good_block_invistment_next_round(team_id, card_data)

		_:
			print("Good effect not implemented: ", effect_name)


func second_chance_battle(team_id: int, card_data = null) -> void:
	print("GOOD: فرصة إضافية في المعركة للفريق ", team_id)
	GameManagerHelper.add_effect(
		team_id,
		GameManagerHelper.EffectType.SECOND_CHANCE_BATTLE,
		{
			"used": false,
			"card_data": card_data,
			"display_turns_left": 1000
		}
	)
func protect_invested_sector(team_id: int, card_data = null) -> void:
	#print("GOOD: فرصة إضافية في المعركة للفريق ", team_id)
	GameManagerHelper.add_effect(
		team_id,
		GameManagerHelper.EffectType.PROTECT_INVESTED_SECTOR,
		{
			"used": false,
			"card_data": card_data,
			"display_turns_left": 1000
		}
	)

# ======================================================
# اسم الدالة: extra_dice_roll
# وظيفتها:
# إعطاء الفريق رمية نرد إضافية مجانية
# ======================================================
func extra_dice_roll(team_id: int, card_data: Dictionary) -> void:
	
	var description := "الفريق حصل على فرصة إضافية لرمي حجر النرد والتحرك مرة أخرى"
	
	GameManagerHelper.add_effect(
		team_id,
		GameManagerHelper.EffectType.EXTRA_DICE_ROLL,
		{
			"used": false,
			"card_data": card_data,
			"display_turns_left": 1
		}
	)

# ======================================================
# اسم الدالة: _has_usable_good
# وظيفتها:
# هل يملك الفريق هذا التأثير الإيجابي، وهل يسمح له باستخدامه الآن؟
# بطاقة "تعطيل البطاقات المخزنة" تمنع الاستخدام دون حذف التأثير
# ======================================================
func _has_usable_good(team_id: int, effect_type: int) -> bool:
	if not can_use_stored_good_cards(team_id):
		return false

	return GameManagerHelper.has_effect(team_id, effect_type)


func use_extra_dice_roll(team_id: int)->bool:
	var good_extra_dice_roll
	good_extra_dice_roll=_has_usable_good(team_id,GameManagerHelper.EffectType.EXTRA_DICE_ROLL)
	if good_extra_dice_roll:
		GameManagerHelper.remove_effect(team_id,GameManagerHelper.EffectType.EXTRA_DICE_ROLL)
		return true
	return false
# ======================================================
# اسم الدالة: choose_dice_value_next_round
# وظيفتها:
# إضافة تأثير يسمح للفريق باختيار رقم حجر النرد
# في الجولة القادمة بدلاً من الرمي العشوائي
# ======================================================
func choose_next_dice_number(team_id: int, card_data: Dictionary) -> void:	
	GameManagerHelper.add_effect(
		team_id,
		GameManagerHelper.EffectType.CHOOSE_NEXT_DICE_NUMBER,
		{
			"card_data": card_data,
			"description": "الفريق سيختار رقم حجر النرد في الجولة القادمة",
			"display_turns_left": 10
		}
	)
	#GameManagerHelper.remove_effect(team_id,GameManagerHelper.EffectType.CHOOSE_NEXT_DICE_NUMBER)
	
func use_choose_next_dice_number(team_id: int)->bool:
	var temp
	temp=_has_usable_good(team_id,GameManagerHelper.EffectType.CHOOSE_NEXT_DICE_NUMBER)
	if temp:
		GameManagerHelper.remove_effect(team_id,GameManagerHelper.EffectType.CHOOSE_NEXT_DICE_NUMBER)
		return true
	return false

#---   تحكم بحركة الفريق المنافس (6)
func control_opponent_direction(team_id: int, card_data: Dictionary) -> void:	
	GameManagerHelper.add_effect(
		team_id,
		GameManagerHelper.EffectType.CONTROL_OPPONENT_DIRECTION,
		{
			"card_data": card_data,
			"description": "تحكم بحركة الفريق المنافس في الجولة القادمة",
			"display_turns_left": 2
		}
	)


#---  رميتان أفضل من واحدة (9)

var firstRoll:int=0
var secondRoll:int=0
var v_choose_first:int=0

func roll_twice_choose_best(team_id: int, card_data: Dictionary) -> void:	
	firstRoll=0
	secondRoll=0

	GameManagerHelper.add_effect(
		team_id,
		GameManagerHelper.EffectType.ROLL_TWICE_CHOOSE_BEST,
		{
			"card_data": card_data,
			"description": "رميتان أفضل من واحدة",
			"display_turns_left": 2000
		}
	)

func use_twice_choose_best(team_id: int)->bool:
	var temp
	temp=_has_usable_good(team_id,GameManagerHelper.EffectType.ROLL_TWICE_CHOOSE_BEST)
	if temp:
		#GameManagerHelper.remove_effect(team_id,GameManagerHelper.EffectType.ROLL_TWICE_CHOOSE_BEST)
		return true
	return false
	

signal  s_choose_next_starting_team
func choose_next_starting_team(team_id: int, card_data: Dictionary) -> void:	
	firstRoll=0
	secondRoll=0
	v_choose_first=0
	GameManagerHelper.add_effect(
		team_id,
		GameManagerHelper.EffectType.CHOOSE_NEXT_STARTING_TEAM,
		{
			"card_data": card_data,
			"description": "إختر من يبدأ اللعب في الجولة القادمة",
			"display_turns_left": 2000	
		}
	)
	s_choose_next_starting_team.emit(v_choose_first)	

func use_choose_next_starting_team(team_id: int)->bool:
	var temp
	temp=_has_usable_good(team_id,GameManagerHelper.EffectType.CHOOSE_NEXT_STARTING_TEAM)
	if temp:
		#GameManagerHelper.remove_effect(team_id,GameManagerHelper.EffectType.CHOOSE_NEXT_STARTING_TEAM)
		return true
	return false


	
func can_double_invest_in_sector(team_id: int, card_data: Dictionary) -> void:	
	firstRoll=0
	secondRoll=0
	GameManagerHelper.add_effect(
		team_id,
		GameManagerHelper.EffectType.DOUBLE_INVESTMENT_LOCK_SECTOR,
		{
			"card_data": card_data,
			"description": "الاستثمار مرتين في القطاع نفسه",
			"display_turns_left": 3
		}
	)	
func use_double_invest_in_sector(team_id: int)->bool:
	var temp
	temp=_has_usable_good(team_id,GameManagerHelper.EffectType.DOUBLE_INVESTMENT_LOCK_SECTOR)
	if temp:
		GameManagerHelper.remove_effect(team_id,GameManagerHelper.EffectType.DOUBLE_INVESTMENT_LOCK_SECTOR)
		return true
	return false


func recover_lost_sector(team_id: int, card_data: Dictionary) -> void:	
	firstRoll=0
	secondRoll=0
	GameManagerHelper.add_effect(
		team_id,
		GameManagerHelper.EffectType.RECOVER_LOST_SECTOR,
		{
			"card_data": card_data,
			"description": "إسترجاع قطاع فقد في معركة",
			"display_turns_left": 3
		}
	)	
	
func use_recover_lost_sector(team_id: int)->bool:
	var temp
	temp=_has_usable_good(team_id,GameManagerHelper.EffectType.RECOVER_LOST_SECTOR)
	if temp:
		#GameManagerHelper.remove_effect(team_id,GameManagerHelper.EffectType.RECOVER_LOST_SECTOR)
		return true
	return false

# إضافة تأثير منع الاستثمار إلى الفريق المنافس
func good_block_invistment_next_round(team_id: int, card_data: Dictionary) -> void:	
	GameManagerHelper.add_effect(
		team_id,
		GameManagerHelper.EffectType.GOOD_BLOCK_INVESTMENT_NEXT_ROUND,
		{
			"card_data": card_data,
			"description": "تعطيل الخصم",
			# التأثير مخزن على الفريق الساحب لكنه يعطل الخصم.
			# القيمة 1 تعني: ينتهي عند بداية دور الفريق الساحب القادم،
			# أي بعد أن يكون الخصم قد خسر دورا واحدا بالضبط
			"display_turns_left": 1
		}
	)	

func use_good_block_invistment_next_round(team_id: int)->bool:
	var temp
	temp=_has_usable_good(team_id,GameManagerHelper.EffectType.GOOD_BLOCK_INVESTMENT_NEXT_ROUND)
	if temp:
		#GameManagerHelper.remove_effect(team_id,GameManagerHelper.EffectType.RECOVER_LOST_SECTOR)
		return true
	return false	
# ======================================================
#   البطاقات التي كانت بلا تنفيذ
# ======================================================

# جيد - حصانة كاملة من البطاقات السيئة خلال الجولة القادمة.
# تبقى طوال المدة ولا تستهلك عند أول استخدام
func temporary_immunity(team_id: int, card_data: Dictionary = {}) -> void:
	GameManagerHelper.add_effect(
		team_id,
		GameManagerHelper.EffectType.TEMPORARY_IMMUNITY,
		{
			"card_data": card_data,
			"description": "حصانة: لا تؤثر أي بطاقة سلبية على الفريق هذه الجولة",
			"display_turns_left": 2
		}
	)


# جيد - تجاهل أول بطاقة سيئة قادمة، ثم ينتهي التأثير
func ignore_next_bad_card(team_id: int, card_data: Dictionary = {}) -> void:
	GameManagerHelper.add_effect(
		team_id,
		GameManagerHelper.EffectType.IGNORE_NEXT_BAD_CARD,
		{
			"card_data": card_data,
			"description": "سيتم تجاهل أول بطاقة حدث سيئة",
			"display_turns_left": 2
		}
	)


# جيد - تجاهل أول عقوبة أو أول خسارة قطاع، أيهما يقع أولا
func ignore_first_sector_loss_or_penalty(team_id: int, card_data: Dictionary = {}) -> void:
	GameManagerHelper.add_effect(
		team_id,
		GameManagerHelper.EffectType.IGNORE_FIRST_SECTOR_LOSS_OR_PENALTY,
		{
			"card_data": card_data,
			"description": "درع الحماية: سيتم تجاهل أول خسارة قطاع أو عقوبة",
			"display_turns_left": 200
		}
	)


# ======================================================
# اسم الدالة: transfer_penalty_to_opponent
# وظيفتها:
# التخلص من عقوبة مفروضة على الفريق ونقلها إلى الفريق المنافس.
# تختار أول عقوبة موجودة تلقائيا بدل أن يختارها اللاعب
# ======================================================
func transfer_penalty_to_opponent(team_id: int, card_data: Dictionary = {}) -> void:
	var other_team: int = GameManager.get_other_team_id(team_id)

	var penalty: int = GameManagerHelper.find_first_effect_of_category(
		team_id,
		GameManagerHelper.EffectCategory.BAD
	)

	if penalty == -1:
		print("لا توجد عقوبة على الفريق ", team_id, " لنقلها")
		return

	var penalty_name: String = GameManagerHelper.get_effect_name(penalty)
	GameManagerHelper.move_effect(team_id, other_team, penalty)

	GameManagerHelper.set_team_effect_data(
		other_team,
		penalty,
		_with_description(
			GameManagerHelper.get_team_effect_data(other_team, penalty),
			"انتقلت إليكم عقوبة (" + penalty_name + ") من الفريق الآخر"
		)
	)

	print("تم نقل العقوبة ", penalty_name, " من الفريق ", team_id, " إلى ", other_team)


# ======================================================
# اسم الدالة: swap_good_with_bad_card
# وظيفتها:
# مبادلة بطاقة جيدة لدى الخصم ببطاقة سيئة لدى الفريق.
# تختار أول بطاقة من كل نوع تلقائيا
# ======================================================
func swap_good_with_bad_card(team_id: int, card_data: Dictionary = {}) -> void:
	var other_team: int = GameManager.get_other_team_id(team_id)

	var their_good: int = GameManagerHelper.find_first_effect_of_category(
		other_team,
		GameManagerHelper.EffectCategory.GOOD
	)
	var my_bad: int = GameManagerHelper.find_first_effect_of_category(
		team_id,
		GameManagerHelper.EffectCategory.BAD
	)

	if their_good == -1 and my_bad == -1:
		print("لا توجد بطاقات للمبادلة")
		return

	if their_good != -1:
		GameManagerHelper.move_effect(other_team, team_id, their_good)

	if my_bad != -1:
		GameManagerHelper.move_effect(team_id, other_team, my_bad)

	print("تمت مبادلة البطاقات بين الفريقين ", team_id, " و ", other_team)


func _with_description(data: Dictionary, description: String) -> Dictionary:
	var copy: Dictionary = data.duplicate(true)
	copy["description"] = description
	return copy


# ======================================================
# اسم الدالة: can_use_stored_good_cards
# وظيفتها:
# هل يسمح للفريق باستخدام بطاقاته الإيجابية المخزنة؟
# بطاقة BLOCK_STORED_POSITIVE_CARDS_NEXT_ROUND تمنع ذلك مؤقتا
# ======================================================
func can_use_stored_good_cards(team_id: int) -> bool:
	return not GameManagerHelper.has_effect(
		team_id,
		GameManagerHelper.EffectType.BLOCK_STORED_POSITIVE_CARDS_NEXT_ROUND
	)
#
#
