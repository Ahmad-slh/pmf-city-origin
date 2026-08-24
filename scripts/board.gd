extends Node2D

#@onready var BattlePopup: Control = $BattlePopup
@onready var BattlePopup: Control = $CanvasLayer/BattlePopup
@onready var sectors: Node2D = $Sectors

@onready var label: Label = $Label
@onready var button: Button = $Button
@onready var player_green: Node2D = $Players/Player_Green
@onready var player_blue: Node2D = $Players/Player_Blue

#@onready var cell_action_handler = $CellActionHandler
@onready var board_cell_action_handler = $board_CellActionHandler
@onready var SectorQuestionCard: CanvasLayer = $SectorQuestionCard
@onready var turn_label: Label = $TurnLayer/TurnLabel
@onready var StreetCard : CanvasLayer = $StreetCard

@export var choose_dice_popup_scene: PackedScene

#@onready var player: Node2D = $Player
@onready var dice: Area2D = $Dice

var sectors_map := {}
var player_grid_pos := Vector2i(0, 0)
var is_moving := false

#---- For Drag and Drop variables
var is_dragging := false
var drag_player = null

var current_team := 1
var team_colors := {
	1: Color(0.25, 0.55, 1.0, 0.8), # أزرق
	#2: Color(0.2, 0.8, 0.35, 0.8)   # أخضر
	2: Color(1.0, 0.25, 0.25)
}

var team_players := {}
var team_positions := {
	1: Vector2i(0, 0),
	2: Vector2i(0, 0)
}

var main_ui = null

# ======================================================
#   قرعة البداية: كل فريق يرمي النرد، وصاحب الرقم الأعلى يبدأ
# ------------------------------------------------------
# roll_off_active يعطّل منطق الدور العادي داخل _on_dice_rolled
# ويمنع رمي النرد أثناء عرض الإعلانات، بنفس أسلوب
# is_any_card_open المستخدم في dice.gd
# ======================================================
signal roll_off_rolled(value)

const ROLL_OFF_MAX_ROUNDS := 20

var roll_off_active := false
var roll_off_accepting_click := false
var roll_off_value := 0

# مؤشر "ابدأ من هنا" فوق قطاع البداية.
# لوحة عالية لأن DebugEventPanel و EventsUI طبقتا CanvasLayer
# ترسمان فوق اللوحة مهما رفعنا z_index للمؤشر
const START_HINT_SCRIPT := preload("res://scripts/start_hint.gd")
const START_HINT_LAYER := 20
var start_hint: Node2D = null
var start_hint_layer: CanvasLayer = null
var start_hint_used: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player_blue.board = self
	player_green.board = self
	dice.board = self
	#$Board.main_ui = self
	
	turn_label.text = "🔵 دور الفريق الازرق"
	turn_label.modulate = Color(0.3, 0.5, 1)
		
	board_cell_action_handler.setup(self)
	SectorQuestionCard.setup(self)
	
	var sectors = get_tree().get_nodes_in_group("board_sectors")

	GameManager.setup_players(player_blue, player_green)
	#GameManager.turn_changed.connect(change_turn)
	button.pressed.connect(change_turn_from_GM)
	GameManager.turn_changed.connect(update_turn_label)
	GameManager.s_cancel_one_investment.connect(apply_cancel_investment_effect_if_needed)
	GameManager.s_transfer_sector_to_other_team.connect(apply_cancel_investment_for_other_team)
	GameManager.good_dice_choose_next_roll.connect(_on_dice_rolled_manual)
	GoodEffects.s_choose_next_starting_team.connect(_on_dice_rolled_manual_for_choose_next_starting_team)
	#GameManager.street_event_finished.connect(hide_team_street_event)

	#var card = SectorCardsData.get_card(1, 0)


	for sector in sectors:
		# أضف الموقع الأساسي للقطاع
		sectors_map[sector.grid_pos] = sector
		#print(" Core Sector:", sector.grid_pos, "\n")
		# أضف المواقع الإضافية التابعة لنفس القطاع
		for extra_pos in sector.extra_grid_positions:
			sectors_map[extra_pos] = sector
			
			#print("- ", extra_pos)
	
		
		sector.sector_selected.connect(_on_sector_selected)
	#print_debug_three_grids()
	#debug_test_logical_move_from(Vector2i(0, 2), 4)
	#debug_test_move_from(Vector2i(0, 2), 4)
	
	team_players = {
	1: player_blue,
	2: player_green
}
	dice.dice_rolled.connect(_on_dice_rolled)
	show_grid_pos_labels()
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_dragging:
		global_position = get_global_mouse_position()	
	
#-------------------------------
# DICE
##--------------------------------

	# ======================================================
# إذا كان لدى الفريق تأثير اختيار رقم النرد
# لا نرمي النرد عشوائيا
# بل نفتح نافذة اختيار الرقم
# ======================================================
	
func _on_dice_rolled_manual()->void:
	show_choose_dice_popup(1)
	return

func _on_dice_rolled_manual_for_choose_next_starting_team(p_team_id)->void:
	show_choose_dice_popup(3)
	return	
	
	
func _on_dice_twice_choose_best(value:int =0)->bool:
	#var team_id=GameManager.current_team	
	if GoodEffects.use_twice_choose_best(current_team):
		if GoodEffects.firstRoll==0:
			GoodEffects.firstRoll=value
			return true
		else:
			GoodEffects.secondRoll=value
			#GameManagerHelper.remove_effect(team_id,GameManagerHelper.EffectType.ROLL_TWICE_CHOOSE_BEST)
			show_choose_dice_popup(2)
			return true
	return false

func _on_dice_rolled(value: int) -> void:
	#print("START DICE")

	# قرعة البداية تستهلك الرمية بنفسها، فلا نشغّل منطق الدور
	if roll_off_active:
		roll_off_value = value
		roll_off_rolled.emit(value)
		return

	var team_id = GameManager.current_team
	clear_sector_highlights()
	
	if _on_dice_twice_choose_best(value):
		return
		
	var current_team_id =GameManagerHelper.get_team_id_from_effect(GameManagerHelper.EffectType.CHOOSE_NEXT_STARTING_TEAM)
	if GoodEffects.use_choose_next_starting_team(current_team_id):
		GameManagerHelper.remove_effect(current_team_id,GameManagerHelper.EffectType.CHOOSE_NEXT_STARTING_TEAM)
			
	# سابقا كان هنا SectorQuestionCard.timer_running = false، وهو
	# سطر يوقف مؤقت السؤال عند كل رمية. لم يعد له داع:
	# is_dice_locked يمنع الرمي أصلا ما دامت البطاقة معروضة،
	# و hide_card توقف المؤقت بنفسها قبل أن تخفي البطاقة

	var current_player = get_current_player()
	
	if current_player.has_method("stop_dragging"):
		current_player.stop_dragging()
		

	current_team = GameManager.current_team
	
	
	# فحص عقوبة تجميد الحركة
	# الفريق يرمي النرد، لكن لا يتحرك هذه الجولة
	if GameManager.is_team_frozen(team_id):
		print("الفريق ", team_id, " مجمّد ولا يستطيع الحركة هذه الجولة")

		# حذف العقوبة بعد تنفيذها مرة واحدة
		GameManager.clear_team_freeze(team_id)

		# تحديث لوحة الأحداث الجانبية
		if main_ui != null:
			main_ui.refresh_team_effect_panel(team_id)

		# إنهاء الدور بدون إظهار أماكن الحركة
		GameManager.end_turn()
		return

	# الخصم قد يكون مسيطرا على اتجاه حركة هذا الفريق هذه الجولة
	var controller: int = _get_direction_controller(team_id)
	if controller != 0:
		_show_direction_popup(controller, team_id, value)
		return

	highlight_reachable_sectors(value, team_positions[team_id])

# ======================================================
#   التحكم باتجاه حركة الفريق المنافس
# ------------------------------------------------------
# بطاقتان تعبران عن نفس الآلية من الجهتين:
#   CONTROL_OPPONENT_DIRECTION      تخزن على الفريق المسيطر
#   OPPONENT_CONTROLS_YOUR_DIRECTION تخزن على الفريق المقيد
# كلتاهما كانتا تخزنان دون أن يقرأهما أي كود حركة.
# ======================================================
const DIRECTION_UP := Vector2i(0, -1)
const DIRECTION_DOWN := Vector2i(0, 1)
const DIRECTION_LEFT := Vector2i(-1, 0)
const DIRECTION_RIGHT := Vector2i(1, 0)

var direction_popup: CanvasLayer = null


# يرجع رقم الفريق الذي يحدد الاتجاه، أو 0 إذا لا يوجد تحكم
func _get_direction_controller(moving_team: int) -> int:
	var other: int = GameManager.get_other_team_id(moving_team)

	# قيد مفروض على الفريق المتحرك
	if GameManagerHelper.has_effect(
		moving_team,
		GameManagerHelper.EffectType.OPPONENT_CONTROLS_YOUR_DIRECTION
	):
		return other

	# أو بطاقة سيطرة يملكها الخصم، وتخضع لمنع البطاقات المخزنة
	if GoodEffects.can_use_stored_good_cards(other) and GameManagerHelper.has_effect(
		other,
		GameManagerHelper.EffectType.CONTROL_OPPONENT_DIRECTION
	):
		return other

	return 0


# التأثير يستخدم مرة واحدة، فيحذف من الطرفين بعد الاختيار
func _clear_direction_effects(moving_team: int, controller_team: int) -> void:
	GameManagerHelper.remove_effect(
		moving_team,
		GameManagerHelper.EffectType.OPPONENT_CONTROLS_YOUR_DIRECTION
	)
	GameManagerHelper.remove_effect(
		controller_team,
		GameManagerHelper.EffectType.CONTROL_OPPONENT_DIRECTION
	)

	GameManagerHelper.effects_changed.emit(moving_team)
	GameManagerHelper.effects_changed.emit(controller_team)


func _team_display_name(team_id: int) -> String:
	if team_id == 1:
		return "الفريق الأزرق"
	return "الفريق الأحمر"


# ======================================================
# اسم الدالة: _show_direction_popup
# وظيفتها:
# نافذة اختيار الاتجاه، تبنى بالكود بالكامل بلا مشهد جديد.
# تظهر للفريق المسيطر بعد أن يرمي الفريق المقيد النرد
# ======================================================
func _show_direction_popup(controller_team: int, moving_team: int, steps: int) -> void:
	if direction_popup != null and is_instance_valid(direction_popup):
		direction_popup.queue_free()

	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	direction_popup = layer

	# تنتظر ضغطة اللاعب، فتقفل النرد حتى يختار اتجاها
	GameManagerHelper.push_input_block(layer, "direction_popup")

	var panel_size := Vector2(460, 300)
	var screen_size: Vector2 = get_viewport().get_visible_rect().size

	var panel := Panel.new()
	panel.size = panel_size
	panel.position = (screen_size - panel_size) / 2.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color("#FFFFFF")
	style.set_border_width_all(3)
	style.border_color = Color("#1976D2") if controller_team == 1 else Color("#D32F2F")
	style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", style)

	layer.add_child(panel)

	var title := Label.new()
	title.text = _team_display_name(controller_team) + " يحدد اتجاه حركة الخصم"
	title.size = Vector2(panel_size.x - 40, 40)
	title.position = Vector2(20, 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#1F1F1F"))
	panel.add_child(title)

	# الأزرار الأربعة موزعة على شكل صليب
	var mid := panel_size.x / 2.0
	# أسهم الاتجاهات: نستخدم U+2190..U+2193 لأن الخط arial.ttf
	# لا يحتوي على مثلثي اليسار/اليمين (U+25C0 / U+25B6) فتظهر مربعات رموز
	_add_direction_button(panel, "↑", DIRECTION_UP,
		Vector2(mid - 55, 70), moving_team, steps, controller_team)
	_add_direction_button(panel, "←", DIRECTION_LEFT,
		Vector2(mid - 175, 160), moving_team, steps, controller_team)
	_add_direction_button(panel, "→", DIRECTION_RIGHT,
		Vector2(mid + 65, 160), moving_team, steps, controller_team)
	_add_direction_button(panel, "↓", DIRECTION_DOWN,
		Vector2(mid - 55, 220), moving_team, steps, controller_team)


# ======================================================
# اسم الدالة: run_opening_roll_off
# وظيفتها:
# تدير قرعة البداية كاملة: كل فريق يضغط النرد بنفسه،
# وصاحب الرقم الأعلى يبدأ. عند التعادل تعاد القرعة للفريقين
# ======================================================
func run_opening_roll_off() -> void:
	roll_off_active = true

	var winner := 0
	var blue_roll := 0
	var red_roll := 0
	var round_index := 0

	while winner == 0 and round_index < ROLL_OFF_MAX_ROUNDS:
		round_index += 1

		blue_roll = await _roll_off_wait_for_team(1)
		red_roll = await _roll_off_wait_for_team(2)

		if blue_roll > red_roll:
			winner = 1
		elif red_roll > blue_roll:
			winner = 2
		else:
			await _show_roll_off_popup(
				"تعادل! إعادة الرمي",
				"%d — %d" % [blue_roll, red_roll],
				0
			)

	# حماية من دورة لا تنتهي بسبب خطأ برمجي
	if winner == 0:
		push_warning("قرعة البداية لم تحسم بعد %d جولات، سيبدأ الفريق الأزرق" % ROLL_OFF_MAX_ROUNDS)
		winner = 1

	await _show_roll_off_popup(
		_team_display_name(winner) + " سيبدأ اللعب",
		"%d — %d" % [blue_roll, red_roll],
		winner
	)

	# تسليم اللعب: نضبط الفريق البادئ دون إنقاص أي تأثيرات مؤقتة
	roll_off_active = false
	roll_off_accepting_click = false

	GameManager.current_team = winner
	GameManager.set_active_turn_players()
	update_turn_label(winner)
	GameManager.turn_changed.emit(winner)

	# اللعب العادي بدأ الآن: أشر إلى قطاع البداية
	show_start_hint()


# ======================================================
#   مؤشر "ابدأ من هنا"
# ------------------------------------------------------
# القطاع الذي يبدأ منه الفريقان هو sectors_map[team_positions]،
# أي Sector_01 عند (0,0). نثبّت المؤشر على مركز CollisionShape2D
# لا على الـ Sprite2D، لأن صورة القطاع فيها هوامش شفافة واسعة
# ======================================================
func show_start_hint() -> void:
	if is_instance_valid(start_hint) or start_hint_used:
		return

	var start_pos: Vector2i = team_positions[GameManager.current_team]

	if not sectors_map.has(start_pos):
		push_warning("لا يوجد قطاع بداية عند %s، لن يظهر المؤشر" % str(start_pos))
		return

	var cell = sectors_map[start_pos]

	# نلاحق CollisionShape2D لا العقدة نفسها، فهي مركز الخلية الحقيقي
	var anchor: Node2D = cell.get_node_or_null("CollisionShape2D")
	if anchor == null:
		anchor = cell

	var layer := CanvasLayer.new()
	layer.layer = START_HINT_LAYER
	add_child(layer)

	var hint: Node2D = START_HINT_SCRIPT.new()
	hint.follow_target = anchor

	if anchor is CollisionShape2D:
		var shape = (anchor as CollisionShape2D).shape
		if shape is RectangleShape2D:
			hint.cell_size = (shape as RectangleShape2D).size

	layer.add_child(hint)

	start_hint = hint
	start_hint_layer = layer

	print("مؤشر البداية: ظهر عند ", cell.name, " ", start_pos)


# يستدعى بعد أول حركة حقيقية، ولا يعود المؤشر بعدها أبدا
func hide_start_hint() -> void:
	start_hint_used = true

	if is_instance_valid(start_hint):
		start_hint.dismiss()

	if is_instance_valid(start_hint_layer):
		start_hint_layer.queue_free()

	start_hint = null
	start_hint_layer = null


# ينتظر ضغطة الفريق على النرد ويرجع النتيجة
func _roll_off_wait_for_team(team_id: int) -> int:
	await _show_roll_off_popup(
		_team_display_name(team_id) + ": اضغط النرد",
		"",
		team_id
	)

	# الآن فقط يقبل النرد الضغط
	roll_off_accepting_click = true
	var value: int = await roll_off_rolled
	roll_off_accepting_click = false

	return value


# ======================================================
# اسم الدالة: _show_roll_off_popup
# وظيفتها:
# إعلان مبني بالكود على نمط _show_direction_popup.
# يغلق بالضغط أو تلقائيا بعد ثلاث ثوان
# ======================================================
const ROLL_OFF_POPUP_SECONDS := 3.0

func _show_roll_off_popup(title_text: String, score_text: String, team_id: int) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 130
	add_child(layer)

	# الإعلان نفسه مانع كبقية النوافذ. استثناء القرعة في dice.gd
	# يخص نافذة "اضغط النرد" وحدها، وهي لحظة لا إعلان فيها
	GameManagerHelper.push_input_block(layer, "roll_off_popup")

	var panel_size := Vector2(540, 260 if score_text != "" else 200)
	var screen_size: Vector2 = get_viewport().get_visible_rect().size

	var panel := Panel.new()
	panel.size = panel_size
	panel.position = (screen_size - panel_size) / 2.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color("#FFFFFF")
	style.set_border_width_all(4)
	if team_id == 1:
		style.border_color = Color("#1976D2")
	elif team_id == 2:
		style.border_color = Color("#D32F2F")
	else:
		style.border_color = Color("#8A8A8A")
	style.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", style)

	layer.add_child(panel)

	var title := Label.new()
	title.text = title_text
	title.size = Vector2(panel_size.x - 40, 60)
	title.position = Vector2(20, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#1F1F1F"))
	panel.add_child(title)

	if score_text != "":
		var score := Label.new()
		score.text = score_text
		score.size = Vector2(panel_size.x - 40, 70)
		score.position = Vector2(20, 120)
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		score.add_theme_font_size_override("font_size", 44)
		score.add_theme_color_override("font_color", Color("#1F1F1F"))
		panel.add_child(score)

	# زر شفاف يغطي اللوحة كلها ليغلقها بالضغط
	var dismiss := Button.new()
	dismiss.flat = true
	dismiss.size = panel_size
	dismiss.position = Vector2.ZERO
	panel.add_child(dismiss)

	# لامبدا GDScript تلتقط المتغيرات المحلية بالنسخة لا بالمرجع،
	# فنستخدم قاموسا (نوع مرجعي) حتى يصل التغيير إلى هذه الدالة
	var state := {"done": false}

	dismiss.pressed.connect(func() -> void:
		state["done"] = true
	)

	var timer := get_tree().create_timer(ROLL_OFF_POPUP_SECONDS)
	timer.timeout.connect(func() -> void:
		state["done"] = true
	)

	while not state["done"]:
		await get_tree().process_frame

	if is_instance_valid(layer):
		GameManagerHelper.pop_input_block(layer)
		layer.queue_free()


func _add_direction_button(
	parent: Control,
	label: String,
	direction: Vector2i,
	at_position: Vector2,
	moving_team: int,
	steps: int,
	controller_team: int
) -> void:
	var button := Button.new()
	button.text = label
	button.size = Vector2(110, 60)
	button.position = at_position
	button.add_theme_font_size_override("font_size", 26)
	button.pressed.connect(
		_on_direction_chosen.bind(direction, moving_team, steps, controller_team)
	)
	parent.add_child(button)


func _on_direction_chosen(
	direction: Vector2i,
	moving_team: int,
	steps: int,
	controller_team: int
) -> void:
	# النافذة مغلقة أصلاً: تجاهل النقر المكرر على أكثر من سهم
	if direction_popup == null or not is_instance_valid(direction_popup):
		return

	# نحرّر القفل فورا: queue_free مؤجّل فتبقى العقدة صالحة هذا الإطار
	GameManagerHelper.pop_input_block(direction_popup)

	direction_popup.queue_free()
	direction_popup = null

	_clear_direction_effects(moving_team, controller_team)

	highlight_reachable_sectors(steps, team_positions[moving_team], direction)


# هل تقع الخلية في الاتجاه المطلوب بالنسبة لموقع البداية؟
# نفحص كل مواقع القطاع لأن القطاعات الكبيرة تشغل أكثر من خانة
func _matches_direction(start_pos: Vector2i, cell, direction: Vector2i) -> bool:
	if direction == Vector2i.ZERO:
		return true

	for pos in get_debug_cell_positions(cell):
		if direction.x > 0 and pos.x > start_pos.x:
			return true
		if direction.x < 0 and pos.x < start_pos.x:
			return true
		if direction.y > 0 and pos.y > start_pos.y:
			return true
		if direction.y < 0 and pos.y < start_pos.y:
			return true

	return false

#--------------------------------
# PLAYER
#-------------------------------
func get_current_player():
	var current_player = GameManager.teams[GameManager.current_team]["player"]
	var player_name = current_player.name
	label.text = player_name

	return current_player

	
	

func change_turn_from_GM() -> void:
	GameManager.end_turn()

		
#----------------------------------------------	
# -----------GRID (SECTORS)
#------------------------------------------------
func get_next_grid_pos(current_pos: Vector2i) -> Vector2i:
	var next := current_pos + Vector2i(1, 0)
	if sectors_map.has(next):
		return next
	return Vector2i(0, current_pos.y + 1)

func handle_sector(grid_pos: Vector2i) -> void:
	var team_id = GameManager.current_team
	var sector = sectors_map[grid_pos]

	sector.questions_used += 1
	sector.mark_as_team(team_id, team_colors[team_id])

	if sector.questions_used >= 2:
		sector.close_cell(team_id)
	
# direction != ZERO يعني أن الخصم فرض اتجاه الحركة هذه الجولة،
# فلا تضاء إلا الوجهات الواقعة في ذلك الاتجاه
func highlight_reachable_sectors(steps: int, start_pos: Vector2i, direction: Vector2i = Vector2i.ZERO) -> void:
	var queue: Array = []
	var highlighted_cells := {}

	if not sectors_map.has(start_pos):
		return

	var start_cell = sectors_map[start_pos]

	queue.append({
		"cell": start_cell,
		"steps": 0,
		"visited": {
			start_cell.get_instance_id(): true
		}
	})

	while queue.size() > 0:
		var current = queue.pop_front()

		var current_cell = current["cell"]
		var current_steps: int = current["steps"]
		var visited: Dictionary = current["visited"]

		if current_steps == steps:
			var cell_id: int = current_cell.get_instance_id()

			# لا نضيء الخلية المغلقة كنهاية حركة
			if not current_cell.is_closed and not highlighted_cells.has(cell_id):
				if _matches_direction(start_pos, current_cell, direction):
					current_cell.highlight()
					current_cell.show_step_number(current_steps)
					highlighted_cells[cell_id] = true

			continue

		var neighbors: Array = get_debug_logical_neighbors(current_cell)

		for neighbor_data in neighbors:
			var next_cell = neighbor_data["cell"]
			var next_id: int = next_cell.get_instance_id()

			if visited.has(next_id):
				continue

			var next_steps: int = current_steps

			# المغلق لا يحتسب في العد
			if not next_cell.is_closed:
				next_steps += 1

			if next_steps > steps:
				continue

			var new_visited: Dictionary = visited.duplicate()
			new_visited[next_id] = true

			queue.append({
				"cell": next_cell,
				"steps": next_steps,
				"visited": new_visited
			})

	# إذا لم يترك الاتجاه المفروض أي وجهة ممكنة، نرفع القيد
	# حتى لا يبقى الفريق بلا حركة ويتوقف الدور
	if direction != Vector2i.ZERO and highlighted_cells.is_empty():
		print("لا توجد وجهة في هذا الاتجاه، تم رفع القيد عن الحركة")
		highlight_reachable_sectors(steps, start_pos, Vector2i.ZERO)

func clear_sector_highlights() -> void:
	for sector in sectors_map.values():
		sector.clear_highlight()
		sector.hide_step_number()

func _on_sector_selected(cell) -> void:
	#print("HANDLE _on_sector_selected CALLED FROM = ", get_stack())
	if is_moving:
		return


	clear_sector_highlights()
	is_moving = true

	var active_player = team_players[current_team]
	
	var offset := Vector2.ZERO

	if current_team == 1:
		offset = Vector2(-20, 0)
	else:
		offset = Vector2(20, 0)
	
	#GameManager.current_team=current_team

	var tween := create_tween()
	tween.tween_property(active_player, "global_position", cell.global_position + offset, 1)
	await tween.finished

	active_player.allowed_position = cell.global_position + offset
	active_player.global_position = active_player.allowed_position

	team_positions[current_team] = cell.grid_pos

	# أول حركة حقيقية اكتملت: لم يعد المؤشر لازما
	hide_start_hint()

	var team_id = GameManager.current_team
	board_cell_action_handler.handle_cell(cell)

	#handle_sector(cell.grid_pos)

	is_moving = false
	#GameManager.end_turn()


# ======================================================
# اسم الدالة: is_any_card_open
# وظيفتها:
# هل توجد بطاقة أو نافذة معروضة الآن فوق اللوحة؟
#
# تغطي الحالات الثلاث:
#   SectorQuestionCard : سؤال القطاع، وهو نفسه المستخدم لسؤال المعركة
#   StreetCard         : بطاقة حدث الشارع
#   BattlePopup        : نافذة اختيار من يجيب في المعركة
#
# تستخدمها dice.gd لمنع رمي النرد ما دامت بطاقة مفتوحة.
# الفحص يقرأ visible مباشرة بدل تتبع حالة منفصلة، فلا يمكن
# أن تختل المزامنة لو أغلقت بطاقة من مسار لم نتوقعه
# ======================================================
# ======================================================
# اسم الدالة: is_dice_locked
# وظيفتها:
# نقطة الفحص الوحيدة التي يستعملها النرد.
#
# البطاقات الثلاث تُفحص عبر is_any_card_open كما كانت، ولا
# تسجّل نفسها في سجل الموانع حتى لا تُحجب مرتين. أما النوافذ
# المبنية بالكود والمشاهد المنبثقة فتسجّل نفسها في السجل
# ======================================================
func is_dice_locked() -> bool:

	if is_any_card_open():
		return true

	return GameManagerHelper.is_input_locked()


func is_any_card_open() -> bool:
	if is_instance_valid(SectorQuestionCard) and SectorQuestionCard.visible:
		return true

	if is_instance_valid(StreetCard) and StreetCard.visible:
		return true

	if is_instance_valid(BattlePopup) and BattlePopup.visible:
		return true

	return false


# ======================================================
# اسم الدالة: show_grid_pos_labels
# وظيفتها:
# إظهار إحداثيات الشبكة فوق كل قطاع، وهي أداة تطوير فقط.
#
# كانت تعمل دائما، فتظهر أرقام صفراء وبرتقالية فوق كل قطاعات
# اللوحة حتى في النسخة النهائية التي يلعبها اللاعبون.
#
# OS.is_debug_build() ترجع true عند التشغيل من المحرر أو من تصدير
# debug، وترجع false في تصدير الإصدار (export-release) وهو الهدف
# الأساسي للعبة. هكذا تبقى الملصقات ظاهرة أثناء التطوير فقط
# دون الحاجة لتذكر تعطيلها قبل كل تصدير.
# ======================================================
func show_grid_pos_labels() -> void:
	if not OS.is_debug_build():
		return

	var debug_labels := Node2D.new()
	debug_labels.name = "Grid_Pos_Labels"
	add_child(debug_labels)

	for sector in get_tree().get_nodes_in_group("board_sectors"):
		var main_label := Label.new()
		main_label.visible= false
		main_label.text = str(sector.grid_pos)
		main_label.z_index = 100
		main_label.position = to_local(sector.global_position) + Vector2(-25, -45)
		main_label.add_theme_font_size_override("font_size", 22)
		main_label.add_theme_color_override("font_color", Color.YELLOW)
		main_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		main_label.add_theme_constant_override("shadow_offset_x", 2)
		main_label.add_theme_constant_override("shadow_offset_y", 2)
		debug_labels.add_child(main_label)

		#var v_pos
		# ملصق واحد لكل قطاع يجمع كل المواقع الإضافية، ويضاف مرة واحدة بعد اكتمال النص
		if not sector.extra_grid_positions.is_empty():
			var extra_label := Label.new()
			extra_label.visible= false
			
			for pos in sector.extra_grid_positions:
				extra_label.text = extra_label.text+" , "+str(pos)
			extra_label.z_index = 100
			extra_label.position = to_local(sector.global_position) + Vector2(10, -10)
			extra_label.add_theme_font_size_override("font_size", 18)
			extra_label.add_theme_color_override("font_color", Color.ORANGE)
			extra_label.add_theme_color_override("font_shadow_color", Color.BLACK)
			extra_label.add_theme_constant_override("shadow_offset_x", 2)
			extra_label.add_theme_constant_override("shadow_offset_y", 2)
			debug_labels.add_child(extra_label)

func update_turn_label(c_team) -> void:
	if c_team == 1:
		turn_label.text = "🔵 دور الفريق الازرق"
		turn_label.modulate = Color(0.3, 0.5, 1)

	elif c_team == 2:
		turn_label.text = "🔴 دور الفريق الاحمر"
		turn_label.modulate = Color(1, 0.25, 0.25)

func stop_dragging() -> void:
	is_dragging = false

# ----------------------------------
#func cancel_one_team_investment(team_id: int) -> void:
	#for cell in sectors.get_children():
		#if cell.is_sector() and cell.owner_team == team_id:
			#cell.cancel_investment()
			##var temp_old_effects =  GameManagerHelper.team_effects[team_id][2]["card_data"]["id"]
			##if temp_old_effects==3:
				##GameManagerHelper.effects_data[2]["description"]=(
				##"تم إلغاء استثمار للفريق: " +	str(team_id) +	" في القطاع " +	cell.name)
				###GameManagerHelper.team_effects[team_id][2]["card_data"]["description"]=(
				###"تم إلغاء استثمار للفريق: " +	str(team_id) +	" في القطاع " +	cell.name)
				##GameManagerHelper.effects_changed.emit(team_id)
			#print("تم إلغاء استثمار للفريق: ", team_id, " في القطاع: ", cell.name)
			#return
#
	#print("لا يوجد قطاع مملوك للفريق ", team_id)
#
#func apply_cancel_investment_effect_if_needed(cell, card_data: Dictionary = {}) -> void:
	#var team_id = GameManager.current_team
#
	## تأكد أن القطاع مملوك للفريق نفسه
	#if cell.owner_team != team_id:
		#print("لا يوجد استثمار لهذا الفريق في هذا القطاع")
		#return
#
	## إلغاء ملكية القطاع
	#cell.owner_team = 0
	#cell.questions_used = 0
#
	## إعادة شكل القطاع إذا عندك دالة خاصة
	#if cell.has_method("reset_sector_visual"):
		#cell.reset_sector_visual()
#
	## وصف الحدث الذي سنخزنه
	#var description : String = "تم إلغاء استثمار للفريق: " + str(team_id) + " في القطاع " + cell.name
	##var description: String = "تم إلغاء استثمار للفريق: " \
	##+ str(team_id) \
	##+ " في القطاع " \
	##+ cell.name
#
	## تخزين التأثير
	#GameManagerHelper.add_effect(
		#team_id,
		#GameManagerHelper.EffectType.CANCEL_ONE_INVESTMENT,
		#{
			#"card_data": card_data,
			#"sector_name": cell.name,
			#"description": description,
			## هذا يعني: اعرضه على اللوحة لمدة دور واحد فقط
			#"display_turns_left": 1
		#}
	#)
#
	#print(description)	
##func apply_cancel_investment_effect_if_needed(team_id: int) -> void:
	##print("inside apply_cancel_investment_effect_if_needed")
	##if GameManagerHelper.has_effect(team_id, GameManagerHelper.EffectType.CANCEL_ONE_INVESTMENT):
		##cancel_one_team_investment(team_id)
		##GameManagerHelper.remove_effect(team_id, GameManagerHelper.EffectType.CANCEL_ONE_INVESTMENT)
##
		##print("تم تنفيذ وحذف تأثير CANCEL_ONE_INVESTMENT للفريق: ", team_id)
		#
func apply_cancel_investment_effect_if_needed(team_id: int, card_data: Dictionary = {}) -> void:
	# نبحث عن قطاع مملوك للفريق
	var selected_sector = null

	for sector in sectors.get_children():
		if not sector.has_method("is_sector"):
			continue

		#if not sector.is_sector():
			#continue

		if sector.owner_team == team_id:
			selected_sector = sector
			break

	# إذا لم نجد قطاع مملوك للفريق
	if selected_sector == null:
		print("لا يوجد قطاع مملوك للفريق: ", team_id)
		return

	# إلغاء ملكية القطاع
	selected_sector.owner_team = 0
	selected_sector.questions_used = 0

	# إعادة شكل القطاع إذا عندك دالة خاصة داخل سكربت القطاع
	if selected_sector.has_method("reset_sector"):
		selected_sector.reset_sector()

	# تجهيز وصف الحدث الذي سيظهر في اللوحة الجانبية
	var description: String = "تم إلغاء استثمار للفريق: " \
		+ str(team_id) \
		+ " في القطاع " \
		+ selected_sector.name

	#GameManagerHelper.remove_effect(team_id, GameManagerHelper.EffectType.CANCEL_ONE_INVESTMENT)
	# الآن نخزن التأثير بعد أن عرفنا اسم القطاع
	GameManagerHelper.add_effect(
		team_id,
		GameManagerHelper.EffectType.CANCEL_ONE_INVESTMENT,
		{
			"card_data": card_data,
			"sector_name": selected_sector.name,
			"description": description,
			"display_turns_left": 2
		}
	)

#---------------------------------------
func apply_cancel_investment_for_other_team(team_id: int, card_data: Dictionary = {}) -> void:
	# نبحث عن قطاع مملوك للفريق
	var selected_sector = null
	
	var other_team = 1
	if team_id==1:
		other_team=2
	#else:
		#other_team=1

	for sector in sectors.get_children():
		if not sector.has_method("is_sector"):
			continue

		#if not sector.is_sector():
			#continue

		if sector.owner_team == team_id:
			selected_sector = sector
			break

	# إذا لم نجد قطاع مملوك للفريق
	if selected_sector == null:
		print("لا يوجد قطاع مملوك للفريق: ", team_id)
		return

	# إلغاء ملكية القطاع
	selected_sector.owner_team = other_team
	
	var v_is_locked= selected_sector.is_locked
	
	selected_sector.mark_as_team(other_team, team_colors[other_team])
	if v_is_locked>=1:
		selected_sector.close_cell(other_team)

	# تجهيز وصف الحدث الذي سيظهر في اللوحة الجانبية
	var description: String = "تم إلغاء استثمار للفريق: " \
		+ str(team_id) \
		+ " في القطاع " \
		+ selected_sector.name \
		+ " وتم منحه للفريق " \
		+ str(other_team)

	# الآن نخزن التأثير بعد أن عرفنا اسم القطاع.
	# هذه البطاقة (220) تنقل القطاع للخصم ولا تلغيه، فتسجل تحت
	# TRANSFER_ONE_OWNED_SECTOR_TO_OPPONENT. تسجيلها سابقا تحت
	# CANCEL_ONE_INVESTMENT كان يظهر اسم بطاقة أخرى في لوحة الفريق
	GameManagerHelper.add_effect(
		team_id,
		GameManagerHelper.EffectType.TRANSFER_ONE_OWNED_SECTOR_TO_OPPONENT,
		{
			"card_data": card_data,
			"sector_name": selected_sector.name,
			"description": description,
			"display_turns_left": 2
		}
	)

# ترجع الخلايا المجاورة أعلى/أسفل/يمين/يسار فقط
func get_debug_neighbors(pos: Vector2i) -> Array:
	return [
		Vector2i(pos.x + 1, pos.y),
		Vector2i(pos.x - 1, pos.y),
		Vector2i(pos.x, pos.y + 1),
		Vector2i(pos.x, pos.y - 1)
	]
# =====================================================
# جلب كل المواقع التابعة لنفس الخلية
# مثال:
# sector.grid_pos = (2,2)
# sector.extra_grid_positions = [(2,3), (2,4)]
# النتيجة:
# [(2,2), (2,3), (2,4)]
# =====================================================
func get_debug_cell_positions(cell) -> Array:
	var positions: Array = []

	positions.append(cell.grid_pos)

	if "extra_grid_positions" in cell:
		for extra_pos in cell.extra_grid_positions:
			positions.append(extra_pos)

	return positions

# =====================================================
# جلب الجيران المنطقيين للخلية
# إذا كانت الخلية قطاعا كبيرا، نفحص كل أجزائه
# ونرجع الخلايا المجاورة المختلفة فقط
# =====================================================
func get_debug_logical_neighbors(cell) -> Array:
	var neighbors: Array = []
	var added_ids := {}

	var cell_id: int = cell.get_instance_id()
	var positions: Array = get_debug_cell_positions(cell)

	for pos in positions:
		var directions := [
			Vector2i(pos.x + 1, pos.y),
			Vector2i(pos.x - 1, pos.y),
			Vector2i(pos.x, pos.y + 1),
			Vector2i(pos.x, pos.y - 1)
		]

		for next_pos in directions:
			if not sectors_map.has(next_pos):
				continue

			var next_cell = sectors_map[next_pos]
			var next_id: int = next_cell.get_instance_id()

			# لا نحسب الحركة داخل نفس القطاع الكبير
			if next_id == cell_id:
				continue

			# منع تكرار نفس الجار أكثر من مرة
			if added_ids.has(next_id):
				continue

			added_ids[next_id] = true

			neighbors.append({
				"cell": next_cell,
				"entry_pos": next_pos
			})

	return neighbors

# ======================================================
# اسم الدالة: show_choose_dice_popup
# وظيفتها:
# إظهار نافذة اختيار رقم حجر النرد للفريق الحالي
# ======================================================
func show_choose_dice_popup(p_effect_no:int=1) -> void:
	var popup = choose_dice_popup_scene.instantiate()
	add_child(popup)
	
	# الأوضاع الثلاثة يستبعد بعضها بعضا: بدون elif كان الوضع 2
	# يسقط في else فيستدعي show_choose_number ويخفي لوحة الرميتين
	if p_effect_no==2:
		popup.show_two_rolls(GoodEffects.firstRoll,GoodEffects.secondRoll)
	elif p_effect_no==3:
		popup.show_choos_first()
	else:
		popup.show_choose_number()

	popup.dice_value_selected.connect(_on_dice_value_selected)


		

# ======================================================
# اسم الدالة: _on_dice_value_selected
# وظيفتها:
# استقبال الرقم المختار من اللاعب
# واستخدامه كأنه نتيجة حجر النرد
# ======================================================
func _on_dice_value_selected(value: int) -> void:
	#var team_id= GameManager.current_team
	#GameManagerHelper.remove_effect(team_id,GameManagerHelper.EffectType.CHOOSE_NEXT_DICE_NUMBER)
	
	# هنا استدعِ نفس الدالة التي تستخدمها بعد رمي النرد العادي
	_on_dice_rolled(value)
	
