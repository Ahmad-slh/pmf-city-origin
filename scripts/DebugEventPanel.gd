extends CanvasLayer

# ======================================================
# عناصر الواجهة
# ======================================================

@onready var panel: Panel = $Panel

@onready var event_list: ItemList = $Panel/VBoxContainer/EventList


@onready var test_button: Button = $Panel/VBoxContainer/TestButton
@onready var close_button: Button = $Panel/VBoxContainer/CloseButton


# ======================================================
# متغيرات خارجية
# ======================================================

var card_manager = null
var main_ui = null

#var testing_cards = "good_cards" #'bad_cards'



# ======================================================
# اسم الدالة: _ready
# وظيفتها:
# تجهيز لوحة فحص الأحداث عند تشغيل اللعبة
# ======================================================
# ======================================================
# اسم الدالة: _is_debug_tools_enabled
# وظيفتها:
# لوحة فحص الأحداث أداة تطوير فقط.
#
# كانت تظهر فوق اللوحة منذ بدء اللعبة وتغطي جزءا كبيرا من الشاشة
# حتى في النسخة النهائية التي يلعبها اللاعبون.
#
# OS.is_debug_build() ترجع true عند التشغيل من المحرر أو من تصدير
# debug، وترجع false في تصدير الإصدار (export-release).
# نستخدمها هنا لأمرين معا:
#   1. إخفاء اللوحة عند بدء اللعبة
#   2. تعطيل مفتاح F9 حتى لا يفتحها اللاعب،
#      لأن فتحها يغير debug_use_selected_card فيتأثر سحب البطاقات
# ======================================================
func _is_debug_tools_enabled() -> bool:
	return OS.is_debug_build()


func _ready() -> void:
	visible = _is_debug_tools_enabled()

	test_button.text = "تجربة الحدث"
	close_button.text = "إخفاء"
	
	event_list.select_mode = ItemList.SELECT_MULTI
	
	test_button.pressed.connect(_on_test_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)


# ======================================================
# اسم الدالة: setup
# وظيفتها:
# استقبال CardManager و MainUI حتى نستطيع تشغيل الحدث
# ======================================================
func setup(_card_manager, _main_ui) -> void:
	card_manager = _card_manager
	main_ui = _main_ui
	
	#var cards_type = card_manager.get(testing_cards)
	#var cards_type = StreetCardsData.all_cards
	
	_fill_events_list()


# ======================================================
# اسم الدالة: _fill_events_list
# وظيفتها:
# تعبئة القائمة بجميع الأحداث السيئة الموجودة
# ======================================================
func _fill_events_list() -> void:

	# التأكد من أن CardManager موجود
	if card_manager == null:
		print("card_manager غير موجود")
		return

	# تفريغ القائمة القديمة
	event_list.clear()

	# أخذ جميع البطاقات من القائمة الموحدة
	var cards_type: Array = StreetCardsData.all_cards

	print("عدد البطاقات التي ستظهر في لوحة Debug: ", cards_type.size())

	# المرور على جميع البطاقات
	for i in range(cards_type.size()):

		var card: Dictionary = cards_type[i]

		var card_type: String = str(card.get("type", "UNKNOWN"))
		var card_id = card.get("id", "-")
		var card_effect: String = str(card.get("effect", "NONE"))
		var card_name: String = str(card.get("name", "NONE"))

		var event_text := ""

		# إظهار نوع البطاقة بوضوح
		if card_type == "GOOD":
			event_text = "[GOOD] "
		elif card_type == "BAD":
			event_text = "[BAD] "
		else:
			event_text = "[UNKNOWN] "

		event_text += " : " + str(card_id)
		event_text += " | " + card_name
		event_text += " | " + card_effect

		# إضافة العنصر إلى ItemList
		event_list.add_item(event_text)
		
# ======================================================
# اسم الدالة: _on_test_button_pressed
# وظيفتها:
# عند الضغط على زر التجربة يتم اختيار الحدث وتشغيله
# ======================================================
func _on_test_button_pressed() -> void:
	
	visible = false

	if card_manager == null:
		print("card_manager غير موجود")
		return

	# الحصول على جميع أرقام العناصر المحددة
	var selected_items: PackedInt32Array = event_list.get_selected_items()

	# التأكد أن المستخدم اختار بطاقة واحدة على الأقل
	if selected_items.is_empty():
		print("اختر بطاقة واحدة على الأقل")
		return

	# تفريغ الاختيارات القديمة
	StreetCardsData.debug_selected_cards.clear()

	# نقل أرقام العناصر المحددة إلى StreetCardsData
	for index in selected_items:

		# حماية من رقم خارج all_cards
		if index < 0 or index >= StreetCardsData.all_cards.size():
			print("تم تجاهل رقم غير صحيح: ", index)
			continue

		StreetCardsData.debug_selected_cards.append(index)

		var card: Dictionary = StreetCardsData.all_cards[index]

		print("--------------------------")
		print("تم اختيار العنصر رقم: ", index)
		print("نوع البطاقة: ", card.get("type", "UNKNOWN"))
		print("ID البطاقة: ", card.get("id", "-"))
		print("التأثير: ", card.get("effect", "NONE"))

	# تشغيل وضع الاختيار اليدوي
	StreetCardsData.debug_use_selected_card = true

	print("==========================")
	print("جميع البطاقات المختارة:")
	print(StreetCardsData.debug_selected_cards)
	
# ======================================================
# اسم الدالة: _on_close_button_pressed
# وظيفتها:
# إخفاء لوحة الفحص
# ======================================================
func _on_close_button_pressed() -> void:
	#StreetCardsData.debug_use_selected_card=false
	
	visible = false

# ======================================================
# اسم الدالة: _input
# وظيفتها:
# مراقبة ضغط الأزرار من الكيبورد
# عند الضغط على F9 يتم إظهار أو إخفاء لوحة الفحص
# ======================================================
func _input(event: InputEvent) -> void:
	# في نسخة الإصدار لا يفتح المفتاح اللوحة إطلاقا
	if not _is_debug_tools_enabled():
		return

	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_F9:
				_toggle_debug_event_panel()
			elif event.keycode == KEY_F10:
				_debug_open_choose_dice_popup()

# ======================================================
# اسم الدالة: _debug_open_choose_dice_popup
# وظيفتها:
# اختصار تجريبي مؤقت: يفتح نافذة اختيار رقم حجر النرد
# (١-٦) مباشرة دون الحاجة لسحب بطاقة "تحكم كامل" فعليا.
# مخصص فقط لاختبار الأزرار الستة يدويا، محمي بنفس شرط
# OS.is_debug_build() فلا يظهر إطلاقا في نسخة الإصدار.
# ======================================================
func _debug_open_choose_dice_popup() -> void:
	if main_ui == null or main_ui.board == null:
		print("main_ui/board غير موجودة، تعذر فتح نافذة اختيار الرقم")
		return

	print("[Debug F10] فتح نافذة اختيار رقم حجر النرد مباشرة")
	main_ui.board.show_choose_dice_popup(1)

# ======================================================
# اسم الدالة: _toggle_debug_event_panel
# وظيفتها:
# إذا كانت لوحة الفحص مخفية تظهرها
# وإذا كانت ظاهرة تخفيها
# ======================================================
func _toggle_debug_event_panel() -> void:
	visible = true
	
	if panel == null:
		print("DebugEventPanel غير موجودة")
		return

	panel.visible = !panel.visible
	
	if panel.visible:		
		StreetCardsData.debug_use_selected_card=true
	else:
		StreetCardsData.debug_use_selected_card=false
					
