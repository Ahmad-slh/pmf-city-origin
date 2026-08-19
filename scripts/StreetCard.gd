extends CanvasLayer

#----------------------------
#هذا الملف وظيفته فقط:
#عرض البطاقة وتشغيل التأثير عند الضغط على الزر.
#---------------------------

@onready var panel: Panel = $player_image/Panel
@onready var title_label: Label = $player_image/Panel/TitleLabel
@onready var body_label: Label = $player_image/Panel/BodyLabel
@onready var next_button: Button = $player_image/Panel/NextButton

@onready var player_image: TextureRect = $player_image




var current_card: Dictionary = {}
var current_cell = null
var board = null
var is_showing_info: bool = true

# يمنع اللاعب من الضغط أثناء دوران البطاقة
var is_flipping: bool = false

func _ready() -> void:
	visible = false
	

	
	if not next_button.pressed.is_connected(_on_next_button_pressed):
		next_button.pressed.connect(_on_next_button_pressed)


func show_street_card(card_data: Dictionary, cell, board_ref) -> void:
	var team_id = GameManager.current_team
	
	current_card = card_data
	current_cell = cell
	board = board_ref

	is_showing_info = true
	
	player_image.visible = true
	
	if team_id == 1:
		player_image.texture = load(
			"res://assets/images/streets/good_effects/Good01_F1.png"
		)

	elif team_id == 2:
		player_image.texture = load(
			"res://assets/images/streets/good_effects/Good01_F1.png"
		)

	# توسيط البطاقة في الشاشة
	#center_street_card.call_deferred()

	title_label.text = "معلومة مالية"
	body_label.text = current_card.get("info", "لا توجد معلومة")
	next_button.text = ""

	if card_data.has("event"):
		visible = true

func _on_next_button_pressed() -> void:
	
	# منع الضغط مرة ثانية أثناء حركة البطاقة
	if is_flipping:
		return
	
	if is_showing_info:
		await flip_to_event_side_v1()
		await flip_to_event_side_v2()
		#show_event_side()
		#player_image.texture = load(
			#"res://assets/images/streets/good_effects/Good01_F2.png"
		#)
	else:
		apply_card_effect()
		hide_card()



func show_event_side() -> void:

	is_showing_info = false
	
	var card_type = current_card.get("type")
	
	var card_image="res://assets/images/streets/good_effects/Good01_F2.png"
	
	if card_type=='BAD':
		card_image="res://assets/images/streets/good_effects/Bad01_F2.png"
		
	# تغيير صورة البطاقة إلى الوجه الثاني
	player_image.texture = load(
		card_image
	)

	if current_card.get("type", "") == "GOOD":
		title_label.text = "حدث جيد"
		
	elif current_card.get("type", "") == "BAD":
		title_label.text = "حدث سيئ"
		
	else:
		title_label.text = "حدث"

	var event_text = current_card.get("event", "")

	if event_text == "":
		body_label.text = "لا يوجد حدث لهذه البطاقة."
	else:
		body_label.text = event_text

	next_button.text = ""


# ---------- شرح الدالة القادمة ما هي تأثيراتها
# 1- StreetCard.gd يعرض البطاقة فقط
# 2- GameEffects.gd يحدد GOOD أو BAD
# 3- BadEffects.gd يحدد أي تأثير سيئ سيتم تنفيذه
# 4- GameManager.gd ينفذ التأثير الحقيقي
# 5- GameManagerHelper.gd يحفظ التأثيرات ويتابعها
#-------------------------
#Function Name:  تطبيق تأثير البطاقة
func apply_card_effect(p_board=null) -> void:
	GameEffects.apply_card_effect(
		current_card,
		GameManager.current_team,
		board
	)
	
		# نبحث عن قطاع مملوك للفريق
	var selected_sector = null
	var has_effect1 = false
	var has_effect2 = false
	
	has_effect1 = GoodEffects.use_recover_lost_sector(GameManager.current_team)
	has_effect2 = GameManagerHelper.has_effect(
		GameManager.current_team,
		GameManagerHelper.EffectType.IGNORE_FIRST_SECTOR_LOSS_OR_PENALTY
	)
		
	if has_effect1 || has_effect2:
		
		var team_id = GameManager.current_team
			
		var other_team = 1
		if team_id==1:
			other_team=2
		
		if is_instance_valid(board)==false:
			if is_instance_valid(p_board):
				board=p_board
			else:			
				return
			
		for sector in board.sectors.get_children():
			if not sector.has_method("is_sector"):
				continue
			if sector.owner_team == other_team:
				if sector.is_closed:
					selected_sector=sector
					break
		
		# إذا لم نجد قطاع مملوك للفريق
		if selected_sector == null:
			print("لا يوجد قطاع مملوك للفريق: ", team_id)
			return
			
			# إلغاء ملكية القطاع
		selected_sector.owner_team = team_id
		
		var v_is_closed= selected_sector.is_closed
		
		selected_sector.mark_as_team(team_id, board.team_colors[team_id])
		if v_is_closed:
			selected_sector.close_cell(team_id)
		
		if has_effect2:
			GameManagerHelper.remove_effect(
				GameManager.current_team,
				GameManagerHelper.EffectType.IGNORE_FIRST_SECTOR_LOSS_OR_PENALTY
			)
		if has_effect1:
			GameManagerHelper.remove_effect(
				GameManager.current_team,
				GameManagerHelper.EffectType.RECOVER_LOST_SECTOR
			)

func hide_card() -> void:
	var team_id = GameManager.current_team
	#if board != null and board.main_ui != null:
		#board.main_ui.hide_team_street_event(team_id)
	current_card = {}
	current_cell = null
	board = null
	is_showing_info = true
	visible = false
	GameManager.end_turn()
	
	
	
func center_street_card() -> void:
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	
	# الحجم الذي ستظهر به البطاقة على الشاشة
	player_image.size = Vector2(350, 500)
	
	# وضع البطاقة في منتصف الشاشة
	player_image.position = (screen_size - player_image.size) / 2.0


func flip_to_event_side_v1() -> void:
	is_flipping = true
	next_button.disabled = true
	
	# اجعل نقطة دوران البطاقة في منتصفها
	player_image.pivot_offset = player_image.size / 2.0
	
	# إنشاء حركة Tween
	var tween := create_tween()
	
	# تقليص عرض البطاقة حتى تختفي تقريبًا
	tween.tween_property(
		player_image,
		"scale:x",
		0.0,
		0.3
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# انتظار انتهاء النصف الأول من الحركة
	await tween.finished
	
	# تغيير الصورة والنصوص إلى الوجه الثاني
	show_event_side()
	
	# نبدأ الوجه الثاني من عرض صفر
	player_image.scale.x = 0.0
	
	# إنشاء Tween جديد لإظهار الوجه الثاني
	var show_tween := create_tween()
	
	show_tween.tween_property(
		player_image,
		"scale:x",
		1.0,
		0.3
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	await show_tween.finished
	
	player_image.scale.x = 1.0
	next_button.disabled = false
	is_flipping = false

func flip_to_event_side_v2() -> void:

	is_flipping = true
	next_button.disabled = true

	# نقطة الدوران في منتصف البطاقة
	player_image.pivot_offset = player_image.size / 2

	####################################################
	# المرحلة الأولى
	# تدور البطاقة 360 درجة
	# ويصغر عرضها حتى تختفي
	####################################################

	var tween1 = create_tween()

	tween1.set_parallel(true)

	# دوران 360 درجة
	tween1.tween_property(
		player_image,
		"rotation_degrees",
		player_image.rotation_degrees + 360,
		0.45
	)

	# تصغير العرض
	tween1.tween_property(
		player_image,
		"scale:x",
		0.0,
		0.45
	)

	await tween1.finished

	####################################################
	# هنا البطاقة أصبحت مختفية
	# نغير الصورة والنص
	####################################################

	show_event_side()

	####################################################
	# المرحلة الثانية
	####################################################

	player_image.scale.x = 0

	var tween2 = create_tween()

	tween2.set_parallel(true)

	# تكمل الدوران حتى تصبح 720
	tween2.tween_property(
		player_image,
		"rotation_degrees",
		player_image.rotation_degrees + 360,
		0.45
	)

	# ترجع للحجم الطبيعي
	tween2.tween_property(
		player_image,
		"scale:x",
		1.0,
		0.45
	)

	await tween2.finished

	####################################################
	# إعادة القيم
	####################################################

	player_image.rotation_degrees = 0
	player_image.scale = Vector2.ONE

	next_button.disabled = false
	is_flipping = false
