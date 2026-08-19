extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/TitleLabel
@onready var event_label: Label = $Panel/EventLabel
@onready var close_button: Button = $Panel/CloseButton
@onready var small_icon_button: Button = $SmallIconButton
#@onready var icon_label: Label = $SmallIconButton/IconLabel


@export var blue_small_icon: Texture2D
@export var red_small_icon: Texture2D


var team_id: int = 0
var shown_position: Vector2
var hidden_position: Vector2
var is_open: bool = false
var life_time: float = 3.0
var effect_type: int = -1
var top_side: int = 300

func _ready() -> void:
	close_button.pressed.connect(_on_close_button_pressed)
	small_icon_button.pressed.connect(_on_small_icon_button_pressed)
	#small_icon_button.visible = false


func setup_notification(_team_id: int, event_text: String, index: int = 0, _effect_type: int = -1) -> void:
	title_label.visible = false
	team_id = _team_id
	effect_type = _effect_type
	_prepare_design()

	if team_id == 1:
		title_label.text = "حدث الفريق الأزرق"
	else:
		title_label.text = "حدث الفريق الأحمر"
	
	_apply_team_colors()
	
	event_label.text = event_text
	small_icon_button.visible = false

	_prepare_positions(index)
	_show_notification()
	
	
# تحديد مكان الإشعار حسب الفريق
# الأزرق يظهر من اليسار، والأحمر يظهر من اليمين
func _prepare_positions(index: int = 0) -> void:
	var screen_size = get_viewport().get_visible_rect().size
	var spacing_y := 10
	var y := top_side + (index * (panel.size.y + spacing_y))
	
	

	if team_id == 1:
		shown_position = Vector2(20, y)
		hidden_position = Vector2(-panel.size.x - 40, y)

		# الأزرق يظهر من اليسار وبارز قليلا
		small_icon_button.position = Vector2(-50, y + 30)

	else:
		shown_position = Vector2(screen_size.x - panel.size.x + 500, y)
		hidden_position = Vector2(screen_size.x + 500, y)
		# الأحمر يظهر من اليمين وبارز قليلا
		small_icon_button.position = Vector2(screen_size.x - small_icon_button.size.x+ 450, y + 30)
		
	panel.position = hidden_position
	

func _show_notification() -> void:
	is_open = true
	
	panel.visible = true
	panel.modulate.a = 1.0
	panel.position = hidden_position
	
	small_icon_button.visible = false
	
	var tween = create_tween()
	tween.tween_property(panel, "position", shown_position, 0.35)
	
	await get_tree().create_timer(life_time).timeout
	
	if is_open:
		_hide_notification()
		
# اسم الدالة: _hide_notification
# وظيفتها: إخفاء الإشعار الكامل وإظهار التبويب الصغير
func _hide_notification() -> void:
	is_open = false
	
	var tween = create_tween()
	tween.tween_property(panel, "position", hidden_position, 0.35)
	await tween.finished
	
	panel.visible = false
	panel.modulate.a = 1.0
	small_icon_button.visible = true
	

func _on_close_button_pressed() -> void:
	_hide_notification()

# اسم الدالة: _on_small_icon_button_pressed
# وظيفتها: عند الضغط على التبويب الصغير، يعيد فتح الإشعار الكامل
func _on_small_icon_button_pressed() -> void:
	if is_open:
		return

	_show_notification()

func remove_notification() -> void:
	panel.visible = false
	small_icon_button.visible = false
	queue_free()


func update_text_silent(event_text: String) -> void:
	event_label.text = event_text

# تجهيز شكل الإشعار ليكون شريط طويل بسطر واحد
func _prepare_design() -> void:
	panel.custom_minimum_size = Vector2(560, 120)
	panel.size = Vector2(560, 120)

	#title_label.position = Vector2(60, 8)
	title_label.size = Vector2(410, 0)

	#event_label.position = Vector2(60, 36)
	event_label.size = Vector2(430, 70)
	event_label.add_theme_font_size_override("font_size", 24)
	
	if team_id == 1:
		title_label.position = Vector2(20, 0)
		event_label.position = Vector2(60, 13)
	else:
		title_label.position = Vector2(20, 0)
		event_label.position = Vector2(60, 13)
	
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	event_label.clip_text = false

	if team_id == 1:
		close_button.position = Vector2(panel.size.x - 45, 10)
	else:
		close_button.position = Vector2(12, 10)
		
	close_button.size = Vector2(32, 10)

	#small_icon_button.size = Vector2(70, 42)
	
	_prepare_small_icon_style()

# تلوين الإشعار حسب الفريق
# الفريق الأزرق: إطار أزرق وخلفية فاتحة
# الفريق الأحمر: إطار أحمر وخلفية فاتحة
func _apply_team_colors() -> void:
	var style := StyleBoxFlat.new()

	style.bg_color = Color("#FFFFFF")
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8

	if team_id == 1:
		style.border_color = Color("#1976D2")
		title_label.add_theme_color_override("font_color", Color("#1976D2"))
	else:
		style.border_color = Color("#D32F2F")
		title_label.add_theme_color_override("font_color", Color("#D32F2F"))

	event_label.add_theme_color_override("font_color", Color("#1F1F1F"))
	close_button.add_theme_color_override("font_color", Color("#666666"))

	panel.add_theme_stylebox_override("panel", style)

# اسم الدالة: _prepare_small_icon_style
# وظيفتها:
# تجهيز التبويب الصغير بعد اختفاء الإشعار
# بحيث تكون الخلفية كلها زر قابل للضغط والأيقونة داخله
func _prepare_small_icon_style() -> void:
	small_icon_button.flat = false
	small_icon_button.text = ""

	# حجم التبويب الحقيقي
	var tab_size := Vector2(130, 20)

	# الزر يأتي من المشهد بمراسي PRESET_FULL_RECT، أي أن
	# anchor_left != anchor_right. ضبط size مباشرة في هذه الحالة
	# يطلق تحذير "size overridden after _ready()" ولا يثبت الحجم،
	# لأن المراسي هي التي تحسم القياس في النهاية.
	# لذلك نضبط المراسي أولا ثم نحدد القياس بالإزاحات
	small_icon_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	small_icon_button.offset_left = 0
	small_icon_button.offset_top = 0
	small_icon_button.offset_right = tab_size.x
	small_icon_button.offset_bottom = tab_size.y

	small_icon_button.custom_minimum_size = tab_size
	small_icon_button.expand_icon = false


	# اختيار لون وأيقونة الفريق
	var team_color: Color

	if team_id == 1:
		team_color = Color("#1976D2")
		small_icon_button.icon = blue_small_icon
	else:
		team_color = Color("#D32F2F")
		small_icon_button.icon = red_small_icon

	# خلفية الزر كاملة بنفس لون الفريق
	var tab_style := StyleBoxFlat.new()
	tab_style.bg_color = team_color

	if team_id == 1:
		tab_style.corner_radius_top_left = 0
		tab_style.corner_radius_bottom_left = 0
		tab_style.corner_radius_top_right = 18
		tab_style.corner_radius_bottom_right = 18
	else:
		tab_style.corner_radius_top_left = 22
		tab_style.corner_radius_bottom_left = 22
		tab_style.corner_radius_top_right = 0
		tab_style.corner_radius_bottom_right = 0

	small_icon_button.add_theme_stylebox_override("normal", tab_style)
	small_icon_button.add_theme_stylebox_override("hover", tab_style)
	small_icon_button.add_theme_stylebox_override("pressed", tab_style)
	small_icon_button.add_theme_stylebox_override("focus", tab_style)

	# الأيقونة تكبر داخل كامل الزر
	
	small_icon_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
