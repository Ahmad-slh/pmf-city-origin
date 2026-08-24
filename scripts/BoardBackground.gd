extends Node2D

@export var event_notification_scene: PackedScene

@onready var board = $GameRoot/Board
@onready var left_event_panel: Control = $EventsUI/LeftEventPanel
@onready var right_event_panel: Control = $EventsUI/RightEventPanel

@onready var right_event_title_label: Label = $EventsUI/RightEventPanel/Panel/EventTitleLabel
@onready var right_event_body_label: Label = $EventsUI/RightEventPanel/Panel/EventBodyLabel

@onready var lefet_event_title_label: Label = $EventsUI/LeftEventPanel/Panel/EventTitleLabel
@onready var lefet_event_body_label: Label = $EventsUI/LeftEventPanel/Panel/EventBodyLabel

@onready var round_label: Label = $UpPanel/RoundLabel

@onready var debug_event_panel : CanvasLayer = $DebugEventPanel

@onready var game_timer_label: Label = $TimerImage/GameTimerLabel
@onready var game_timer: Timer = $GameTimer
@onready var exit_to_menu_button: Button = $ExitUI/ExitToMenuButton



var remaining_seconds := 3600



var active_notifications: Array = []
var shown_notification_effects: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	board.main_ui = self
	exit_to_menu_button.pressed.connect(_on_exit_to_menu_pressed)
	#GameManager.signal_skip_turn_cleared.connect(_on_skip_turn_cleared)
	GameManagerHelper.effects_changed.connect(_on_effects_changed)
	GameManagerHelper.effects_show.connect(_on_effects_show)
	
	debug_event_panel.setup(StreetCardsData, self)

	left_event_panel.visible = true
	right_event_panel.visible = true

	left_event_panel.setup_team(1)
	right_event_panel.setup_team(2)
	
	var team_id=GameManager.current_team
	
	refresh_team_effect_panel(1)
	refresh_team_effect_panel(2)
	
	#----------------
	game_timer.timeout.connect(_on_game_timer_timeout)
	update_game_timer()
	game_timer.start()

	# قرعة البداية تحدد الفريق الذي يلعب أولا قبل أي دور عادي
	board.run_opening_roll_off()
	
	
	
	

	#left_event_panel.show_event(
		#"لا يوجد حدث حاليًا",
		#"ستظهر هنا أحداث الشوارع الخاصة بهذا الفريق."
	#)

	#right_event_panel.show_event(
		#"لا يوجد حدث حاليًا",
		#"ستظهر هنا أحداث الشوارع الخاصة بهذا الفريق."
	#)
#
#
	#left_event_panel.show_event(
		#"لا يوجد حدث حاليًا",
		#"ستظهر هنا أحداث الشوارع الخاصة بهذا الفريق."
	#)
#
	#right_event_panel.show_event(
		#"لا يوجد حدث حاليًا",
		#"ستظهر هنا أحداث الشوارع الخاصة بهذا الفريق."
	#)

func show_team_street_event(team_id: int, title: String, body: String) -> void:

	if team_id == GameManager.Team.BLUE:
		left_event_panel.show_event(title, body)
		
	else:
		right_event_panel.show_event(title, body)
		

func hide_team_street_event(team_id: int) -> void:
	if team_id == 1:
		lefet_event_title_label.text = ""
		lefet_event_body_label.text = ""
	elif team_id == 2:
		right_event_title_label.text = ""
		right_event_body_label.text = ""
		
func _on_skip_turn_cleared(team_id: int) -> void:
	refresh_team_effect_panel(team_id)	

# يتم استدعاؤها عند أي تغيير على التأثيرات: إضافة أو حذف
# هنا نحدث اللوحات فقط ولا نظهر إشعار جديد
func _on_effects_changed(team_id: int) -> void:
	refresh_team_effect_panel(team_id)
	update_team_effect_notification_silent(team_id)

	#setup_team_event_notification(team_id)	

# يتم استدعاؤها فقط عند إضافة حدث جديد من الشارع
# هنا نعرض الإشعار للمستخدم
func _on_effects_show(team_id: int) -> void:
	show_team_effects_notifications(team_id)


func refresh_team_effect_panel(team_id: int) -> void:
	#print ("refresh_team_effect_panel-team id=", team_id)
	#print("HANDLE CELL CALLED FROM refresh_team_effect_panel = ", get_stack())
	
	round_label.text=str(GameManager.total_rounds)

	var effects_text: String = GameManagerHelper.get_team_effects_text(team_id)


	if effects_text == "لا يوجد حدث حاليًا":
		show_team_street_event(
			team_id,
			" ",
			"ستظهر هنا أحداث الشوارع الخاصة بهذا الفريق."
		)
		return

	show_team_street_event(
		team_id,
		" ",
		effects_text
	)		

# إظهار حدث جديد للفريق
#func show_team_event_notification(team_id: int, event_text: String) -> void:
	#if active_notifications.has(team_id):
		#active_notifications[team_id].queue_free()
		#active_notifications.erase(team_id)
	#
	#var notification = event_notification_scene.instantiate()
	#add_child(notification)
	#
	#active_notifications[team_id] = notification
	#notification.setup_notification(team_id, event_text)


# حذف كل إشعارات فريق معين نهائيا
# تستخدم عندما لا يبقى لهذا الفريق أي تأثير داخل team_effects
func remove_team_event_notification(team_id: int) -> void:
	for notification in active_notifications:
		if is_instance_valid(notification) and notification.team_id == team_id:
			notification.remove_notification()

	clean_invalid_notifications()
	

# عرض إشعار منفصل لكل تأثير جديد فقط
# لا تعرض التأثيرات القديمة مرة ثانية
func show_team_effects_notifications(team_id: int) -> void:
	if GameManagerHelper.last_effect_source_type != "STREET":
		return

	if event_notification_scene == null:
		print("EventNotification scene is not assigned")
		return

	if not GameManagerHelper.team_effects.has(team_id):
		remove_team_event_notification(team_id)
		return

	var effects: Dictionary = GameManagerHelper.team_effects[team_id]

	if effects.is_empty():
		remove_team_event_notification(team_id)
		return

	for effect_type in effects.keys():
		var key := str(team_id) + "_" + str(effect_type)

		# إذا تم عرض هذا التأثير سابقا، لا نكرره
		if shown_notification_effects.has(key):
			#remove_team_event_notification(team_id)
			if effect_type != GameManagerHelper.EffectType.ROLL_TWICE_CHOOSE_BEST:
				continue

		shown_notification_effects[key] = true

		# الوصف يطلب بنوع التأثير وبرقم الفريق.
		# تمرير رقم البطاقة هنا كان يرجع وصف بطاقة أخرى لا علاقة لها بالحدث
		var message: String = GameManagerHelper.get_effect_description(effect_type, team_id)

		var notification = event_notification_scene.instantiate()
		add_child(notification)

		active_notifications.append(notification)

		var index := get_team_notification_index(team_id)
		notification.setup_notification(team_id, message, index, effect_type)
			
	
func get_team_notification_index(team_id: int) -> int:
	var count := 0

	for notification in active_notifications:
		if is_instance_valid(notification) and notification.team_id == team_id:
			count += 1

	return count - 1
	
	
	
	# تحديث صامت عند حذف تأثير
# لا يظهر إشعار جديد، فقط يحذف إشعارات التأثيرات التي انتهت
func update_team_effect_notification_silent(team_id: int) -> void:
	if not GameManagerHelper.team_effects.has(team_id):
		remove_team_event_notification(team_id)
		return

	var effects: Dictionary = GameManagerHelper.team_effects[team_id]

	for notification in active_notifications:
		if not is_instance_valid(notification):
			continue

		if notification.team_id != team_id:
			continue

		var key := str(team_id) + "_" + str(notification.effect_type)

		if not effects.has(notification.effect_type):
			notification.remove_notification()
			shown_notification_effects.erase(key)

	clean_invalid_notifications()

func clean_invalid_notifications() -> void:
	for i in range(active_notifications.size() - 1, -1, -1):
		if not is_instance_valid(active_notifications[i]):
			active_notifications.remove_at(i)	

# --------------  Timer
func _on_game_timer_timeout():
	remaining_seconds -= 1

	update_game_timer()
	if remaining_seconds <= 0:
		game_timer.stop()
		end_game()

func update_game_timer():

	# اعرض دائماً بصيغة MM:SS فقط — بدون ساعات
	# ملاحظة: لا نضيف "⏳ الوقت:" هنا لأن الأيقونة موجودة أصلاً كصورة
	# (TimerImage)، ولأن النص الأطول يفيض خارج الصندوق الأزرق
	game_timer_label.text = GameManagerHelper.format_mm_ss(remaining_seconds)

func end_game():

	print("Game Over")

	# هنا تستدعي شاشة النتائج		


# ======================================================
#   تأكيد الخروج إلى القائمة الرئيسية
# ------------------------------------------------------
# الخروج يفقد المباراة كاملة (لا يوجد حفظ)، فلا يكفي ضغط
# زر واحد. النافذة مبنية بالكود على نمط _show_direction_popup:
# CanvasLayer + خلفية معتمة + لوحة في المنتصف.
#
# طبقة 140 لأن زر الخروج نفسه على ExitUI بطبقة 10
# ======================================================
const EXIT_CONFIRM_LAYER := 140

var exit_confirm_layer: CanvasLayer = null


func _on_exit_to_menu_pressed() -> void:
	# لا نفتح التأكيد فوق بطاقة أو نافذة مفتوحة أصلا.
	# is_dice_locked تجمع is_any_card_open مع سجل الموانع،
	# فهي تغطي أيضا ضغطة ثانية والنافذة مفتوحة
	if board.is_dice_locked():
		return

	_show_exit_confirm_popup()


func _show_exit_confirm_popup() -> void:
	var layer := CanvasLayer.new()
	layer.layer = EXIT_CONFIRM_LAYER
	add_child(layer)
	exit_confirm_layer = layer

	# النافذة تنتظر ضغطة اللاعب، فتقفل النرد مثل بقية النوافذ
	GameManagerHelper.push_input_block(layer, "exit_confirm_popup")

	var screen_size: Vector2 = get_viewport().get_visible_rect().size

	# خلفية معتمة تبتلع الضغطات خلف النافذة
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	# المراسي وحدها تكفي لتغطية الشاشة، وضبط size معها
	# يطلق تحذير "non-equal opposite anchors" ويُلغى بعد _ready
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)

	var panel_size := Vector2(600, 260)

	var panel := Panel.new()
	panel.size = panel_size
	panel.position = (screen_size - panel_size) / 2.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color("#FFFFFF")
	style.set_border_width_all(4)
	style.border_color = Color("#D32F2F")
	style.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", style)

	layer.add_child(panel)

	var message := Label.new()
	message.text = "هل أنت متأكد؟ إذا خرجت سوف تبدأ من جديد"
	message.size = Vector2(panel_size.x - 60, 100)
	message.position = Vector2(30, 40)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 26)
	message.add_theme_color_override("font_color", Color("#1F1F1F"))
	panel.add_child(message)

	# اليمين في واجهة عربية هو الخيار الأول
	_add_exit_confirm_button(
		panel, "نعم، اخرج", Vector2(panel_size.x - 250, 165),
		Color("#D32F2F"), _on_exit_confirmed
	)
	_add_exit_confirm_button(
		panel, "إلغاء", Vector2(30, 165),
		Color("#6B6B6B"), _on_exit_cancelled
	)


func _add_exit_confirm_button(
	panel: Panel,
	text: String,
	pos: Vector2,
	color: Color,
	handler: Callable
) -> void:
	var button := Button.new()
	button.text = text
	button.size = Vector2(220, 60)
	button.position = pos
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", Color("#FFFFFF"))
	button.add_theme_color_override("font_hover_color", Color("#FFFFFF"))
	button.add_theme_color_override("font_pressed_color", Color("#FFFFFF"))

	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(12)
	button.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = color.lightened(0.12)
	button.add_theme_stylebox_override("hover", hover)

	var pressed := style.duplicate()
	pressed.bg_color = color.darkened(0.12)
	button.add_theme_stylebox_override("pressed", pressed)

	button.pressed.connect(handler)
	panel.add_child(button)


func _close_exit_confirm_popup() -> void:
	if is_instance_valid(exit_confirm_layer):
		GameManagerHelper.pop_input_block(exit_confirm_layer)
		exit_confirm_layer.queue_free()

	exit_confirm_layer = null


func _on_exit_confirmed() -> void:
	# نحرر المانع قبل تبديل المشهد، فالسجل autoload يعيش بعده
	_close_exit_confirm_popup()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _on_exit_cancelled() -> void:
	_close_exit_confirm_popup()
