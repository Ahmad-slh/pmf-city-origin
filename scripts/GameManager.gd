extends Node

signal turn_changed(team_id)
signal good_dice_choose_next_roll()
#signal signal_skip_turn_cleared(team_id)

var g_is_battle = false
var x_current_teem = "blue"
var g_team_clicks: int=0
var extra_turn_team: int = 0
signal street_event_finished(team_id)
enum Team  {
	BLUE = 1,
	GREEN = 2
}
var current_team: Team = Team.BLUE
var core_team: Team = Team.BLUE

var teams = { 
	Team.BLUE:{
		"name": "Blue Team",
		#"color": Color.BLUE,
		"player": null
	},
	Team.GREEN:{
		"name": "Green Team",
		#"color": Color.GREEN,
		"player": null
	}
}
# عدد كل الجولات في اللعبة
var total_rounds: int = 0

# عدد جولات كل فريق
var team_rounds := {
	1: 0, # الفريق الأزرق
	2: 0  # الفريق الأحمر
}

	
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass


# Players
func setup_players(player_blue, player_green) -> void:
	teams[1].player = player_blue
	teams[2].player = player_green
	
	player_blue.team_id = Team.BLUE
	player_green.team_id = Team.GREEN
	
	player_blue.team_name = "First Team"
	player_green.team_name = "Second Team"
	
	player_blue.team_clicks = 0
	player_green.team_clicks = 0
	
	player_blue.set_active_turn(true)
	player_green.set_active_turn(false)

	GameManagerHelper.setup_effects([
		Team.BLUE,
		Team.GREEN
	])	


func is_current_team(team_id: int) -> bool:
	return team_id == current_team

func get_other_team_id(team_id: int) -> int:
	if team_id == Team.BLUE:
		return Team.GREEN
	else:
		return Team.BLUE

#  -------------------------
#    --- اللعب مرتين يدخل في هذه الدالة
func handle_opponent_twice_effects() -> bool:

	var finished_team_id = current_team
	var other_team_id = get_other_team_id(finished_team_id)

	var opponent_twice_effects := [
		GameManagerHelper.EffectType.SKIP_NEXT_DICE_ROLL,
		GameManagerHelper.EffectType.OPPONENT_ROLLS_TWICE_BEFORE_YOU
	]

	for effect_type in opponent_twice_effects:

		if not GameManagerHelper.has_effect(other_team_id, effect_type):
			continue

		var effect_data = GameManagerHelper.get_team_effect_data(
			other_team_id,
			effect_type
		)

		var turns_done = effect_data.get("opponent_turns_done", 0)
		var turns_required = effect_data.get("opponent_turns_required", 2)

		turns_done += 1
		effect_data["opponent_turns_done"] = turns_done

		GameManagerHelper.set_team_effect_data(
			other_team_id,
			effect_type,
			effect_data
		)

		print("التأثير = ", effect_type)
		print("عدد أدوار الخصم = ", turns_done, "/", turns_required)

		if turns_done < turns_required:

			current_team = finished_team_id

			update_active_players()
			turn_changed.emit(current_team)

			return true

		GameManagerHelper.remove_effect(
			other_team_id,
			effect_type
		)

		return false

	return false	

# --------------------------------
func end_turn() -> void:
	
	GameManager.g_is_battle= false

	#var finished_team_id = current_team
	add_team_round(current_team)
	# حذف التأثيرات المؤقتة بعد أن يراها اللاعب خلال دوره
	#GameManagerHelper.reduce_temporary_effects(finished_team_id)
	
	if GoodEffects.use_choose_next_starting_team(current_team):
		return

	if GoodEffects.use_choose_next_dice_number(current_team):
		good_dice_choose_next_roll.emit()
		return
	
	if GoodEffects.use_twice_choose_best(current_team):
		return
		
	if GoodEffects.use_extra_dice_roll(current_team):
		return

	if handle_opponent_twice_effects():
		return
	current_team = get_other_team_id(current_team)
	update_active_players()
	turn_changed.emit(current_team)	
	
	

	
#-------------------------------------	
	
# ======================================================
# اسم الدالة: reset_for_new_game
# وظيفتها:
# تصفير كل حالة اللعبة قبل بدء مباراة جديدة.
#
# GameManager و GameManagerHelper كلاهما autoload، فهما يبقيان
# في الذاكرة بعد change_scene_to_file. بدون هذا التصفير تنتقل
# حالة المباراة السابقة (الفريق الحالي، الجولات، التأثيرات)
# إلى المباراة الجديدة في نفس الجلسة
# ======================================================
func reset_for_new_game() -> void:

	current_team = Team.BLUE
	core_team = Team.BLUE

	total_rounds = 0
	team_rounds = {
		1: 0,
		2: 0
	}

	g_is_battle = false
	extra_turn_team = 0
	g_team_clicks = 0

	GameManagerHelper.team_effects.clear()

	GameManagerHelper.effects_changed.emit(Team.BLUE)
	GameManagerHelper.effects_changed.emit(Team.GREEN)


# ======================================================
# اسم الدالة: set_active_turn_players
# وظيفتها:
# تفعيل لاعب الفريق صاحب الدور دون أي أثر جانبي.
#
# update_active_players تنقص عدادات التأثيرات المؤقتة، وهو
# سلوك مطلوب عند تبديل الأدوار لا عند تحديد البادئ في بداية
# المباراة، فنفصل الجزء البصري وحده هنا
# ======================================================
func set_active_turn_players() -> void:

	teams[Team.BLUE]["player"].set_active_turn(current_team == Team.BLUE)
	teams[Team.GREEN]["player"].set_active_turn(current_team == Team.GREEN)

	GameManagerHelper.effects_changed.emit(Team.BLUE)
	GameManagerHelper.effects_changed.emit(Team.GREEN)


func update_active_players() -> void:
	teams[Team.BLUE]["player"].set_active_turn(current_team == Team.BLUE)
	teams[Team.GREEN]["player"].set_active_turn(current_team == Team.GREEN)
	
	
	# ينقص عداد الجولات لصاحب الدور الجديد فقط.
	# current_team هنا هو الفريق الذي بدأ دوره للتو
	GameManagerHelper.reduce_temporary_effects(current_team)

	GameManagerHelper.effects_changed.emit(Team.BLUE)
	GameManagerHelper.effects_changed.emit(Team.GREEN)	

# ======================================================
# اسم الدالة: add_team_effect_by_name
# وظيفتها:
# إضافة تأثير للفريق انطلاقا من اسمه النصي.
#
# كانت إضافة التأثير معطلة داخل هذه الدالة، فكانت تبحث عن نوع
# التأثير ثم لا تفعل شيئا. أي بطاقة تمر من هنا كان أثرها يختفي تماما.
#
# display_turns_left = 2 يعني: يبقى التأثير فعالا خلال الجولة القادمة للفريق
# ======================================================
func add_team_effect_by_name(
	team_id: int,
	effect_name: String,
	card_data: Dictionary = {},
	display_turns_left: int = 2
) -> void:
	core_team=team_id
	var effect_type = GameManagerHelper.get_effect_type_from_name(effect_name)

	if effect_type == null:
		print("Effect name not found: ", effect_name)
		return

	GameManagerHelper.add_effect(
		team_id,
		effect_type,
		{
			"card_data": card_data,
			"display_turns_left": display_turns_left
		}
	)
#-------------------------------------------
# جيد - إعطاء دور إضافي
func give_extra_turn(team_id: int) -> void:
	#GameManagerHelper.add_effect(
		#team_id,
		#GameManagerHelper.EffectType.EXTRA_TURN
	#)
 
	print("تم إعطاء دور إضافي للفريق: ", team_id)
func has_extra_turn(team_id: int) -> bool:
	return GameManagerHelper.has_effect(
		team_id,
		GameManagerHelper.EffectType.EXTRA_TURN
	)
func clear_extra_turn(team_id: int) -> void:
	if has_extra_turn(team_id):
		GameManagerHelper.remove_effect(
			team_id,
			GameManagerHelper.EffectType.EXTRA_TURN
		)

		#print("تم إنهاء الدور الإضافي للفريق: ", team_id)
#----------------------------------			--
#   تخطي الدور
var skip_next_turn_team: int = 0
var skip_penalty_waiting_clear_team: int = 0
func skip_next_turn(team_id: int, card_data: Dictionary = {}) -> void:
	GameManagerHelper.add_effect(
		team_id,
		GameManagerHelper.EffectType.SKIP_NEXT_DICE_ROLL,
		{
			"opponent_turns_done": 0,
			"opponent_turns_required": 2,
			"card_data": card_data
		}
	)

	#print("تم تطبيق عقوبة تخطي رمية النرد على الفريق: ", team_id)
	
func should_skip_turn(team_id: int) -> bool:
	return GameManagerHelper.has_effect(
		team_id,
		GameManagerHelper.EffectType.SKIP_NEXT_DICE_ROLL
	)		
#func clear_skip_turn(team_id: int) -> void:
	#if should_skip_turn(team_id):
		#GameManagerHelper.remove_effect(
			#team_id,
			#GameManagerHelper.EffectType.SKIP_NEXT_DICE_ROLL
		#)
#
		#signal_skip_turn_cleared.emit(team_id)
		#print("تم إنهاء عقوبة تخطي الدور للفريق: ", team_id)
			

#-----------------------------------------------------------
 #  تجميد الفريق للجولة القادمة - 9
func freeze_team_next_round(team_id: int, card_data: Dictionary = {}) -> void:
	GameManagerHelper.add_effect(
		team_id,
		GameManagerHelper.EffectType.FREEZE_TEAM_NEXT_ROUND,
		{
			"card_data": card_data
		}
	)
	print("تم تجميد الفريق للجولة القادمة: ", team_id)
func is_team_frozen(team_id: int) -> bool:
	return GameManagerHelper.has_effect(
		team_id,
		GameManagerHelper.EffectType.FREEZE_TEAM_NEXT_ROUND
	)
func clear_team_freeze(team_id: int) -> void:
	GameManagerHelper.remove_effect(
		team_id,
		GameManagerHelper.EffectType.FREEZE_TEAM_NEXT_ROUND
	)
	print("تم إنهاء تجميد الفريق: ", team_id)

#-------------------------------------------------------
#   منع الاستثمار
# الفريق الممنوع من الاستثمار (2)
func block_investment_next_round(team_id: int, card_data: Dictionary = {}) -> void:
	GameManagerHelper.add_effect(
		team_id,
		GameManagerHelper.EffectType.BLOCK_INVESTMENT_NEXT_ROUND,
		{
			"used": false,
			"card_data": card_data,
			# الجولة القادمة فقط
			"display_turns_left": 2
		}
	)

# ==================================================
# دالة: منع الاستثمار في قطاع الطاقة لجولتين
# Function Name: block_energy_investment_two_rounds
#
# شرح:
# هذه الدالة تضيف تأثيرا مؤقتا على الفريق.
# التأثير يمنع الفريق من الاستثمار في قطاع الطاقة فقط.
# مدة التأثير جولتان، لذلك وضعنا display_turns_left = 3.
# دالة reduce_temporary_effects ستقوم بتخفيض هذا الرقم تلقائيا.
# ==================================================
func block_energy_investment_two_rounds(team_id: int, card_data: Dictionary = {}) -> void:
	GameManagerHelper.add_effect(
		team_id,
		GameManagerHelper.EffectType.BLOCK_ENERGY_INVESTMENT_TWO_ROUNDS,
		{
			"card_data": card_data,
			"sector_id":2,
			"sector_name": "Sector_10",
			"description": "يُمنع الفريق من الاستثمار في قطاع الطاقة لجولتين متتاليتين.",
			"display_turns_left": 3
		}
	)	
	# ==================================================
	 # التأثير يمنع الفريق من الاستثمار في قطاع التعليم فقط (14). 
func block_education_investment_two_rounds(team_id: int, card_data: Dictionary = {}) -> void:
	GameManagerHelper.add_effect(
		team_id,
		GameManagerHelper.EffectType.BLOCK_EDUCATION_INVESTMENT_TWO_ROUNDS,
		{
			"card_data": card_data,
			"sector_id":6,
			"sector_name": "Sector_06",
			"description": "يُمنع الفريق من الاستثمار في قطاع الجامعات لجولتين متتاليتين",
			"display_turns_left": 3
		}
	)
# -----------------------------------------
signal s_cancel_one_investment(team_id, card_data)
func cancel_one_investment(team_id: int, card_data: Dictionary = {}) -> void:
	# لا نضيف التأثير هنا لأننا لا نعرف اسم القطاع
	# فقط نطلب من board.gd تنفيذ إلغاء الاستثمار
	s_cancel_one_investment.emit(team_id, card_data)
	#GameManagerHelper.add_effect(
		#team_id,
		#GameManagerHelper.EffectType.CANCEL_ONE_INVESTMENT,
		#{
			#"card_data": card_data,
			#"sector_id":6,
			#"sector_name": "Sector_06",
			#"description": "xxxxxxxxxxxx00xxxxxxxxxxxx",
			#"display_turns_left": 3
		#}
		#)

# -----------------------------------------
#   TRANSFER_ONE_OWNED_SECTOR_TO_OPPONENT
signal s_transfer_sector_to_other_team(team_id, card_data)
func transfer_sector_to_other_team(team_id: int, card_data: Dictionary = {}) -> void:
	# لا نضيف التأثير هنا لأننا لا نعرف اسم القطاع
	# فقط نطلب من board.gd تنفيذ إلغاء الاستثمار
	s_transfer_sector_to_other_team.emit(team_id, card_data)	

#---------------------------------
func opponent_rolls_twice_before_you(team_id: int, card_data: Dictionary = {}) -> void:
	GameManagerHelper.add_effect(
		team_id,
		GameManagerHelper.EffectType.OPPONENT_ROLLS_TWICE_BEFORE_YOU,
		{
			"opponent_turns_done": 0,
			"opponent_turns_required": 2,
			"card_data": card_data
		}
	)

	print("تم تطبيق حدث: المنافس يلعب مرتين قبل الفريق: ", team_id)

#----------------------------------------------------
 # يمنع الفريق من دخول أي Battle في جولته القادمة (16)
func block_battle_next_round(team_id: int, card_data: Dictionary = {}) -> void:
	GameManagerHelper.add_effect(
		team_id,
		GameManagerHelper.EffectType.BLOCK_BATTLE_NEXT_ROUND,
		{
			"card_data": card_data,
			"description": "تراجع تصنيف: الفريق ممنوع من دخول أي معركة في الجولة القادمة",
			#"waiting_next_turn": true,
			# الجولة القادمة فقط
			"display_turns_left": 2
		}
	)
	
# الفريق الخصم يحدد مسار الحركة
 # في الجولة القادمة فقط - 10
#--------------------------------------
func opponent_controls_your_direction(team_id: int,	card_data: Dictionary = {}) -> void:
	GameManagerHelper.add_effect(
		team_id,
		GameManagerHelper.EffectType.OPPONENT_CONTROLS_YOUR_DIRECTION,
		{
			"used": false,
			"card_data": card_data,
			"display_turns_left": 2
		}
	)

# ==================================================
# إضافة تأثير:
# الخصم يجيب أولاً في المعركة القادمة - 1
# ==================================================
func opponent_answers_first_next_battle(team_id: int,card_data: Dictionary = {}) -> void:
	GameManagerHelper.add_effect(
		team_id,
		GameManagerHelper.EffectType.OPPONENT_ANSWERS_FIRST_NEXT_BATTLE,
		{
			"used": false,
			"card_data": card_data,
			"display_turns_left": 5000
		}
	)		
#--------------------
#     عدد الجولات
func add_team_round(team_id: int) -> void:
	if not team_rounds.has(team_id):
		team_rounds[team_id] = 0

	team_rounds[team_id] += 1
	total_rounds += 1

	
