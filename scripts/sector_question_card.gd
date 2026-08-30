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


# ======================================================
# اسم الدالة: _sync_image_mode_overlay
# وظيفتها:
# نسخ نص المؤقت والنتيجة من العقدتين الأصليتين إلى الطبقة.
# تستدعى كل إطار، فتلتقط أي تغيير مهما كان مصدره
# ======================================================
func _sync_image_mode_overlay() -> void:
	_ensure_image_mode_overlay()

	# الطبقة لوضع الصورة فقط، وليس على وجه المعلومة
	if not uses_card_image or _showing_info_side:
		_overlay_timer.visible = false
		_overlay_result.visible = false
		return

	var has_result: bool = result_label.visible and result_label.text != ""

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
	_resolve_answer(option_index == correct_index)


# ======================================================
# اسم الدالة: _apply_question_visuals
# وظيفتها:
# عرض السؤال كصورة بطاقة جاهزة إذا توفرت صورة للقطاع،
# وإلا يبقى العرض النصي القديم كما هو
# ======================================================
func _apply_question_visuals() -> void:
	var image_path: String = str(current_question.get("image", ""))
	uses_card_image = image_path != "" and ResourceLoader.exists(image_path)

	# سؤال جديد يعني العودة من وجه المعلومة إلى وجه السؤال
	_showing_info_side = false

	if uses_card_image:
		texture_rect.texture = load(image_path)

		# السؤال والخيارات مرسومة داخل الصورة، فلا حاجة للوحة النصوص
		panel.visible = false
		background_label.visible = false
		_set_option_zones_visible(true)
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
	
	result_label.text = "❌ إجابة خاطئة\n✨ لديكم فرصة ثانية للإجابة مرة أخرى"
	result_label.add_theme_color_override(
		"font_color",
		Color(0.001, 0.001, 0.0, 1.0)
	)
	
	# إعادة تفعيل الإجابة
	answer_selected = false
	#enable_answer_buttons()
	
	return true
	
func handle_normal_answer(is_correct: bool) -> void:
	var team_id = GameManager.current_team

	current_cell.questions_used += 1
	
	if is_correct:
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

	# وجه المعلومة لا يعرض المؤقت ولا النتيجة
	_showing_info_side = true

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
	enable_answer_buttons()


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
