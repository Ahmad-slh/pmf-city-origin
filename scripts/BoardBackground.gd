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

	var minutes := remaining_seconds / 60
	var seconds := remaining_seconds % 60
	game_timer_label.text = "%02d:%02d" % [minutes, seconds]

func end_game():

	print("Game Over")

	# هنا تستدعي شاشة النتائج		


func _on_exit_to_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
