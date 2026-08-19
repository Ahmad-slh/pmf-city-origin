extends Control

var current_cell = null
var board = null

@onready var content_box: VBoxContainer = $ContentBox
@onready var dark_overlay: ColorRect = $DarkOverlay
@onready var battle_effect: TextureRect = $BattleEffect
@onready var battle_card: TextureRect = $BattleCard

@onready var title_label: Label = $ContentBox/TitleLabel
@onready var message_label: Label = $ContentBox/MessageLabel
@onready var battle_teams_label: Label = $ContentBox/BattleTeamsLabel
@onready var attacker_button: Button = $ContentBox/HBoxContainer/AttackerButton
@onready var defender_button: Button = $ContentBox/HBoxContainer/DefenderButton
@onready var battle_flash: ColorRect = $BattleFlash
@onready var battle_result_label: Label = $ContentBox/BattleResultLabel

@onready var battle_start_sound: AudioStreamPlayer = $BattleStartSound
@onready var battle_lose_sound: AudioStreamPlayer = $BattleLoseSound
@onready var battle_win_sound: AudioStreamPlayer = $BattleWinSound

@onready var button_row: HBoxContainer = $ContentBox/HBoxContainer

# تسلسل اختيار المجيب في المعركة:
# الضغطة الأولى تفتح السؤال، والضغطات التالية تحوّل حق الإجابة للفريق الآخر
var battle_question_open := false

# قيم التخطيط الأصلية للنافذة، تُلتقط في _ready وتُستعاد بعد الشريط المصغّر
var _home_layer: int = 2
var _cb_home_anchor_top: float
var _cb_home_anchor_bottom: float
var _cb_home_offset_top: float
var _cb_home_offset_bottom: float


func _ready() -> void:
	visible = false
	dark_overlay.modulate.a = 0.0
	battle_flash.modulate.a = 0.0
	battle_effect_original_position = battle_effect.position

	# التقاط قيم التخطيط الأصلية لاستعادتها بعد الخروج من الشريط المصغّر
	var cl := get_parent()
	if cl is CanvasLayer:
		_home_layer = (cl as CanvasLayer).layer

	_cb_home_anchor_top = content_box.anchor_top
	_cb_home_anchor_bottom = content_box.anchor_bottom
	_cb_home_offset_top = content_box.offset_top
	_cb_home_offset_bottom = content_box.offset_bottom


var attacker_team_id: int = 0
var defender_team_id: int = 0
var battle_effect_original_position: Vector2

func show_battle(cell, p_attacker_team_id: int, p_defender_team_id: int, board_ref, team_must_begin_battle: int) -> void:
	current_cell = cell
	attacker_team_id = p_attacker_team_id
	defender_team_id = p_defender_team_id
	board = board_ref

	# معركة جديدة تبدأ بالنافذة الكاملة وبدون سؤال مفتوح بعد
	battle_question_open = false
	_restore_full_layout()

	battle_result_label.visible = false
	battle_result_label.text = ""
	attacker_button.visible = true
	defender_button.visible = true
	
	#battle_effect.position = battle_effect.position
	
	visible = true
	#battle_start_sound.play()

	title_label.text = "معركة ⚔"
	message_label.text = "اختر من سيجيب على السؤال"

	battle_teams_label.text = get_team_name(attacker_team_id) + " وصل\n" + \
		"إلى قطاع " + get_team_name(defender_team_id) + "\n\n" + \
		get_team_icon(attacker_team_id) + "   VS   " + get_team_icon(defender_team_id)
	play_open_animation()
	begin_auto_bettle(current_cell, p_attacker_team_id, p_defender_team_id, board_ref, team_must_begin_battle)
	


func begin_auto_bettle(cell, p_attacker_team_id: int, p_defender_team_id: int, board_ref, team_must_begin_battle: int) -> void:
	
	GameManager.g_is_battle= true
	
	#if team_must_begin_battle==-1:
		#visible = false
		#board.SectorQuestionCard.show_battle_question(
				#current_cell,
				#board,
				#team_must_begin_battle,
				#attacker_team_id,
				#defender_team_id
			#)
		
	if team_must_begin_battle==1 or team_must_begin_battle==2: # الفريق الذي سيبدأ المعركة
		visible = false
		# إلغاء المؤقت صار داخل SectorQuestionCard._start_answer_timer
		# مربوطا بتأثير OPPONENT_ANSWERS_FIRST_NEXT_BATTLE نفسه،
		# حتى لا يلغى الوقت عن الفريقين معا
		var sector_woner=cell.owner_team	 # الفريق صاحب القطاع
		
		if sector_woner==1: # إذا كان الفريق الازرق
			
			board.SectorQuestionCard.show_battle_question(
				current_cell,
				board,
				team_must_begin_battle,
				attacker_team_id,
				defender_team_id
			)
		if sector_woner==2:
			board.SectorQuestionCard.show_battle_question(
				current_cell,
				board,
				team_must_begin_battle,
				attacker_team_id,
				defender_team_id
			)
		var remove_effect_from_team=1
		if team_must_begin_battle==1:
			remove_effect_from_team=2
			
		GameManagerHelper.remove_effect(remove_effect_from_team, GameManagerHelper.EffectType.OPPONENT_ANSWERS_FIRST_NEXT_BATTLE)

func _on_attacker_button_pressed() -> void:
	_select_answerer(attacker_team_id)


func _on_defender_button_pressed() -> void:
	_select_answerer(defender_team_id)


# ======================================================
# اسم الدالة: _select_answerer
# وظيفتها:
# الضغطة الأولى على أي زر تفتح سؤال المعركة للفريق المختار وتحوّل
# النافذة إلى شريط أزرار مصغّر فوق البطاقة. الضغطات التالية على زر
# الفريق الآخر تحوّل حق الإجابة إليه دون إعادة ضبط المؤقت، ما دام لم
# تُسجّل إجابة والوقت ما زال متبقيًا — وهذا هو مسار "تمرير الدور".
# ======================================================
func _select_answerer(team_id: int) -> void:
	if not battle_question_open:
		battle_question_open = true
		enter_redirect_mode()
		board.SectorQuestionCard.show_battle_question(
			current_cell,
			board,
			team_id,
			attacker_team_id,
			defender_team_id
		)
		return

	# سؤال المعركة مفتوح: نحوّل حق الإجابة للفريق الآخر ما لم تُسجّل
	# إجابة أو ينتهِ الوقت. المؤقت لا يُعاد ضبطه
	var card = board.SectorQuestionCard
	if card.answer_selected or card.time_left <= 0:
		return

	card.redirect_battle_answerer(team_id)


# ======================================================
# اسم الدالة: enter_redirect_mode
# وظيفتها:
# تصغير نافذة المعركة إلى صف الأزرار وحده فوق سؤال المعركة، حتى يستطيع
# المشرف تحويل حق الإجابة للفريق الآخر أثناء السؤال. بطاقة السؤال تُعرض
# على الطبقة 100، فنرفع طبقة النافذة فوقها، ونجعل الجذر يمرّر الضغط إلى
# مناطق الإجابة تحته بحيث تلتقطه الأزرار وحدها.
# ======================================================
func enter_redirect_mode() -> void:
	var cl := get_parent()
	if cl is CanvasLayer:
		(cl as CanvasLayer).layer = 110

	# الجذر وصف الأزرار يمرّران الضغط، والزران وحدهما يلتقطانه
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	button_row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# إخفاء كل عناصر النافذة عدا صف الأزرار حتى تظهر البطاقة تحتها
	dark_overlay.visible = false
	battle_flash.visible = false
	battle_effect.visible = false
	battle_card.visible = false
	title_label.visible = false
	message_label.visible = false
	battle_teams_label.visible = false
	battle_result_label.visible = false

	# نقل صف الأزرار إلى أعلى الشاشة حتى لا يغطي مناطق الإجابة
	# (مناطق الاختيار في البطاقة تبدأ عند نحو 55% من الارتفاع)
	content_box.anchor_top = 0.0
	content_box.anchor_bottom = 0.0
	content_box.offset_top = 30.0
	content_box.offset_bottom = 230.0

	attacker_button.visible = true
	defender_button.visible = true
	visible = true


# ======================================================
# اسم الدالة: close_battle_ui
# وظيفتها:
# إغلاق نافذة/شريط المعركة نهائيًا بعد حسم السؤال (إجابة أو انتهاء وقت)،
# وإعادة الطبقة والتخطيط إلى وضعهما الأصلي. تستدعى من SectorQuestionCard.
# ======================================================
func close_battle_ui() -> void:
	battle_question_open = false
	visible = false
	_restore_full_layout()


# ======================================================
# اسم الدالة: _restore_full_layout
# وظيفتها:
# استعادة الطبقة والضغط والعناصر وتخطيط صندوق المحتوى إلى وضع النافذة
# الكاملة، حتى تظهر المعركة التالية بشكلها الطبيعي.
# ======================================================
func _restore_full_layout() -> void:
	var cl := get_parent()
	if cl is CanvasLayer:
		(cl as CanvasLayer).layer = _home_layer

	mouse_filter = Control.MOUSE_FILTER_STOP
	button_row.mouse_filter = Control.MOUSE_FILTER_STOP

	dark_overlay.visible = true
	battle_flash.visible = true
	battle_effect.visible = true
	battle_card.visible = true
	title_label.visible = true
	message_label.visible = true
	battle_teams_label.visible = true

	content_box.anchor_top = _cb_home_anchor_top
	content_box.anchor_bottom = _cb_home_anchor_bottom
	content_box.offset_top = _cb_home_offset_top
	content_box.offset_bottom = _cb_home_offset_bottom
		
func get_team_name(team_id: int) -> String:
	if team_id == 1:
		return "الفريق الأزرق"
	elif team_id == 2:
		return "الفريق الأحمر"
	return "فريق غير معروف"


func get_team_icon(team_id: int) -> String:
	if team_id == 1:
		return "🔵"
	elif team_id == 2:
		return "🔴"
	return "⚪"

func play_open_animation() -> void:
	#battle_start_sound.play()
	visible = true
	
	battle_effect.position = battle_effect_original_position
	

	dark_overlay.modulate.a = 0.0
	battle_flash.modulate.a = 0.0

	battle_card.scale = Vector2(0.6, 0.6)
	content_box.scale = Vector2(0.6, 0.6)

	battle_card.pivot_offset = battle_card.size / 2
	content_box.pivot_offset = content_box.size / 2
	battle_effect.pivot_offset = battle_effect.size / 2

	var original_effect_position := battle_effect.position

	# 1) الخلفية السوداء + تكبير البطاقة
	var open_tween := create_tween()
	open_tween.set_parallel(true)

	open_tween.tween_property(dark_overlay, "modulate:a", 1.0, 0.35)

	open_tween.tween_property(battle_card, "scale", Vector2.ONE, 0.35)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	open_tween.tween_property(content_box, "scale", Vector2.ONE, 0.35)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	# 2) فلاش أحمر مستقل
	var flash_tween := create_tween()
	flash_tween.tween_property(battle_flash, "modulate:a", 0.45, 0.08)
	flash_tween.tween_property(battle_flash, "modulate:a", 0.0, 0.18)

	await open_tween.finished

	shake_battle_effect(original_effect_position)
	

func shake_battle_effect(original_position: Vector2) -> void:
	var shake := create_tween()

	shake.tween_property(battle_effect, "position", original_position + Vector2(14, 0), 0.04)
	shake.tween_property(battle_effect, "position", original_position + Vector2(-14, 0), 0.04)
	shake.tween_property(battle_effect, "position", original_position + Vector2(10, 0), 0.04)
	shake.tween_property(battle_effect, "position", original_position + Vector2(-10, 0), 0.04)
	shake.tween_property(battle_effect, "position", original_position, 0.04)

func show_battle_result(result_text: String, is_win: bool) -> void:
	battle_result_label.visible = true
	battle_result_label.text = result_text

	attacker_button.visible = false
	defender_button.visible = false

	if is_win:
		battle_result_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
	else:
		battle_result_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))

	battle_result_label.scale = Vector2(0.5, 0.5)

	var tween := create_tween()
	tween.tween_property(battle_result_label, "scale", Vector2.ONE, 0.25)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

func hide_buttons_only() -> void:
	attacker_button.visible = false
	defender_button.visible = false
	message_label.text = "جاري فتح سؤال المعركة..."		

func play_win_sound() -> void:
	battle_win_sound.play()	
	
func play_lose_sound()-> void:
	battle_lose_sound.play()
	
func play_battle_start_sound() -> void:
	battle_start_sound.play()	
	
