extends CanvasLayer
@onready var panel: Panel = $TextureRect/Panel
@onready var timer_label: Label = $TextureRect/Panel/TimerLabel
@onready var v_box_container: VBoxContainer = $TextureRect/Panel/VBoxContainer
@onready var question_number_label: Label = $TextureRect/Panel/VBoxContainer/QuestionNumberLabel
@onready var sector_name_label: Label = $TextureRect/Panel/VBoxContainer/SectorNameLabel
@onready var question_text_label: Label = $TextureRect/Panel/VBoxContainer/QuestionTextLabel
@onready var result_label: Label = $TextureRect/Panel/VBoxContainer/ResultLabel

@onready var margin_container: MarginContainer = $TextureRect/Panel/MarginContainer
@onready var background_label: Label = $TextureRect/background_label


@onready var answers_container: VBoxContainer = $TextureRect/Panel/MarginContainer/AnswersContainer

@onready var answer_a_button: Button = $TextureRect/Panel/MarginContainer/AnswersContainer/AnswerAButton
@onready var answer_b_button: Button = $TextureRect/Panel/MarginContainer/AnswersContainer/AnswerBButton
@onready var answer_c_button: Button = $TextureRect/Panel/MarginContainer/AnswersContainer/AnswerCButton
@onready var answer_d_button: Button = $TextureRect/Panel/MarginContainer/AnswersContainer/AnswerDButton
@onready var close_button: Button = $TextureRect/CloseButton
# زر الإغلاق الظاهر على وجه المعلومة وحده، لا على وجه السؤال
@onready var info_close_button: Button = $TextureRect/InfoCloseButton
@onready var texture_rect: TextureRect = $TextureRect
@onready var choos_player_1: ColorRect = $ChoosPlayer1
@onready var choos_player_2: ColorRect = $ChoosPlayer2



var current_question = {}
var correct_answer: String = ""
var current_cell = null
var board = null
var answer_selected := false

var is_flipping: bool = false


var questions_data := {
	6: [
		{
			"text": "ما الهدف من إعداد الموازنة العامة؟",
			"a": "تنظيم الإيرادات والنفقات",
			"b": "زيادة عدد الموظفين فقط",
			"c": "إلغاء الضرائب",
			"d": "تقليل الخدمات",
			"correct": "a"
		},
		{
			"text": "من الجهات التي تتابع تنفيذ الموازنة؟",
			"a": "المدرسة",
			"b": "وزارة المالية",
			"c": "النادي الرياضي",
			"d": "المكتبة",
			"correct": "b"
		}
	]
}


# ======================================================
# مدة الإجابة على السؤال بالثواني.
# المصدر الوحيد للقيمة: كل من يضبط time_left يقرأ من هنا،
# فلا يمكن أن يبقى موضع على قيمة قديمة عند تغيير المدة
# ======================================================
const ANSWER_TIME_SECONDS := 40.0

var timer_running := false
var time_left := ANSWER_TIME_SECONDS


# كم ثانية تبقى نتيجة الإجابة معروضة قبل أن تنقلب البطاقة
# إلى وجه المعلومة. تستخدم في العرض النصي وعرض الصورة والمعركة معا
const RESULT_HOLD_SECONDS := 0.5


# ======================================================
# مناطق الضغط فوق صورة البطاقة
# ------------------------------------------------------
# بطاقات الأسئلة الجديدة ترسم السؤال والخيارات داخل الصورة نفسها،
# لذلك نضع أزرارًا شفافة فوق كل خيار بدل بناء الأزرار من نص.
#
# القياسات مأخوذة من فحص جميع بطاقات الأسئلة الأربع والعشرين:
# مركز دائرة الاختيار عند 82% من العرض تقريبًا، ومراكز الخيارات
# الثلاثة عند 59.5% و 67.5% و 75.7% من الارتفاع.
#
# مقاسات الصور غير متطابقة (ثمانية مقاسات مختلفة)، لذلك يتحرك مركز
# الدائرة بمقدار ±2.3% بين بطاقة وأخرى، أي نصف قطر الدائرة تقريبًا.
# لهذا تغطي منطقة الضغط صف الخيار كاملًا (الدائرة والنص معًا)
# وليس الدائرة وحدها، فيبقى الضغط صحيحًا في كل البطاقات
# مع هامش أمان لا يقل عن 1.7% من الارتفاع.
const OPTION_ZONE_LEFT := 0.04
const OPTION_ZONE_RIGHT := 0.96
const OPTION_ZONE_TOP := 0.554     # أعلى صف الخيار الأول
const OPTION_ZONE_HEIGHT := 0.081  # ارتفاع صف خيار واحد
const OPTION_ZONE_COUNT := 3

# للفحص فقط: اجعلها true لرسم إطار أحمر حول مناطق الضغط
const DEBUG_SHOW_OPTION_ZONES := false

# أزرار الخيارات الشفافة التي توضع فوق صورة البطاقة
var option_buttons: Array[Button] = []

# هل يعرض السؤال الحالي كصورة بطاقة أم كنص؟
var uses_card_image := false



func setup(_board) -> void:
	board = _board
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = false
	result_label.visible = false
	
	choos_player_1.visible= false
	choos_player_2.visible = false
	
	timer_running = false
	time_left = ANSWER_TIME_SECONDS
	

	
	#show()
	#layer = 100
	#close_button.pressed.connect(_on_close_button_pressed)
	
	#panel.size = Vector2(820, 500)
	#panel.position = (get_viewport().get_visible_rect().size - panel.size) / 2
	#label_decoration()

	answer_a_button.pressed.connect(func(): check_answer("a"))
	answer_b_button.pressed.connect(func(): check_answer("b"))
	answer_c_button.pressed.connect(func(): check_answer("c"))
	answer_d_button.pressed.connect(func(): check_answer("d"))


func _process(delta: float) -> void:
	if not visible:
		return

	# المزامنة تعمل في كل إطار، لا فقط أثناء عمل المؤقت،
	# حتى تظهر النتيجة بعد توقف المؤقت
	_sync_image_mode_overlay()

	# عرض القراءة قبل المعركة له عداده الخاص، ولا يمر بـ handle_time_out
	# لأن انتهاء وقت المعركة يجعل القطاع محايدًا
	if battle_preview_running:
		battle_preview_time_left -= delta
		timer_label.text = "📖 وقت القراءة: " + GameManagerHelper.format_mm_ss(int(ceil(max(battle_preview_time_left, 0.0))))
		if battle_preview_time_left <= 0:
			_finish_battle_preview()
		return

	if not timer_running:
		return

	time_left -= delta

	timer_label.text = GameManagerHelper.format_time_label(int(time_left))

	if time_left <= 0:
		timer_running = false
		handle_time_out()
		
# ======================================================
# طبقة المؤقت والنتيجة فوق بطاقات الصور
# ------------------------------------------------------
# TimerLabel ابن للوحة Panel، و ResultLabel حفيد لها،
# و _apply_question_visuals تخفي اللوحة كاملة في وضع الصورة
# (panel.visible = false)، فيختفي المؤقت والنتيجة معا.
#
# بدل نقل العقدتين من مكانهما، وهو ما يغير تخطيط الوضع النصي
# لأن ResultLabel عنصر داخل VBoxContainer، نضيف طبقة خفيفة فوق
# الصورة تعكس نص العقدتين الأصليتين كما هو.
# بهذا تبقى مواضع كتابة النتيجة السبعة عشر في هذا الملف دون تعديل،
# ويبقى الوضع النصي كما كان تماما.
#
# القياسات نسبة من ارتفاع البطاقة: نص البطاقات المرسوم يبدأ عند
# 0.1065 من الارتفاع في أضيق بطاقة، فتبقى الطبقة فوق هذا الحد.
# حافة البطاقة نفسها تتراوح بين 0.0016 و 0.1075، لذلك تحمل الطبقة
# خلفية معتمة خاصة بها لتبقى مقروءة سواء وقعت على بياض البطاقة
# أو على الفراغ الذي تظهر منه أرضية اللوحة
# ======================================================
# الشريط مختار بالقياس على البطاقات الست والعشرين:
# نص البطاقات المرسوم يبدأ عند 0.1065 من الارتفاع في أضيق بطاقة،
# فالشريط 0.056..0.098 يبقى فوق النص المرسوم في كل البطاقات.
# شريط أخفض كان يجلس داخل بياض البطاقة في حالات أكثر،
# لكنه يغطي نص السؤال في تسع بطاقات، والقراءة أهم
const OVERLAY_LEFT := 0.20
const OVERLAY_RIGHT := 0.80
const OVERLAY_TOP := 0.01
const OVERLAY_TIMER_BOTTOM := 0.098

# النتيجة تجلس مباشرة تحت المؤقت بدل أن تحل محله،
# حتى يبقى الوقت ظاهرا مع إشعار الإجابة في نفس المنطقة
const OVERLAY_RESULT_TOP := 0.104
const OVERLAY_RESULT_BOTTOM := 0.208

var _overlay_timer: Label = null
var _overlay_result: Label = null


# ======================================================
#   إشعار الفرصة الثانية في المعركة
# ------------------------------------------------------
# كان النص يمر عبر result_label فيظهر في طبقة النتيجة فوق البطاقة
# ويغطي نص السؤال أثناء إعادة المحاولة. نعرضه بدلا من ذلك في شريط
# أحمر على يسار الشاشة خارج البطاقة.
#
# الإشعار يظهر ما دام result_label يحمل هذا النص بالضبط، فيختفي في
# اللحظة نفسها التي كان يختفي فيها سابقا (عند استبدال النص بنتيجة
# الإجابة الثانية أو انتهاء الوقت)، دون أي مؤقت جديد.
#
# الإحداثيات بوحدات طبقة البطاقة (مقياسها 0.4): البطاقة تبدأ عند
# x=1220، أي 488 بكسل على شاشة عرضها 1500، والإشعار ينتهي عند
# x=1180 (472 بكسل) فيبقى بينه وبين البطاقة هامش
# ======================================================
const SECOND_CHANCE_TEXT := "❌ إجابة خاطئة\n✨ لديكم فرصة ثانية للإجابة مرة أخرى"

const SECOND_CHANCE_NOTICE_LEFT := 60.0
const SECOND_CHANCE_NOTICE_RIGHT := 1180.0
const SECOND_CHANCE_NOTICE_TOP := 900.0
const SECOND_CHANCE_NOTICE_BOTTOM := 1340.0

var _second_chance_notice: Label = null

# يمنع ظهور الطبقة على وجه المعلومة بعد قلب البطاقة
var _showing_info_side := false


func _make_overlay_label(font_size: int, top: float, bottom: float) -> Label:
	var label := Label.new()

	# مهم: الطبقة ترسم فوق مناطق الضغط، فيجب ألا تبتلع الضغطات
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.04, 0.09, 0.22))

	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.94)
	style.border_color = Color(0.11, 0.22, 0.45, 0.9)
	style.set_border_width_all(3)
	style.set_corner_radius_all(30)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	label.add_theme_stylebox_override("normal", style)

	label.anchor_left = OVERLAY_LEFT
	label.anchor_right = OVERLAY_RIGHT
	label.anchor_top = top
	label.anchor_bottom = bottom
	label.offset_left = 0.0
	label.offset_top = 0.0
	label.offset_right = 0.0
	label.offset_bottom = 0.0

	return label


func _ensure_image_mode_overlay() -> void:
	if _overlay_timer != null and is_instance_valid(_overlay_timer):
		return

	_overlay_timer = _make_overlay_label(58, OVERLAY_TOP, OVERLAY_TIMER_BOTTOM)
	_overlay_timer.name = "OverlayTimer"
	texture_rect.add_child(_overlay_timer)

	_overlay_result = _make_overlay_label(54, OVERLAY_RESULT_TOP, OVERLAY_RESULT_BOTTOM)
	_overlay_result.name = "OverlayResult"
	texture_rect.add_child(_overlay_result)


func _ensure_second_chance_notice() -> void:
	if _second_chance_notice != null and is_instance_valid(_second_chance_notice):
		return

	var label := Label.new()
	label.name = "SecondChanceNotice"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0.35, 0.0, 0.0))
	label.add_theme_constant_override("outline_size", 8)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.80, 0.10, 0.10, 0.95)
	style.border_color = Color(0.45, 0.0, 0.0, 1.0)
	style.set_border_width_all(8)
	style.set_corner_radius_all(40)
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	label.add_theme_stylebox_override("normal", style)

	# ابن مباشر لطبقة البطاقة، لا لصورة البطاقة، حتى لا يتحرك مع
	# حركة قلب البطاقة ولا يقع داخل حدودها
	label.position = Vector2(SECOND_CHANCE_NOTICE_LEFT, SECOND_CHANCE_NOTICE_TOP)
	label.size = Vector2(
		SECOND_CHANCE_NOTICE_RIGHT - SECOND_CHANCE_NOTICE_LEFT,
		SECOND_CHANCE_NOTICE_BOTTOM - SECOND_CHANCE_NOTICE_TOP
	)
	label.text = SECOND_CHANCE_TEXT
	label.visible = false
	add_child(label)
	_second_chance_notice = label


# ======================================================
# اسم الدالة: _sync_image_mode_overlay
# وظيفتها:
# نسخ نص المؤقت والنتيجة من العقدتين الأصليتين إلى الطبقة.
# تستدعى كل إطار، فتلتقط أي تغيير مهما كان مصدره
# ======================================================
func _sync_image_mode_overlay() -> void:
	_ensure_image_mode_overlay()
	_ensure_second_chance_notice()

	# إشعار الفرصة الثانية يذهب إلى الشريط الأحمر على اليسار بدل
	# البطاقة، في وضع الصورة والوضع النصي معا
	var show_second_chance: bool = result_label.visible \
		and result_label.text == SECOND_CHANCE_TEXT \
		and not _showing_info_side
	_second_chance_notice.visible = show_second_chance
	# في الوضع النصي نخفي النسخة داخل اللوحة بالشفافية فقط،
	# حتى لا يتغير تخطيط الخيارات تحتها
	result_label.self_modulate.a = 0.0 if show_second_chance else 1.0

	# الطبقة لوضع الصورة فقط، وليس على وجه المعلومة
	if not uses_card_image or _showing_info_side:
		_overlay_timer.visible = false
		_overlay_result.visible = false
		return

	var has_result: bool = result_label.visible and result_label.text != "" \
		and not show_second_chance

	# المؤقت يبقى ظاهرا، وإشعار النتيجة يظهر تحته مباشرة
	_overlay_timer.text = timer_label.text
	_overlay_timer.visible = timer_label.text != ""

	_overlay_result.text = result_label.text
	_overlay_result.visible = has_result

	# النتيجة تلون بالأخضر أو الأحمر في العقدة الأصلية، ننقل اللون كما هو
	_overlay_result.add_theme_color_override(
		"font_color",
		result_label.get_theme_color("font_color")
	)


# ======================================================
# اسم الدالة: _ensure_option_buttons
# وظيفتها:
# إنشاء أزرار الخيارات الشفافة مرة واحدة فقط.
# تضاف كآخر أبناء TextureRect حتى ترسم فوق صورة البطاقة
# وتستقبل الضغط قبل أي عنصر تحتها.
# ======================================================
func _ensure_option_buttons() -> void:
	if not option_buttons.is_empty():
		return

	for i in OPTION_ZONE_COUNT:
		var button := Button.new()
		button.name = "OptionZone%d" % i
		button.text = ""
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP

		# المنطقة شفافة تماما، فمؤشر اليد هو الدليل الوحيد
		# الذي يخبر اللاعب أنها قابلة للضغط
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		# لا نريد أي أثر بصري للزر: لا خلفية ولا إطار ولا تظليل عند المرور
		# كل الحالات بلا أثر بصري، ما عدا المرور بالفأرة
		for style_name in ["normal", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(style_name, _make_option_zone_style())

		button.add_theme_stylebox_override("hover", _make_option_zone_hover_style())

		# الموضع بالنسب المئوية حتى يتبع حجم البطاقة مهما تغير مقاس الصورة
		button.anchor_left = OPTION_ZONE_LEFT
		button.anchor_right = OPTION_ZONE_RIGHT
		button.anchor_top = OPTION_ZONE_TOP + i * OPTION_ZONE_HEIGHT
		button.anchor_bottom = OPTION_ZONE_TOP + (i + 1) * OPTION_ZONE_HEIGHT
		button.offset_left = 0.0
		button.offset_top = 0.0
		button.offset_right = 0.0
		button.offset_bottom = 0.0

		button.pressed.connect(_on_image_option_pressed.bind(i))

		texture_rect.add_child(button)
		option_buttons.append(button)


func _make_option_zone_style() -> StyleBox:
	if not DEBUG_SHOW_OPTION_ZONES:
		return StyleBoxEmpty.new()

	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 0, 0, 0.12)
	style.border_color = Color(1, 0, 0, 0.9)
	style.set_border_width_all(2)
	return style


# ======================================================
# اسم الدالة: _make_option_zone_hover_style
# وظيفتها:
# إبراز خفيف يظهر عند مرور الفأرة فوق صف الخيار.
#
# منطقة الضغط شفافة تماما، فلا شيء يؤكد للاعب أنه فوق خيار
# سوى شكل المؤشر. هذا الإبراز يضيف تأكيدا بصريا خفيفا
# دون أن يغطي رسم البطاقة.
#
# الإدخال يمنع ملامسة حواف الصف، ونصف قطر الزوايا يساوي
# نصف ارتفاع الصف بعد الإدخال، فيصير الشكل بيضاويا يشبه
# دائرة الاختيار المرسومة في البطاقة بدل مستطيل حاد.
#
# لا حاجة لحماية إضافية عند التعطيل: BaseButton يرسم نمط
# disabled ولا يدخل حالة hover أصلا وهو معطل
# ======================================================
# الإدخال الرأسي بسيط، فحدود الصف رأسيا قريبة من حدود المنطقة.
#
# الإدخال الأفقي أكبر بكثير: منطقة الضغط تمتد من 0.04 إلى 0.96 من
# عرض البطاقة، وهي أوسع من رسم البطاقة نفسه عمدا حتى يبقى الضغط
# مريحا. قياس البطاقات الست والعشرين يعطي أضيق رسم عند 0.0975
# من اليسار و 0.9064 من اليمين، فلو رسمنا الإبراز على كامل المنطقة
# لخرج عن حافة البطاقة وظهر فوق أرضية اللوحة.
# مئة بكسل من كل جهة تبقيه داخل الرسم في كل البطاقات
const OPTION_ZONE_HOVER_INSET_V := 12.0
const OPTION_ZONE_HOVER_INSET_H := 100.0


# ======================================================
# إبراز الإجابة الصحيحة بعد إجابة خاطئة
# ------------------------------------------------------
# مناطق الضغط شفافة بالكامل عمدا، فنمنح منطقة الإجابة
# الصحيحة وحدها نمطا أخضر مرئيا لمدة قصيرة، ثم نعيدها
# شفافة كما كانت قبل قلب البطاقة
# ======================================================
const CORRECT_HIGHLIGHT_SECONDS := 3.0

var _highlighted_zone: Button = null


func _make_correct_zone_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = Color(0.16, 0.68, 0.27, 0.45)
	style.border_color = Color(0.05, 0.45, 0.13, 0.95)
	style.set_border_width_all(4)

	# نفس إدخال نمط المرور حتى يبقى الإبراز داخل رسم البطاقة
	style.expand_margin_left = -OPTION_ZONE_HOVER_INSET_H
	style.expand_margin_right = -OPTION_ZONE_HOVER_INSET_H
	style.expand_margin_top = -OPTION_ZONE_HOVER_INSET_V
	style.expand_margin_bottom = -OPTION_ZONE_HOVER_INSET_V

	var card_height: float = texture_rect.size.y
	if card_height <= 0.0:
		card_height = 2059.0

	var row_height: float = card_height * OPTION_ZONE_HEIGHT
	var radius: int = int((row_height - OPTION_ZONE_HOVER_INSET_V * 2.0) * 0.5)
	style.set_corner_radius_all(max(radius, 8))

	return style


# يبرز منطقة الإجابة الصحيحة، ويرجع true إذا تم الإبراز فعلا
func _highlight_correct_option_zone() -> bool:
	if not uses_card_image:
		return false

	var correct_index: int = int(current_question.get("correct_index", -1))
	if correct_index < 0 or correct_index >= option_buttons.size():
		return false

	_highlighted_zone = option_buttons[correct_index]

	# الزر معطل بعد الإجابة، فنمط disabled هو الظاهر فعليا
	var style := _make_correct_zone_style()
	for style_name in ["normal", "pressed", "focus", "disabled", "hover"]:
		_highlighted_zone.add_theme_stylebox_override(style_name, style)

	return true


func _clear_correct_zone_highlight() -> void:
	if _highlighted_zone == null or not is_instance_valid(_highlighted_zone):
		_highlighted_zone = null
		return

	for style_name in ["normal", "pressed", "focus", "disabled"]:
		_highlighted_zone.add_theme_stylebox_override(
			style_name, _make_option_zone_style()
		)

	_highlighted_zone.add_theme_stylebox_override(
		"hover", _make_option_zone_hover_style()
	)

	_highlighted_zone = null


func _make_option_zone_hover_style() -> StyleBox:
	var style := StyleBoxFlat.new()

	# أبيض شفاف جدا، يقرأ كإضاءة خفيفة لا كصندوق
	style.bg_color = Color(1, 1, 1, 0.12)
	style.set_border_width_all(0)

	# إدخال من الجهات الأربع حتى لا يلامس الإبراز حدود الصف
	style.expand_margin_left = -OPTION_ZONE_HOVER_INSET_H
	style.expand_margin_right = -OPTION_ZONE_HOVER_INSET_H
	style.expand_margin_top = -OPTION_ZONE_HOVER_INSET_V
	style.expand_margin_bottom = -OPTION_ZONE_HOVER_INSET_V

	# ارتفاع الصف بإحداثيات البطاقة، مع قيمة احتياطية
	# إن استدعيت الدالة قبل أن يأخذ TextureRect قياسه
	var card_height: float = texture_rect.size.y
	if card_height <= 0.0:
		card_height = 2059.0

	var row_height: float = card_height * OPTION_ZONE_HEIGHT
	var radius: int = int((row_height - OPTION_ZONE_HOVER_INSET_V * 2.0) * 0.5)
	style.set_corner_radius_all(max(radius, 8))

	# ظل ناعم يعطي إحساس الارتفاع البسيط خلف الصف
	style.shadow_color = Color(0, 0, 0, 0.10)
	style.shadow_size = 10

	return style


# ======================================================
#   تلوين دائرة الخيار في البطاقات المصورة
# ------------------------------------------------------
# دوائر الاختيار مرسومة داخل صورة البطاقة نفسها، فلا توجد
# عقدة نلونها. ولا تصلح نسب مناطق الضغط لتحديد مكانها:
# قياس البطاقات الثماني والعشرين يعطي تنقلا لمركز الدائرة
# يبلغ 6.2% من العرض و 4.5% من الارتفاع، ونصف قطرها 3.5%
# من العرض فقط، أي أن الفرق بين بطاقة وأخرى يقارب ضعف نصف
# القطر. ولهذا السبب نفسه تغطي منطقة الضغط صف الخيار كاملا.
#
# لذلك نكتشف الدوائر من الصورة عند أول عرض لكل بطاقة:
# نفحص الجهة اليمنى من نصف البطاقة السفلي، ونعد كل بكسل
# بعيد عن الأبيض حبرا دون افتراض لون بعينه، فالبطاقات ليست
# بطابع واحد: منها الأزرق الداكن والبرتقالي والرمادي. ثم
# نجمع المكونات المتصلة ونقبل ما كانت إحاطته شبه مربعة
# ونسبة امتلائه تدل على حلقة مجوفة لا كتلة مصمتة.
#
# النتيجة تخزن بمفتاح مسار الصورة، فالفحص يجري مرة واحدة
# لكل بطاقة مهما تكرر عرضها
# ======================================================
# النطاق مشتق من قياس البطاقات الثماني والعشرين: المركز بين
# 0.79 و 0.85 من العرض ونصف القطر 0.037 كحد أقصى، أي أن الحلقة
# تقع كلها بين 0.753 و 0.887. والهامش هنا أوسع من ذلك احتياطا.
# تضييق النطاق يستبعد عمود النص كله، فيقل عدد العينات والمكونات
const RING_SCAN_LEFT := 0.73
const RING_SCAN_RIGHT := 0.92
const RING_SCAN_TOP := 0.53
const RING_SCAN_BOTTOM := 0.83

# نفحص بكسلا من كل ثلاثة: قطر الحلقة نحو مئة بكسل فتبقى نحو
# ثلاث وثلاثين خانة، وهو تمثيل واف. جربت الخطوات 2 و3 و4 على
# البطاقات الثماني والعشرين فأعطت الثلاث النتيجة نفسها،
# واخترنا الوسطى: أسرع من 2 وأبقى هامشا لو رقّت حلقة بطاقة جديدة
const RING_SCAN_STRIDE := 3

# مجموع القنوات الثلاث دون هذا الحد يعد حبرا لا خلفية
const RING_INK_SUM_MAX := 660

# قطر الحلقة بين 0.066 و 0.074 من العرض في كل البطاقات، فحد
# أدنى عند 0.05 يستبعد الرسوم الصغيرة ويبقي الحلقات كلها
const RING_MIN_SIDE_RATIO := 0.05   # أصغر ضلع مقبول، نسبة من عرض الصورة
const RING_SQUARENESS_MAX := 0.22   # فرق الضلعين المسموح
const RING_FILL_MIN := 0.15         # أقل من هذا: خط رفيع لا حلقة
const RING_FILL_MAX := 0.70         # أكثر من هذا: كتلة مصمتة لا حلقة

# أخضر داكن عن قصد: عند الإجابة الخاطئة ترسم هذه الحلقة فوق
# شريط الإبراز الأخضر الفاتح، والأخضر الفاتح على الفاتح كانت
# نسبة تباينه 1.88 فقط. هذا الأخضر يعطي 5.13 فوق الشريط
# و 8.22 فوق أرضية البطاقة البيضاء، ويبقى أخضرا لا أسود
const RING_COLOR_CORRECT := Color(0.04, 0.36, 0.11)
const RING_COLOR_WRONG := Color(0.82, 0.18, 0.18)
const RING_FILL_ALPHA := 0.28
const RING_STROKE_RATIO := 0.22     # سمك الحلقة نسبة من نصف القطر

var _ring_cache := {}
var _ring_marks := {}
var _current_image_path := ""
var _option_ring_layer: Control = null


# ======================================================
# اسم الدالة: _detect_option_rings
# وظيفتها:
# مواضع دوائر الخيارات الثلاث في بطاقة بعينها، بالنسب.
# ترجع مصفوفة فارغة إذا لم تكتشف ثلاثا بالضبط، فيبقى
# الإبراز القديم على مستوى الصف هو الظاهر وحده
# ======================================================
func _detect_option_rings(image_path: String) -> Array:
	if _ring_cache.has(image_path):
		return _ring_cache[image_path]

	var found: Array = []
	var tex: Texture2D = load(image_path)

	if tex != null:
		var src: Image = tex.get_image()

		if src != null:
			# لا نعدل صورة المورد نفسها، فنعمل على نسخة
			var img := Image.new()
			img.copy_from(src)

			if img.is_compressed():
				img.decompress()

			found = _scan_option_rings(img)

	_ring_cache[image_path] = found
	return found


func _scan_option_rings(img: Image) -> Array:
	img.convert(Image.FORMAT_RGBA8)

	var img_w: int = img.get_width()
	var img_h: int = img.get_height()

	if img_w <= 0 or img_h <= 0:
		return []

	var x0: int = int(img_w * RING_SCAN_LEFT)
	var x1: int = int(img_w * RING_SCAN_RIGHT)
	var y0: int = int(img_h * RING_SCAN_TOP)
	var y1: int = int(img_h * RING_SCAN_BOTTOM)

	var cols: int = (x1 - x0) / RING_SCAN_STRIDE
	var rows: int = (y1 - y0) / RING_SCAN_STRIDE

	if cols <= 0 or rows <= 0:
		return []

	# قراءة البايتات مباشرة أسرع كثيرا من get_pixel لكل عينة
	var data: PackedByteArray = img.get_data()

	var ink := PackedByteArray()
	ink.resize(cols * rows)

	for ry in rows:
		var sy: int = y0 + ry * RING_SCAN_STRIDE
		var row_base: int = ry * cols
		var pixel_base: int = sy * img_w

		# الفهرس يتقدم بخطوة ثابتة، فنزيده بدل حسابه في كل دورة
		var idx: int = (pixel_base + x0) * 4
		var idx_step: int = RING_SCAN_STRIDE * 4

		for rx in cols:
			if data[idx] + data[idx + 1] + data[idx + 2] < RING_INK_SUM_MAX:
				ink[row_base + rx] = 1

			idx += idx_step

	var found: Array = _collect_ring_components(ink, cols, rows, img_w, img_h, x0, y0)

	# حلقات البطاقة الواحدة متطابقة الحجم، فأي شكل أصغر بوضوح
	# ليس منها. بطاقة "التخطيط المالي" فيها رسم صغير كان يمر من
	# باقي المرشحات ويجعل العدد أربعة فيسقط الاكتشاف كله
	if found.size() > OPTION_ZONE_COUNT:
		found = _keep_largest_ring_group(found)

	if found.size() != OPTION_ZONE_COUNT:
		return []

	found.sort_custom(func(a, b): return a["center"].y < b["center"].y)
	return found


# يبقي المرشحات التي تقارب أكبرها حجما، ويسقط ما دونها
func _keep_largest_ring_group(candidates: Array) -> Array:
	var widest: float = 0.0

	for c in candidates:
		widest = max(widest, c["radius"].x)

	var kept: Array = []

	for c in candidates:
		if c["radius"].x >= widest * 0.85:
			kept.append(c)

	return kept


# تجميع المكونات المتصلة في شبكة الحبر، وترشيح الحلقات منها
func _collect_ring_components(
	ink: PackedByteArray,
	cols: int,
	rows: int,
	img_w: int,
	img_h: int,
	x0: int,
	y0: int
) -> Array:
	var visited := PackedByteArray()
	visited.resize(cols * rows)

	var min_side: float = (img_w * RING_MIN_SIDE_RATIO) / float(RING_SCAN_STRIDE)
	var found: Array = []

	# كومة واحدة تكفي كل المكونات: PackedInt32Array لا تملك pop_back
	# فندير قمتها بأنفسنا، ونعيد استعمالها بدل تخصيص واحدة لكل مكون
	var stack := PackedInt32Array()
	stack.resize(cols * rows)

	for start in cols * rows:
		if ink[start] == 0 or visited[start] == 1:
			continue

		var top: int = 0
		stack[top] = start
		top += 1
		visited[start] = 1

		var count: int = 0
		var min_x: int = cols
		var max_x: int = -1
		var min_y: int = rows
		var max_y: int = -1

		while top > 0:
			top -= 1
			var cur: int = stack[top]
			var cur_y: int = cur / cols
			var cur_x: int = cur % cols

			count += 1
			min_x = min(min_x, cur_x)
			max_x = max(max_x, cur_x)
			min_y = min(min_y, cur_y)
			max_y = max(max_y, cur_y)

			# جوار رباعي يكفي: حلقة البطاقة خط متصل لا نقاط متفرقة،
			# وهو أرخص من الجوار الثماني بمقدار النصف
			if cur_x > 0:
				var left: int = cur - 1
				if ink[left] == 1 and visited[left] == 0:
					visited[left] = 1
					stack[top] = left
					top += 1

			if cur_x < cols - 1:
				var right: int = cur + 1
				if ink[right] == 1 and visited[right] == 0:
					visited[right] = 1
					stack[top] = right
					top += 1

			if cur_y > 0:
				var up: int = cur - cols
				if ink[up] == 1 and visited[up] == 0:
					visited[up] = 1
					stack[top] = up
					top += 1

			if cur_y < rows - 1:
				var down: int = cur + cols
				if ink[down] == 1 and visited[down] == 0:
					visited[down] = 1
					stack[top] = down
					top += 1

		var box_w: int = max_x - min_x + 1
		var box_h: int = max_y - min_y + 1

		if box_w < min_side or box_h < min_side:
			continue

		# الحلقة إحاطتها شبه مربعة، بخلاف النص الممتد أفقيا
		if abs(box_w - box_h) / float(max(box_w, box_h)) > RING_SQUARENESS_MAX:
			continue

		# ومجوفة: لا تملأ إحاطتها كما تفعل الكتلة المصمتة
		var fill: float = count / float(box_w * box_h)
		if fill < RING_FILL_MIN or fill > RING_FILL_MAX:
			continue

		var center_x: float = x0 + (min_x + max_x) * 0.5 * RING_SCAN_STRIDE
		var center_y: float = y0 + (min_y + max_y) * 0.5 * RING_SCAN_STRIDE

		found.append({
			"center": Vector2(center_x / img_w, center_y / img_h),
			"radius": Vector2(
				(box_w * 0.5 * RING_SCAN_STRIDE) / img_w,
				(box_h * 0.5 * RING_SCAN_STRIDE) / img_h
			)
		})

	return found


# ======================================================
# اسم الدالة: _ensure_option_ring_layer
# وظيفتها:
# طبقة الرسم فوق صورة البطاقة. تضاف بعد أزرار الخيارات
# حتى ترسم الحلقة فوق إبراز الصف الأخضر لا تحته، ولا
# تلتقط الفأرة فلا تحجب الضغط عن الأزرار تحتها
# ======================================================
func _ensure_option_ring_layer() -> void:
	if _option_ring_layer != null and is_instance_valid(_option_ring_layer):
		return

	var layer := Control.new()
	layer.name = "OptionRingLayer"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.draw.connect(_draw_option_rings)

	texture_rect.add_child(layer)
	_option_ring_layer = layer


func _draw_option_rings() -> void:
	if _ring_marks.is_empty():
		return

	if not uses_card_image or _showing_info_side:
		return

	var rings: Array = _detect_option_rings(_current_image_path)
	if rings.size() != OPTION_ZONE_COUNT:
		return

	var layer_size: Vector2 = _option_ring_layer.size

	for index in _ring_marks:
		if index < 0 or index >= rings.size():
			continue

		var ring: Dictionary = rings[index]
		var color: Color = _ring_marks[index]

		var center: Vector2 = ring["center"] * layer_size
		var radius: Vector2 = ring["radius"] * layer_size
		var stroke: float = max(radius.x * RING_STROKE_RATIO, 3.0)

		# تعبئة خفيفة داخل الحلقة، ثم الحلقة نفسها حول رسم البطاقة
		_draw_ring_shape(center, radius, Color(color, RING_FILL_ALPHA), true, 0.0)
		_draw_ring_shape(center, radius + Vector2(stroke, stroke) * 0.5, color, false, stroke)


# ======================================================
# اسم الدالة: _draw_ring_shape
# وظيفتها:
# رسم حلقة بيضاوية. صورة البطاقة تمدد أفقيا داخل TextureRect
# لأن نسبة الصورة تخالف نسبة العقدة، فالدائرة المرسومة في
# البطاقة تظهر بيضاوية. نمدد رسمنا بالقدر نفسه ليطابقها
# ======================================================
func _draw_ring_shape(
	center: Vector2,
	radius: Vector2,
	color: Color,
	filled: bool,
	width: float
) -> void:
	var unit: float = max(radius.y, 1.0)
	var stretch := Vector2(radius.x / unit, 1.0)

	_option_ring_layer.draw_set_transform(center, 0.0, stretch)

	if filled:
		_option_ring_layer.draw_circle(Vector2.ZERO, unit, color)
	else:
		_option_ring_layer.draw_arc(Vector2.ZERO, unit, 0.0, TAU, 64, color, width, true)

	_option_ring_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ======================================================
# اسم الدالة: _mark_option_rings
# وظيفتها:
# تلوين دائرة الخيار الذي ضغطه اللاعب، أخضر إن أصاب وأحمر
# إن أخطأ. واللون يحدد لحظة الضغط لأن الصواب معروف فورا
# من correct_index، فلا انتظار بين الضغط وظهور اللون.
#
# وعند الخطأ تلون دائرة الإجابة الصحيحة بالأخضر أيضا، مع
# بقاء إبراز الصف الأخضر كما هو
# ======================================================
func _mark_option_rings(picked_index: int, is_correct: bool) -> void:
	if not uses_card_image:
		return

	_ring_marks.clear()
	_ring_marks[picked_index] = RING_COLOR_CORRECT if is_correct else RING_COLOR_WRONG

	if not is_correct:
		var correct_index: int = int(current_question.get("correct_index", -1))
		if correct_index >= 0 and correct_index != picked_index:
			_ring_marks[correct_index] = RING_COLOR_CORRECT

	_ensure_option_ring_layer()
	_option_ring_layer.queue_redraw()


# تسخين مبكر للنتيجة المخزنة، تستدعى مؤجلة عند فتح البطاقة
func _warm_option_rings(image_path: String) -> void:
	_detect_option_rings(image_path)


func _clear_option_ring_marks() -> void:
	if _ring_marks.is_empty():
		return

	_ring_marks.clear()

	if _option_ring_layer != null and is_instance_valid(_option_ring_layer):
		_option_ring_layer.queue_redraw()


# ======================================================
# اسم الدالة: _set_option_zone_disabled
# وظيفتها:
# تغيير حالة منطقة الضغط وشكل المؤشر معا.
#
# الزر المعطل في Godot يبقى يلتقط الفأرة، لأن mouse_filter يظل STOP
# و BaseButton لا يغير شكل المؤشر عند التعطيل. فلو تركنا شكل اليد
# مثبتا لظهرت اليد فوق منطقة لا تقبل الضغط، مثل ما بعد اختيار
# الإجابة أو في العرض النصي. لذلك يمر كل تغيير للحالة من هنا
# ======================================================
func _set_option_zone_disabled(button: Button, is_disabled: bool) -> void:
	button.disabled = is_disabled

	if is_disabled:
		button.mouse_default_cursor_shape = Control.CURSOR_ARROW
	else:
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _set_option_zones_visible(zones_visible: bool) -> void:
	_ensure_option_buttons()

	for button in option_buttons:
		button.visible = zones_visible
		_set_option_zone_disabled(button, not zones_visible)


# ======================================================
# اسم الدالة: _on_image_option_pressed
# وظيفتها:
# الضغط على أحد خيارات صورة البطاقة.
# نقارن ترتيب الخيار مع correct_index المخزن مع السؤال
# ======================================================
func _on_image_option_pressed(option_index: int) -> void:
	var correct_index: int = int(current_question.get("correct_index", -1))
	var is_correct: bool = option_index == correct_index

	# اللون يظهر مع الضغط نفسه، لا بعد انتظار
	_mark_option_rings(option_index, is_correct)

	_resolve_answer(is_correct)


# ======================================================
# اسم الدالة: _apply_question_visuals
# وظيفتها:
# عرض السؤال كصورة بطاقة جاهزة إذا توفرت صورة للقطاع،
# وإلا يبقى العرض النصي القديم كما هو
# ======================================================
func _apply_question_visuals() -> void:
	var image_path: String = str(current_question.get("image", ""))
	uses_card_image = image_path != "" and ResourceLoader.exists(image_path)
	_current_image_path = image_path

	# سؤال جديد يعني العودة من وجه المعلومة إلى وجه السؤال
	_showing_info_side = false
	info_close_button.visible = false
	_clear_option_ring_marks()

	if uses_card_image:
		texture_rect.texture = load(image_path)

		# السؤال والخيارات مرسومة داخل الصورة، فلا حاجة للوحة النصوص
		panel.visible = false
		background_label.visible = false
		_set_option_zones_visible(true)

		# الاكتشاف يجري مرة واحدة لكل بطاقة، ويكلف عشرات المللي
		# ثانية. نؤجله إطارا فلا يعطل ظهور البطاقة، وينتهي قبل أن
		# يقرأ اللاعب السؤال، فلا يتأخر شيء لحظة الضغط
		_warm_option_rings.call_deferred(image_path)
		return

	# القطاعات التي لا تملك صور بطاقات بعد تبقى على العرض النصي
	panel.visible = true
	background_label.visible = false
	_set_option_zones_visible(false)
	_apply_text_mode_answer_layout()


# ======================================================
# إصلاح مؤقت لتخطيط الخيارات في وضع النص
# ------------------------------------------------------
# يخص القطاعات التي ما زالت بلا صورة بطاقة (5 و 12 حاليا).
# قالب البطاقة Blue01_F2.png مقاسه 1671x2059 وفيه ثلاث مناطق ثابتة
# قيست من الصورة نفسها:
#
#   الشخصية مع الغيوم :  x  421 .. 731
#   دوائر الاختيار     :  x 1309 .. 1409
#   مراكز الدوائر      :  y 1174.5 ، 1334.5 ، 1501
#
# صندوق الخيارات كان يمتد من x=699 إلى x=1307 بمقياس 3،
# أي يبدأ داخل رسمة الشخصية وينتهي فوق الدوائر تماما،
# فيركب النص على الرسمة وعلى الدوائر ويصبح غير مقروء.
# كما كان ارتفاع الصندوق 163 بينما أقل ارتفاع تحتاجه الصفوف 160،
# فلم يبق بين الصفوف أي فراغ تقريبا.
#
# الحل: ننقل الصندوق إلى الممر الفارغ بين الشخصية والدوائر،
# ونحاذي مراكز الصفوف مع مراكز الدوائر، ونلغي قص النص
# ونسمح بالالتفاف حتى تظهر الإجابات الطويلة كاملة.
#
# يطبق على وضع النص وحده: في وضع الصورة تكون اللوحة كلها مخفية
# (panel.visible = false) وتستخدم أزرار option_buttons فوق الصورة
# ======================================================

# حدود الممر الفارغ بين الشخصية والدوائر، بإحداثيات قالب البطاقة
const TEXT_MODE_BOX_LEFT := 760.0
const TEXT_MODE_BOX_RIGHT := 1285.0

# مركز أول دائرة، والمسافة بين مراكز الدوائر
const TEXT_MODE_FIRST_ROW_CENTER := 1174.5
const TEXT_MODE_ROW_PITCH := 163.25

const TEXT_MODE_ROW_HEIGHT := 120.0

# أطول إجابة في القطاعات النصية 81 حرفا. القياس 26 يجعلها تلتف
# في ثلاثة أسطر داخل ارتفاع الصف، فلا يتمدد الصف ويزيح بقية الصفوف
const TEXT_MODE_FONT_SIZE := 26


func _apply_text_mode_answer_layout() -> void:
	# المسافة بين الصفوف تشتق من المسافة بين الدوائر
	var row_spacing: float = TEXT_MODE_ROW_PITCH - TEXT_MODE_ROW_HEIGHT

	var box_width: float = TEXT_MODE_BOX_RIGHT - TEXT_MODE_BOX_LEFT
	var box_height: float = TEXT_MODE_ROW_HEIGHT * 3.0 + row_spacing * 2.0

	# أعلى الصندوق = مركز أول دائرة ناقص نصف ارتفاع الصف
	var box_top: float = TEXT_MODE_FIRST_ROW_CENTER - TEXT_MODE_ROW_HEIGHT * 0.5

	# المراسي متساوية المقابل هنا، لذلك ضبط size آمن ولا يطلق تحذيرا
	margin_container.scale = Vector2.ONE
	margin_container.set_anchors_preset(Control.PRESET_TOP_LEFT)

	# القالب يأتي بـ grow = BOTH، فلو تمدد الصندوق عن حجمه الأدنى
	# لانزاح نصف المقدار إلى الأعلى وفقد الصف الأول محاذاته مع دائرته.
	# التثبيت على END يبقي الزاوية العليا اليسرى في مكانها
	margin_container.grow_horizontal = Control.GROW_DIRECTION_END
	margin_container.grow_vertical = Control.GROW_DIRECTION_END

	# إحداثيات القالب تتحول إلى إحداثيات داخل اللوحة بطرح موضع اللوحة
	margin_container.position = \
		Vector2(TEXT_MODE_BOX_LEFT, box_top) - panel.position
	margin_container.size = Vector2(box_width, box_height)

	for margin_side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin_container.add_theme_constant_override(margin_side, 0)

	answers_container.size_flags_vertical = Control.SIZE_FILL
	answers_container.add_theme_constant_override("separation", int(row_spacing))

	for button in [answer_a_button, answer_b_button, answer_c_button]:
		button.custom_minimum_size = Vector2(0, TEXT_MODE_ROW_HEIGHT)
		button.add_theme_font_size_override("font_size", TEXT_MODE_FONT_SIZE)

		# الإجابات الطويلة كانت تقص فتتراكب حروفها، فنسمح بالالتفاف
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		button.clip_text = false

		# النص عربي، فيبدأ من اليمين قرب الدائرة
		button.alignment = HORIZONTAL_ALIGNMENT_RIGHT

		# الخلفية البيضاء في الأزرار B و C كانت تغطي جزءا من الرسمة
		button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())


func show_sector_question(cell, question_number: int) -> void:
	current_cell = cell
	
	reset_question_card()
	
	visible = true
	

	answer_selected = false
	timer_label.visible = true

	# enable_answer_buttons تستدعي _start_answer_timer التي تضبط
	# الوقت ونص المؤقت معا، فلا حاجة لتكرارهما هنا
	enable_answer_buttons()

	answer_a_button.disabled = false
	answer_b_button.disabled = false
	answer_c_button.disabled = false
	answer_d_button.disabled = false
	
	# أسئلة القطاعات مصدرها SectorQuestionsData وليس قائمة محلية،
	# حتى تظهر أسئلة كل القطاعات وليس قطاعاً واحداً فقط.
	var sector_data: Dictionary = SectorQuestionsData.sector_cards.get(cell.sector_id, {})
	var sector_questions: Array = sector_data.get("questions", [])

	if sector_questions.size() < question_number:
		question_text_label.text = "لا يوجد سؤال لهذا القطاع بعد"
		answer_a_button.visible = false
		answer_b_button.visible = false
		answer_c_button.visible = false
		answer_d_button.visible = false
		#result_label.text = ""
		result_label.visible = false
		return

	current_question = sector_questions[question_number - 1]
	correct_answer = current_question["correct"]

	sector_name_label.text = cell.sector_name
	question_number_label.text = "السؤال رقم " + str(question_number)
	question_text_label.text = current_question["question"]

	# البطاقات الجديدة فيها ثلاثة خيارات (A/B/C)، لذلك يُخفى أي زر بلا إجابة
	var answers: Dictionary = current_question.get("answers", {})

	answer_a_button.text = str(answers.get("A", ""))
	answer_b_button.text = str(answers.get("B", ""))
	answer_c_button.text = str(answers.get("C", ""))
	answer_d_button.text = str(answers.get("D", ""))

	answer_a_button.visible = answers.has("A")
	answer_b_button.visible = answers.has("B")
	answer_c_button.visible = answers.has("C")
	answer_d_button.visible = answers.has("D")
	

	
#
#func check_answer(answer_key: String) -> void:
	#if answer_selected:
		#return
#
	#answer_selected = true
	#timer_running = false
#
	#var team_id = GameManager.current_team
#
	#answer_key = answer_key.to_upper()
	#var correct_key = str(current_question["correct"]).to_upper()
#
	#result_label.visible = true
#
	#if answer_key == correct_key:
		#result_label.text = "✅ إجابة صحيحة"
		#result_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
#
		#current_cell.mark_as_team(team_id, board.team_colors[team_id])
		#board.board_cell_action_handler.add_score(team_id, 10)
	#else:
		#result_label.text = "❌ إجابة خاطئة"
		#result_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
#
	## مهم: زدّاد عدد الأسئلة المستخدمة بعد أي إجابة
	#current_cell.questions_used += 1
#
	#if current_cell.questions_used >= 2:
		#current_cell.close_cell(team_id)
#
	#hide_rolle_control()
	#disable_answer_buttons()

# ======================================================
# اسم الدالة: check_answer
# وظيفتها:
# فحص إجابة اللاعب
# ثم تحويل النتيجة إما للسؤال العادي أو للمعركة
# ======================================================
func check_answer(answer_key: String) -> void:
	var correct_key = str(current_question["correct"]).to_upper()
	_resolve_answer(answer_key.to_upper() == correct_key)



# ======================================================
# اسم الدالة: _resolve_answer
# وظيفتها:
# معالجة نتيجة الإجابة، سواء جاءت من زر نصي
# أو من الضغط على أحد خيارات صورة البطاقة
# ======================================================
func _resolve_answer(is_correct: bool) -> void:
	if answer_selected:
		return

	answer_selected = true
	timer_running = false

	result_label.visible = true

	if battle_mode:
		# فحص تأثير فرصة ثانية في دالة منفصلة
		if try_use_second_chance_battle(is_correct):
			return

		# سُجّلت إجابة نهائية: أغلق شريط اختيار المجيب فوق البطاقة
		if is_instance_valid(board) and board.BattlePopup != null:
			board.BattlePopup.close_battle_ui()

		handle_battle_answer(is_correct)
		disable_answer_buttons()
		hide_rolle_control()
		return

	disable_answer_buttons()
	hide_rolle_control()
	handle_normal_answer(is_correct)

# ======================================================
# اسم الدالة: try_use_second_chance_battle
# وظيفتها:
# فحص هل يمكن استخدام تأثير SECOND_CHANCE_BATTLE
#
# ترجع true:
# إذا تم استخدام التأثير، وبالتالي لا نكمل نتيجة المعركة الآن
#
# ترجع false:
# إذا لا يوجد تأثير أو تم استخدامه مسبقًا
# ======================================================
func try_use_second_chance_battle(is_correct: bool) -> bool:
	
	# التأثير يعمل فقط إذا كانت الإجابة خاطئة
	if is_correct:
		return false
	
	# البطاقات المخزنة قد تكون معطلة بعقوبة
	if not GoodEffects.can_use_stored_good_cards(battle_answering_team):
		return false

	# فحص هل الفريق الذي يجيب لديه تأثير فرصة ثانية
	var has_second_chance := GameManagerHelper.has_effect(
		battle_answering_team,
		GameManagerHelper.EffectType.SECOND_CHANCE_BATTLE
	)
	
	# إذا لا يوجد تأثير، نكمل الخسارة العادية
	if not has_second_chance:
		return false
	
	# إذا تم استخدام الفرصة الثانية سابقًا في نفس المعركة
	if second_chance_used:
		return false
	
	# الآن نستخدم التأثير
	second_chance_used = true
	
	# حذف التأثير لأنه يستخدم مرة واحدة فقط
	GameManagerHelper.remove_effect(
		battle_answering_team,
		GameManagerHelper.EffectType.SECOND_CHANCE_BATTLE
	)
	
	result_label.text = SECOND_CHANCE_TEXT
	result_label.add_theme_color_override(
		"font_color",
		Color(0.001, 0.001, 0.0, 1.0)
	)
	
	# _mark_option_rings لونت دائرة الإجابة الصحيحة بالأخضر لحظة الضغط،
	# وهذا يكشف الجواب قبل المحاولة الثانية. نزيل علامة الصحيحة ونبقي
	# الأحمر على اختيار الفريق. إن أخطأ مرة ثانية تعيد _mark_option_rings
	# رسم العلامات فتظهر الإجابة الصحيحة كالمعتاد
	_hide_correct_option_ring()

	# إعادة تفعيل الإجابة
	answer_selected = false
	#enable_answer_buttons()
	
	return true


func _hide_correct_option_ring() -> void:
	var correct_index: int = int(current_question.get("correct_index", -1))
	if not _ring_marks.has(correct_index):
		return

	_ring_marks.erase(correct_index)

	if _option_ring_layer != null and is_instance_valid(_option_ring_layer):
		_option_ring_layer.queue_redraw()
	
func handle_normal_answer(is_correct: bool) -> void:
	var team_id = GameManager.current_team

	current_cell.questions_used += 1
	
	if is_correct:
		# صوت الإجابة الصحيحة — المسار العادي فقط.
		# في المعركة يشتغل صوت فوز/خسارة القطاع بدلا منه
		Sfx.play(Sfx.Sound.ANSWER_CORRECT)
		result_label.text = "✅ إجابة صحيحة"
		result_label.add_theme_color_override("font_color", Color(0.0, 0.278, 0.005, 1.0))
				# تكبير الخط
		result_label.add_theme_font_size_override("font_size", 26)

		# جعل الخط أوضح وأعرض بصريًا
		result_label.add_theme_color_override(
			"font_outline_color",
			Color(0.0, 0.12, 0.0, 1.0)
		)
		result_label.add_theme_constant_override("outline_size", 1)

		current_cell.mark_as_team(team_id, board.team_colors[team_id])
		board.board_cell_action_handler.add_score(team_id, 10)
		
		if current_cell.questions_used >= 2:
			current_cell.close_cell(team_id)
	else:
		# صوت الإجابة الخاطئة — المسار العادي فقط
		Sfx.play(Sfx.Sound.ANSWER_WRONG)
		result_label.text = "❌ إجابة خاطئة"
		result_label.add_theme_color_override("font_color", Color(0.281, 0.0, 0.015, 1.0))

		# إجابة خاطئة فقط: أظهر للاعب أين كانت الإجابة الصحيحة
		_highlight_correct_option_zone()
		
				# تكبير الخط
		result_label.add_theme_font_size_override("font_size", 26)

		# جعل الخط أوضح وأعرض بصريًا
		result_label.add_theme_color_override(
			"font_outline_color",
			Color(0.281, 0.0, 0.015, 1.0)
		)
		result_label.add_theme_constant_override("outline_size", 1)

		if current_cell.questions_used >= 2:
			
			if v_use_double_invest_in_sector:
				v_use_double_invest_in_sector=false
				if current_cell.owner_team==1 || current_cell.owner_team==2:
					current_cell.close_cell(team_id)					
					return
			current_cell.close_cell(-1)


	#if current_cell.questions_used >= 2:
		#current_cell.close_cell(team_id)

func handle_battle_answer(is_correct: bool) -> void:
	
	current_cell.questions_used += 1
	if battle_answering_team == battle_attacker_team:
		handle_attacker_answer(is_correct)
	else:
		handle_defender_answer(is_correct)
				
func handle_attacker_answer(is_correct: bool) -> void:
	
	var team_id = GameManager.current_team

	
	if is_correct:
		result_label.text = "✅ إجابة صحيحة\nفاز المهاجم بالقطاع " #+" "+ "⚔️ انتصر المهاجم\nتم الاستيلاء على القطاع"
		result_label.add_theme_color_override("font_color", Color(0.0, 0.239, 0.004, 1.0))

		current_cell.owner_team = battle_attacker_team
		current_cell.close_cell(battle_attacker_team)
		board.board_cell_action_handler.add_score(battle_attacker_team, 10)
		board.BattlePopup.show_battle_result("⚔️ انتصر المهاجم\nتم الاستيلاء على القطاع", true)
		board.BattlePopup.play_win_sound()
	else:
		
		#var has_good_effect= GameManagerHelper.has_effect(team_id, GameManagerHelper.EffectType.SECOND_CHANCE_BATTLE)
		#if has_good_effect:
			#result_label.text = "❌ إجابة خاطئة\n   يرجى المحاولة مرى أخرى" #+ " " + "🛡️ نجح المدافع\nبقي القطاع مع المدافع"
		#else:
		result_label.text = "❌ إجابة خاطئة\nبقي القطاع مع المدافع" #+ " " + "🛡️ نجح المدافع\nبقي القطاع مع المدافع"
		result_label.add_theme_color_override("font_color", Color(0.313, 0.0, 0.019, 1.0))

		current_cell.owner_team = battle_defender_team
		current_cell.close_cell(battle_defender_team)
		board.BattlePopup.show_battle_result("🛡️ نجح المدافع\nبقي القطاع مع مالكه", false)
		board.BattlePopup.play_lose_sound()

func handle_defender_answer(is_correct: bool) -> void:
	var team_id = battle_defender_team
	
	if is_correct:
		result_label.text = "✅ إجابة صحيحة\nبقي القطاع مع المدافع" #+ " "+ "🛡️ نجح المدافع\nتمت حماية القطاع"
		result_label.add_theme_color_override("font_color", Color(0.0, 0.235, 0.004, 1.0))

		current_cell.owner_team = battle_defender_team
		current_cell.close_cell(battle_defender_team)
		board.board_cell_action_handler.add_score(battle_defender_team, 10)
		board.BattlePopup.show_battle_result("🛡️ نجح المدافع\nتمت حماية القطاع", true)
		board.BattlePopup.play_win_sound()
	else:
		if good_try_use_protect_invested_sector(team_id, is_correct):
			return
		result_label.text = "❌ إجابة خاطئة\nخسر المدافع القطاع وتم إغلاقه كقطاع محايد" #+" "+ "⚔️ فشل المدافع\nأصبح القطاع محايداً"
		result_label.add_theme_color_override("font_color", Color(0.371, 0.0, 0.026, 1.0))

		current_cell.owner_team = -1
		current_cell.close_neutral_cell()
		board.BattlePopup.show_battle_result("⚔️ فشل المدافع\nأصبح القطاع محايداً", false)						
		board.BattlePopup.play_lose_sound()


func good_try_use_protect_invested_sector(team_id: int, is_correct: bool) ->bool:
# ======================================================
# فحص تأثير حماية القطاع
# ======================================================

	# البطاقات المخزنة قد تكون معطلة بعقوبة، فلا تستخدم أي حماية
	if not GoodEffects.can_use_stored_good_cards(team_id):
		return false

	# "درع الحماية" يغطي أول خسارة قطاع كما يغطي العقوبات
	if GameManagerHelper.has_effect(
		team_id,
		GameManagerHelper.EffectType.IGNORE_FIRST_SECTOR_LOSS_OR_PENALTY
	):
		GameManagerHelper.remove_effect(
			team_id,
			GameManagerHelper.EffectType.IGNORE_FIRST_SECTOR_LOSS_OR_PENALTY
		)

		result_label.text = "🛡️ درع الحماية\nبقي القطاع مع المدافع"
		result_label.add_theme_color_override("font_color", Color(0.0, 0.213, 0.003, 1.0))

		current_cell.owner_team = battle_defender_team
		current_cell.close_cell(battle_defender_team)

		board.BattlePopup.show_battle_result(
			"🛡️ درع الحماية\nبقي القطاع مع مالكه",
			true
		)
		board.BattlePopup.play_win_sound()
		return true

	var has_protection := GameManagerHelper.has_effect(
		team_id,
		GameManagerHelper.EffectType.PROTECT_INVESTED_SECTOR
	)

	if has_protection:

		# حذف التأثير لأنه يستخدم مرة واحدة
		GameManagerHelper.remove_effect(
			team_id,
			GameManagerHelper.EffectType.PROTECT_INVESTED_SECTOR
		)

		result_label.text = "🛡️ تم استخدام بطاقة الحماية\nبقي القطاع مع المدافع"

		result_label.add_theme_color_override(
			"font_color",
			Color(0.0, 0.222, 0.003, 1.0)
		)

		current_cell.owner_team = battle_defender_team
		current_cell.close_cell(battle_defender_team)

		board.BattlePopup.show_battle_result(
			"🛡️ بطاقة الحماية\nبقي القطاع مع مالكه",
			true
		)

		board.BattlePopup.play_win_sound()
		return true
	
	return false
# ---   إنتهت دوال المعركة ---------	
		
func disable_answer_buttons() -> void:
	
	choos_player_1.visible=false
	choos_player_2.visible=false
	
	answer_a_button.disabled = true
	answer_b_button.disabled = true
	answer_c_button.disabled = true
	answer_d_button.disabled = true
	timer_running = false
	#answer_selected = false

	for button in option_buttons:
		_set_option_zone_disabled(button, true)
			
	
func hide_card() -> void:
	var team_id = GameManager.current_team
	
	choos_player_1.visible= false
	choos_player_2.visible = false
	
	timer_running = false
	result_label.text = ""
	result_label.visible = false
	
	#if current_cell.questions_used >= 2:
		#current_cell.close_cell(team_id)

	visible = false
	
	#current_board.StreetCard.apply_card_effect()
	
	GameManager.end_turn()
	
	
# ======================================================
# اسم الدالة: handle_time_out
# وظيفتها:
# انتهاء الوقت يعامل معاملة الإجابة الخاطئة تماما،
# فيمر بنفس مسار النتيجة بدل أن يعالج الأمر بنفسه.
#
# سابقا كانت هذه الدالة تتجاهل وضع المعركة كليا:
# تزيد عداد الأسئلة وتغلق القطاع لصالح صاحب الدور،
# فلا تحسم المعركة ولا تنتقل ملكية القطاع حسب قواعدها،
# وكان المدافع قد يخسر قطاعه بسبب وقت لم يكن هو من يجيب فيه.
#
# زيادة العداد وإغلاق القطاع تتم الآن داخل
# handle_normal_answer و handle_battle_answer، فلا نكررها هنا.
# ======================================================
func handle_time_out() -> void:
	if answer_selected:
		return

	# المعركة: انتهاء الوقت يجعل القطاع محايدًا دائمًا مهما كان الفريق
	# المختار للإجابة، عبر مسار مخصص لا يمر بتوجيه المهاجم/المدافع
	# ولا بفحص الفرصة الثانية (عدم الإجابة ليس إجابة خاطئة من فريق بعينه)
	if battle_mode:
		await _resolve_battle_timeout()
		return

	_resolve_answer(false)

	# نوضح أن السبب انتهاء الوقت وليس إجابة خاطئة
	result_label.text = "⏰ انتهى الوقت\n" + result_label.text

	# إذا منح تأثير الفرصة الثانية محاولة أخرى،
	# نبقي البطاقة مفتوحة ولا ننهي الدور
	if not answer_selected:
		return

	# هذا هو المسار الوحيد الذي يخفي البطاقة تلقائيا.
	# القلب صار ينتظر RESULT_HOLD_SECONDS، فلو بقي الإخفاء على 1.5
	# لاختفت البطاقة قبل أن تنقلب أصلا ولما رأى اللاعب وجه المعلومة.
	# نضيف المهلة نفسها ليبقى وجه المعلومة ظاهرا كما كان
	await get_tree().create_timer(RESULT_HOLD_SECONDS + 1.5).timeout
	hide_card()


# ======================================================
# اسم الدالة: _resolve_battle_timeout
# وظيفتها:
# انتهاء وقت سؤال المعركة. النتيجة واحدة دائمًا: يصبح القطاع محايدًا
# ويُقفل رماديًا، بغض النظر عن الفريق الذي كان يجيب لحظة انتهاء الوقت.
# لا يمر هذا المسار بتوجيه المهاجم/المدافع ولا بفحص الفرصة الثانية،
# لأن عدم الإجابة ليس إجابة خاطئة من فريق بعينه.
# ======================================================
func _resolve_battle_timeout() -> void:
	if answer_selected:
		return

	answer_selected = true
	timer_running = false

	disable_answer_buttons()

	# إغلاق شريط اختيار المجيب إن كان ظاهرًا فوق البطاقة
	if is_instance_valid(board) and board.BattlePopup != null:
		board.BattlePopup.close_battle_ui()

	current_cell.questions_used += 1

	# النتيجة واحدة دائمًا: القطاع يصبح محايدًا ويُقفل رماديًا
	current_cell.owner_team = -1
	current_cell.close_neutral_cell()

	result_label.visible = true
	result_label.text = "...⏰ انتهى الوقت\nأصبح القطاع محايدًا"
	result_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))

	board.BattlePopup.show_battle_result(".⚔️ انتهى الوقت\nأصبح القطاع محايدًا", false)
	board.BattlePopup.play_lose_sound()

	# قلب البطاقة إلى وجه المعلومة، ثم إخفاؤها وإنهاء الدور تلقائيًا
	# بنفس مهلة القراءة المستخدمة في بقية مسارات انتهاء الوقت
	hide_rolle_control()

	await get_tree().create_timer(RESULT_HOLD_SECONDS + 1.5).timeout
	#hide_card()


# ======================================================
# اسم الدالة: redirect_battle_answerer
# وظيفتها:
# تحويل حق الإجابة إلى الفريق الآخر أثناء سؤال المعركة نفسه، دون إعادة
# ضبط المؤقت ودون إعادة فتح البطاقة. يستدعى من BattlePopup عندما يضغط
# المشرف زر الفريق الآخر بعد أن بدأ فريق ولم يجب والوقت ما زال متبقيًا.
# ======================================================
func redirect_battle_answerer(new_team: int) -> void:
	# لا تحويل بعد تسجيل إجابة أو انتهاء الوقت
	if not battle_mode or answer_selected or time_left <= 0:
		return

	# لا حاجة للتحويل إذا كان الفريق نفسه يجيب أصلًا
	if new_team == battle_answering_team:
		return

	battle_answering_team = new_team

	if new_team == battle_attacker_team:
		question_number_label.text = "سؤال المعركة - المهاجم"
	else:
		question_number_label.text = "سؤال المعركة - المدافع"


var v_use_double_invest_in_sector=false
func _on_close_button_pressed() -> void:

	var team_id = GameManager.current_team

	# بطاقة "دعم إضافي" مشروطة في وثيقة البطاقات:
	# "في حال لم يكن القطاع مملوك للفريق المنافس".
	# نفحص الملكية قبل use_double_invest_in_sector لأنها تستهلك
	# التأثير، فلا نحرق البطاقة على قطاع لا تنطبق عليه
	v_use_double_invest_in_sector=false
	if current_cell.questions_used <= 1 \
		and _sector_allows_double_investment(team_id) \
		and not _sector_investment_blocked(team_id):
		if GoodEffects.use_double_invest_in_sector(team_id):
			v_use_double_invest_in_sector=true
			show_sector_card(current_cell, board)
			return

	hide_card()


# المنع الخاص بقطاع (الطاقة/الجامعات) يجب أن يقطع مسار "دعم إضافي"
# أيضا، وإلا صارت إعادة فتح البطاقة بابا خلفيا يلتف على الفحص.
# الفحص قبل use_double_invest_in_sector حتى لا تحرق البطاقة على
# قطاع ممنوع، تماما كفحص الملكية فوقه. عند المنع تكمل الدالة إلى
# hide_card، وهي تغلق البطاقة وتنهي الدور بنفسها
func _sector_investment_blocked(team_id: int) -> bool:
	if board == null or current_cell == null:
		return false

	var handler = board.board_cell_action_handler

	if handler == null:
		return false

	return handler.is_sector_investment_blocked(current_cell, team_id)


# القطاع متاح للاستثمار المزدوج إذا كان غير مملوك أو مملوكا لنفس الفريق
func _sector_allows_double_investment(team_id: int) -> bool:
	if current_cell == null:
		return false

	return current_cell.owner_team == OWNER_NONE or current_cell.owner_team == team_id


var current_board = null

func show_sector_card(cell, board_ref) -> void:
	
	reset_question_card()
	
	var team_id = GameManager.current_team
	current_cell = cell
	board = board_ref
	current_board = board_ref
	
	# ---  المعرك -----
	battle_mode = false
	battle_answering_team = 0
	battle_attacker_team = 0
	battle_defender_team = 0
   #----------------

	answers_container.visible = true
	background_label.visible = false
	background_label.text = ""
	result_label.visible = false
	result_label.text = ""
	answer_selected = false

	var sector_data: Dictionary = SectorQuestionsData.sector_cards.get(cell.sector_id, {})
	var questions: Array = sector_data.get("questions", [])

	var question_index: int = current_cell.questions_used

	# لم يعد للقطاع سؤال متاح، أو رقم القطاع غير موجود في بيانات الأسئلة.
	# الخروج الصامت هنا كان يترك البطاقة مخفية بلا إنهاء للدور فتتجمد اللوحة،
	# لذلك نغلق القطاع على مالكه الحالي وننهي الدور.
	if question_index < 0 or question_index >= questions.size():
		push_warning(
			"لا يوجد سؤال متاح للقطاع %s (questions_used=%d, عدد الأسئلة=%d)"
			% [str(cell.sector_id), question_index, questions.size()]
		)
		var owner_or_neutral: int = current_cell.owner_team if current_cell.owner_team > 0 else -1
		_close_exhausted_cell_and_end_turn(owner_or_neutral)
		return

	current_question = questions[question_index]

	sector_name_label.text = sector_data.get("topic", "")
	question_number_label.text = "السؤال " + str(question_index + 1) + " من 2"
	question_text_label.text = current_question["question"]

	answer_a_button.text = current_question["answers"]["A"]
	answer_b_button.text = current_question["answers"]["B"]
	answer_c_button.text = current_question["answers"]["C"]

	answer_d_button.visible = false

	# يعرض صورة البطاقة إن وجدت، وإلا يبقى العرض النصي
	_apply_question_visuals()

	visible = true
	show()
	layer = 100
	enable_answer_buttons()
		
func enable_answer_buttons() -> void:
	
	
	if GameManager.g_is_battle== false:
		_start_answer_timer()
	else:
		timer_running=false
		time_left = ANSWER_TIME_SECONDS
		
	
	answer_a_button.disabled = false
	answer_b_button.disabled = false
	answer_c_button.disabled = false
	answer_d_button.disabled = true
	answer_d_button.visible = false

	# مناطق الضغط تفعّل فقط عندما يعرض السؤال كصورة بطاقة
	for button in option_buttons:
		_set_option_zone_disabled(button, not uses_card_image)



# ======================================================
# اسم الدالة: _battle_answerer_has_no_time_limit
# وظيفتها:
# بطاقة "ما هذا الحظ السيّئ" تمنح الفريق المنافس حق الإجابة أولا
# "مع إلغاء قيود الوقت عليه" كما في وثيقة البطاقات.
# التأثير مخزن على الفريق المعاقب، فالمستفيد منه هو الفريق الآخر.
#
# سابقا كان الوقت يلغى بشكل عرضي عبر timer_running = false داخل
# BattlePopup، فيطبق على الفريقين معا. هنا نربطه بالتأثير نفسه
# ليقتصر على الفريق المستفيد فقط
# ======================================================
func _battle_answerer_has_no_time_limit() -> bool:
	if not battle_mode:
		return false

	if battle_answering_team != 1 and battle_answering_team != 2:
		return false

	var penalized_team: int = 1 if battle_answering_team == 2 else 2

	var has_effect= GameManagerHelper.has_effect(
		penalized_team,
		GameManagerHelper.EffectType.OPPONENT_ANSWERS_FIRST_NEXT_BATTLE
	)
	return has_effect


# ======================================================
# اسم الدالة: _start_answer_timer
# وظيفتها:
# المكان الوحيد الذي يشغل فيه مؤقت الإجابة. المدة نفسها
# في ANSWER_TIME_SECONDS، فلا تتكرر قيمتها في أكثر من موضع
# ======================================================
func _start_answer_timer() -> void:
	if _battle_answerer_has_no_time_limit():
		timer_running = false
		time_left = 0.0
		timer_label.text = "⏳ بلا حد زمني"
		return

	time_left = ANSWER_TIME_SECONDS
	timer_running = true

	timer_label.text = GameManagerHelper.format_time_label(int(time_left))


func hide_rolle_control() -> void:
	
	if is_flipping:
		return
	
	await flip_to_background_info()
	
	
	#answers_container.visible = false
	##disable_answer_buttons()
#
	#var sector_data = SectorQuestionsData.sector_cards[current_cell.sector_id]
#
	#background_label.visible = true
	#background_label.text = sector_data["background"]
#
	#background_label.add_theme_color_override(
	#"font_color",
	#Color(0.78, 0.54, 0.18))
	#background_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func prepare_background_info() -> void:
	var sector_data: Dictionary = \
		SectorQuestionsData.sector_cards[current_cell.sector_id]
	
	background_label.text = sector_data.get(
		"background",
		"لا توجد معلومة متوفرة لهذا القطاع."
	)
	
	background_label.add_theme_color_override(
		"font_color",
		Color(0.78, 0.54, 0.18)
	)
	
	background_label.autowrap_mode = \
		TextServer.AUTOWRAP_WORD_SMART
		
func show_info_side() -> void:
	# لا نحتاج مناطق الضغط بعد انتهاء الإجابة
	_set_option_zones_visible(false)

	# وجه المعلومة لا يعرض المؤقت ولا النتيجة ولا تلوين الدوائر
	_showing_info_side = true
	_clear_option_ring_marks()

	# الزر الوحيد الذي يغلق وجه المعلومة يدويا، ويمر بنفس مسار
	# _on_close_button_pressed المربوط بزر الإغلاق الأصلي
	info_close_button.visible = true

	var info_path: String = str(current_question.get("info_image", ""))

	# البطاقات التي لها صورة معلومات تعرضها كما هي بدل النص
	if uses_card_image and info_path != "" and ResourceLoader.exists(info_path):
		texture_rect.texture = load(info_path)
		panel.visible = false
		background_label.visible = false
		return

	prepare_background_info()

	var card_image="res://assets/images/QuastionCards/Blue01_F3.png"

	# تغيير صورة البطاقة إلى الوجه الثاني
	texture_rect.texture = load(
		card_image
	)

	#card_texture.texture = info_card_texture

	panel.visible = false
	background_label.visible = true

	#is_showing_info = true

func reset_question_card() -> void:
	
	info_close_button.visible = false
	choos_player_1.visible= false
	choos_player_2.visible = false
	is_flipping = false
	#is_showing_info = false
	
	
	#texture_rect.texture = question_card_texture
	
	
	var card_image="res://assets/images/QuastionCards/Blue01_F2.png"
		
	# تغيير صورة البطاقة إلى الوجه الثاني
	texture_rect.texture = load(
		card_image
	)
	
	
	texture_rect.scale = Vector2.ONE
	texture_rect.rotation_degrees = 0.0

	panel.visible = true
	background_label.visible = false

	background_label.text = ""

	# نبدأ من الوضع النصي، و _apply_question_visuals يفعّل الصورة إن وجدت
	uses_card_image = false
	_clear_correct_zone_highlight()
	_clear_option_ring_marks()
	_set_option_zones_visible(false)

	enable_answer_buttons()
	
func flip_to_background_info() -> void:
	if is_flipping:
		return

	is_flipping = true

	disable_answer_buttons()

	# ------------------------------------------------------
	# مهلة قراءة النتيجة
	# كل مسارات الإجابة تمر من _resolve_answer ثم hide_rolle_control
	# ثم هذه الدالة، سواء كان العرض نصيا أو صورة أو معركة.
	# سابقا كان القلب يبدأ فورا، فلا يبقى من علامة الصح أو الخطأ
	# سوى ربع ثانية، وهي مدة الحركة الأولى.
	# الانتظار هنا يغطي الأوضاع الثلاثة بنقطة واحدة
	# ------------------------------------------------------
	await get_tree().create_timer(RESULT_HOLD_SECONDS).timeout

	# إجابة خاطئة على بطاقة صورة: امنح اللاعب وقتا ليرى الإجابة
	# الصحيحة مبرزة قبل أن تنقلب البطاقة
	if _highlighted_zone != null:
		await get_tree().create_timer(CORRECT_HIGHLIGHT_SECONDS).timeout
		_clear_correct_zone_highlight()

	texture_rect.pivot_offset = texture_rect.size / 2.0
	
	# -------------------------------------------
	# المرحلة الأولى:
	# إغلاق وجه السؤال
	# -------------------------------------------
	var tween_1 := create_tween()
	
	tween_1.tween_property(
		texture_rect,
		"scale:x",
		0.0,
		0.25
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	await tween_1.finished
	
	# -------------------------------------------
	# البطاقة أصبحت في المنتصف
	# هنا نغير الصورة والمحتوى
	# -------------------------------------------
	show_info_side()
	
	texture_rect.scale.x = 0.0
	
	# -------------------------------------------
	# المرحلة الثانية:
	# إظهار وجه المعلومة
	# -------------------------------------------
	var tween_2 := create_tween()
	
	tween_2.tween_property(
		texture_rect,
		"scale:x",
		1.0,
		0.25
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	await tween_2.finished
	
	texture_rect.scale.x = 1.0
	is_flipping = false
	
# ---------------------------
#  المعركة
#---------------------------
var battle_mode := false
var battle_attacker_team := 0
var battle_defender_team := 0
var battle_answering_team := 0
const OWNER_NONE := 0
const OWNER_NEUTRAL_LOCKED := -1

# هل تم استخدام فرصة الإجابة الثانية في هذه المعركة؟
var second_chance_used := false


# ======================================================
#   عرض سؤال المعركة للقراءة فقط
# ------------------------------------------------------
# عند بدء المعركة يظهر السؤال أولًا للجميع دون إمكانية الإجابة
# لمدة ANSWER_TIME_SECONDS، ثم يغلق تلقائيًا وتظهر نافذة اختيار
# الفريق. السؤال نفسه يعاد عرضه بعدها في show_battle_question،
# لأن كلا العرضين يقرأ questions[cell.questions_used] ولا يتغير
# العداد إلا بعد الإجابة
# ======================================================
signal battle_preview_finished

var battle_preview_running := false
var battle_preview_time_left := 0.0


func show_battle_preview(cell, board_ref) -> void:
	var sector_data: Dictionary = SectorQuestionsData.sector_cards.get(cell.sector_id, {})
	var questions: Array = sector_data.get("questions", [])
	var question_index: int = cell.questions_used

	# لا سؤال متاح: نتخطى القراءة ويكمل المسار الحالي إلى إلغاء المعركة
	if question_index < 0 or question_index >= questions.size():
		return

	current_cell = cell
	board = board_ref
	current_board = board_ref

	reset_question_card()

	# reset_question_card تشغل مؤقت الإجابة، ولا إجابة في هذه المرحلة
	timer_running = false
	battle_mode = false
	# يمنع _resolve_answer من أي مسار كان، ويعاد ضبطه في show_battle_question
	answer_selected = true

	current_question = questions[question_index]

	sector_name_label.text = sector_data.get("topic", "")
	question_number_label.text = "سؤال المعركة - للقراءة فقط"
	question_text_label.text = current_question["question"]

	answer_a_button.text = current_question["answers"]["A"]
	answer_b_button.text = current_question["answers"]["B"]
	answer_c_button.text = current_question["answers"]["C"]
	answer_d_button.visible = false

	result_label.visible = false
	result_label.text = ""

	_apply_question_visuals()

	# بعد _apply_question_visuals لأنها تظهر مناطق الضغط في وضع الصورة
	_set_option_zones_visible(false)
	answer_a_button.disabled = true
	answer_b_button.disabled = true
	answer_c_button.disabled = true
	answer_d_button.disabled = true

	# زر الإغلاق ينهي الدور عبر hide_card، فيُخفى طوال القراءة
	close_button.visible = false

	battle_preview_time_left = ANSWER_TIME_SECONDS
	timer_label.visible = true
	timer_label.text = "📖 وقت القراءة: " + GameManagerHelper.format_mm_ss(int(battle_preview_time_left))
	battle_preview_running = true

	# البطاقة الظاهرة تمنع النرد أصلًا، وهذا المانع احتياط للحظة الانتقال
	GameManagerHelper.push_input_block(self, "battle_preview")

	visible = true
	layer = 100

	await battle_preview_finished


func _finish_battle_preview() -> void:
	if not battle_preview_running:
		return

	battle_preview_running = false
	close_button.visible = true
	visible = false

	# المانع يُحرر بعد أن تفتح نافذة المعركة في الإطار نفسه
	# (المستمع ينفذ show_battle مباشرة بعد الإشارة)
	battle_preview_finished.emit()
	GameManagerHelper.pop_input_block(self)


func handle_sector(cell) -> void:
	var team_id = GameManager.current_team

	if cell.is_closed:
		return

	if cell.owner_team != 0 and cell.owner_team != team_id:
		board.BattlePopup.show_battle(cell, team_id, cell.owner_team, board)
		return

	show_sector_card(cell, board)

func show_battle_question(
	cell,
	board_ref,
	answering_team: int,
	attacker_team: int,
	defender_team: int
) -> void:
	current_cell = cell
	current_board = board_ref
	
	timer_running = false
	
	choos_player_1.visible= false
	choos_player_2.visible = false
	if GameManager.g_is_battle== true:
		choos_player_1.visible=true
		choos_player_2.visible=true
	

	
	#GameManager.g_is_battle= false

	battle_mode = true
	battle_answering_team = answering_team
	battle_attacker_team = attacker_team
	battle_defender_team = defender_team


#------------------------------------------------------
#  إذا كان هناك لعب لفريق ما بناء على الحدث السيء رقم 1 
#في المعركة القادمة تكون الأسبقية في ا
#لإجابة لصالح الفريق المنافس ولا يوجد أي قيود على الوقت.

#	
	if battle_answering_team==1 || battle_answering_team==2:
		choos_player_2.visible=false
		choos_player_1.visible=false
	
	# كل معركة جديدة تبدأ بدون استخدام الفرصة الثانية
	second_chance_used = false

	answers_container.visible = true
	background_label.visible = false
	background_label.text = ""
	result_label.visible = false
	result_label.text = ""
	answer_selected = false

	var sector_data: Dictionary = SectorQuestionsData.sector_cards.get(cell.sector_id, {})
	var questions: Array = sector_data.get("questions", [])

	# في المعركة نستخدم السؤال التالي المتاح
	var question_index: int = cell.questions_used

	# قد ينتهي القطاع من أسئلته قبل بدء المعركة، أو يكون رقم القطاع
	# غير موجود في بيانات الأسئلة. في هذه الحالة لا يوجد سؤال نعرضه،
	# فلا نحاول قراءة عنصر خارج حدود المصفوفة.
	if question_index < 0 or question_index >= questions.size():
		push_warning(
			"لا يوجد سؤال متاح للمعركة في القطاع %s (questions_used=%d, عدد الأسئلة=%d)"
			% [str(cell.sector_id), question_index, questions.size()]
		)
		_abort_battle_without_question()
		return

	# لا نقفل القطاع إلا بعد التأكد من وجود سؤال للمعركة
	cell.is_locked = 1

	current_question = questions[question_index]

	sector_name_label.text = sector_data.get("topic", "")

	if answering_team == attacker_team:
		question_number_label.text = "سؤال المعركة - المهاجم"
	else:
		question_number_label.text = "سؤال المعركة - المدافع"

	question_text_label.text = current_question["question"]

	answer_a_button.text = current_question["answers"]["A"]
	answer_b_button.text = current_question["answers"]["B"]
	answer_c_button.text = current_question["answers"]["C"]

	answer_d_button.visible = false

	# يعرض صورة البطاقة إن وجدت، وإلا يبقى العرض النصي
	_apply_question_visuals()

	visible = true
	layer = 100
	enable_answer_buttons()

	# enable_answer_buttons لا تشغل المؤقت في المعركة، وأزرار ChoosPlayer
	# التي كانت تشغله مخفية دائمًا هنا، فكان سؤال المعركة بلا مؤقت.
	# نشغله صراحة عند فتح السؤال للإجابة. تأثير "ما هذا الحظ السيّئ"
	# ما زال قائمًا في هذه اللحظة (يحذف بعد العودة من هنا)، فيبقى
	# الفريق المستفيد بلا حد زمني كما في وثيقة البطاقات
	_start_answer_timer()


# ======================================================
# اسم الدالة: _close_exhausted_cell_and_end_turn
# وظيفتها:
# إغلاق قطاع لم يعد له سؤال متاح، ثم إنهاء الدور عبر مسار
# الإغلاق الطبيعي حتى لا يتوقف الدور وتتجمد اللوحة
# ======================================================
func _close_exhausted_cell_and_end_turn(close_for_team: int) -> void:
	answer_selected = true

	_set_option_zones_visible(false)

	if is_instance_valid(current_cell):
		current_cell.close_cell(close_for_team)

	# نفس مسار الإغلاق الطبيعي: يخفي البطاقة ثم ينهي الدور
	hide_card()


# ======================================================
# اسم الدالة: _abort_battle_without_question
# وظيفتها:
# إنهاء معركة لا يوجد لها سؤال متاح، بدل الانهيار أو تعليق الدور.
# القطاع يبقى مع مالكه المدافع ويغلق لأن أسئلته انتهت.
# ======================================================
func _abort_battle_without_question() -> void:
	battle_mode = false
	battle_answering_team = 0

	# المعركة لم تبدأ، فلا يتغير مالك القطاع
	var close_for_team := -1
	if is_instance_valid(current_cell) and battle_defender_team > 0:
		current_cell.owner_team = battle_defender_team
		close_for_team = battle_defender_team

	_close_exhausted_cell_and_end_turn(close_for_team)


func _on_button_1_pressed() -> void:
	
	_start_answer_timer()
	battle_answering_team=1
	choos_player_1.visible=false
	choos_player_2.visible=false


func _on_button_2_pressed() -> void:
	
	_start_answer_timer()
	battle_answering_team=2
	choos_player_1.visible=false
	choos_player_2.visible=false
