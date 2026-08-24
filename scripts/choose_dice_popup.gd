extends CanvasLayer



@onready var choose_number_panel: Panel = $ChooseNumberPanel
@onready var two_rolls_panel: Panel = $TwoRollsPanel
@onready var choos_first: Panel = $ChoosFirst

@onready var button_1: Button = $ChooseNumberPanel/HBoxContainer/PopupDice/Button1
@onready var button_2: Button = $ChooseNumberPanel/HBoxContainer/PopupDice/Button2
@onready var button_3: Button = $ChooseNumberPanel/HBoxContainer/PopupDice/Button3
@onready var button_4: Button = $ChooseNumberPanel/HBoxContainer/PopupDice/Button4
@onready var button_5: Button = $ChooseNumberPanel/HBoxContainer/PopupDice/Button5
@onready var button_6: Button = $ChooseNumberPanel/HBoxContainer/PopupDice/Button6

@onready var button_10: Button = $TwoRollsPanel/HBoxContainer/PopupDice2/Button10
@onready var button_11: Button = $TwoRollsPanel/HBoxContainer/PopupDice2/Button11

@onready var button_20: Button = $ChoosFirst/HBoxContainer/PopupDice3/Button20
@onready var button_30: Button = $ChoosFirst/HBoxContainer/PopupDice3/Button30


# ======================================================
# إشارة ترسل الرقم الذي اختاره اللاعب
# ======================================================
signal dice_value_selected(value: int)


# نقطة تحرير واحدة مهما كان سبب إغلاق النافذة
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(GameManagerHelper):
			GameManagerHelper.pop_input_block(self)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# النافذة بأوضاعها الثلاثة تنتظر ضغطة اللاعب، فتقفل النرد.
	# التحرير يتم في NOTIFICATION_PREDELETE ليغطي مسارات
	# الإغلاق الثلاثة (_select_value و _select_two_rolls_value
	# و _select_choos_first) من مكان واحد
	GameManagerHelper.push_input_block(self, "choose_dice_popup")

	choose_number_panel.visible = false
	two_rolls_panel.visible = false
	choos_first.visible = false

	button_1.pressed.connect(func(): _select_value(1))
	button_2.pressed.connect(func(): _select_value(2))
	button_3.pressed.connect(func(): _select_value(3))
	button_4.pressed.connect(func(): _select_value(4))
	button_5.pressed.connect(func(): _select_value(5))
	button_6.pressed.connect(func(): _select_value(6))

	# أزرار ChoosFirst تُربط في show_choos_first وحدها.
	# كان الربط هنا أيضا وبقيم معكوسة (20←1 و 30←2)، فكان كل
	# ضغط ينفّذ _select_choos_first مرتين بقيمتين متناقضتين.
	# الترتيب الصحيح من صورة اللوحة: 20 اليسار = الأحمر (2)،
	# و 30 اليمين = الأزرق (1)

	center_panel()

# ======================================================
# اسم الدالة: _select_value
# وظيفتها:
# إرسال الرقم المختار إلى لوحة اللعب ثم إغلاق النافذة
# ======================================================
func _select_value(value: int) -> void:
	var team_id=GameManager.current_team
	dice_value_selected.emit(value)
	queue_free()


# ======================================================
# اسم الدالة: center_panel
# وظيفتها:
# وضع نافذة اختيار رقم حجر النرد في منتصف الشاشة
# مهما كان حجم الشاشة
# ======================================================
func center_panel() -> void:

	# حجم الشاشة
	var screen_size = get_viewport().get_visible_rect().size

	# حجم الـ Panel
	var panel_size = choose_number_panel.size
	var panel2_size = two_rolls_panel.size
	var panel3_size = choos_first.size

	# وضع كل لوحة في المنتصف بمقاسها هي.
	# كانت الأسطر الثلاثة تكتب على choose_number_panel نفسها،
	# فتنتهي بمقاس ChoosFirst، واللوحتان الأخريان لا تتوسطان أصلا
	choose_number_panel.position = (screen_size - panel_size) / 2
	two_rolls_panel.position = (screen_size - panel2_size) / 2
	choos_first.position = (screen_size - panel3_size) / 2

func show_choose_number() -> void:
	choose_number_panel.visible = true
	two_rolls_panel.visible = false
	choos_first.visible = false
	
func show_two_rolls(roll1:int, roll2:int) -> void:
	
	var team_id=GameManager.current_team
	
	choose_number_panel.visible = false
	two_rolls_panel.visible = true

	button_10.text = str(roll1)
	button_11.text = str(roll2)	
	button_10.pressed.connect(func(): _select_two_rolls_value(roll1))
	button_11.pressed.connect(func(): _select_two_rolls_value(roll2))

func _select_two_rolls_value(value: int) -> void:
	var team_id=GameManager.current_team

	GoodEffects.firstRoll=0
	GoodEffects.secondRoll=0
	GameManagerHelper.remove_effect(team_id,GameManagerHelper.EffectType.ROLL_TWICE_CHOOSE_BEST)
	GameManagerHelper._refresh_side_cotroll_panels(team_id)
	dice_value_selected.emit(value)
	queue_free()

func show_choos_first() -> void:
	
	choose_number_panel.visible = false
	two_rolls_panel.visible = false
	choos_first.visible = true
	
	button_20.pressed.connect(func(): _select_choos_first(2))
	button_30.pressed.connect(func(): _select_choos_first(1))

func _select_choos_first(value: int) -> void:	
	
	var team_id=GameManager.current_team
	

	

	GoodEffects.v_choose_first=value

	GameManagerHelper.remove_effect(team_id,GameManagerHelper.EffectType.CHOOSE_NEXT_STARTING_TEAM)
	GameManagerHelper._refresh_side_cotroll_panels(team_id)
	#dice_value_selected.emit(value)
	GameManager.current_team=value
	GameManager.update_active_players()
	queue_free()	
