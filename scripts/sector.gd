extends Area2D

# صور القطاع حسب حالة الملكية
@export var normal_texture: Texture2D
@export var blue_texture: Texture2D
@export var red_texture: Texture2D
@export var basic_texture : Texture2D

@onready var label: Label = $Label
@onready var owner_mark: ColorRect = $OwnerMark
@onready var step_label: Label = $StepLabel
@export var cell_type: CellType = CellType.SECTOR

@onready var sprite: Sprite2D = $Sprite2D
@export var sector_id: int = 0
@export var sector_name: String = ""
@export var grid_pos: Vector2i = Vector2i(0, 0)
@export var extra_grid_positions: Array[Vector2i] = []

# خاص بالاقفال
@onready var lock_sprite: Sprite2D = $LockSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@export var red_lock_texture: Texture2D
@export var blue_lock_texture: Texture2D
@export var gray_lock_texture: Texture2D
@export var neutral_lock_texture: Texture2D

# نقطة صغيرة تعلو القطاع الذي أخطأ أول من مرّ عليه، فتذكّر اللاعبين
# بأن له سؤالا ثانيا لم يُستخدم بعد.
# النقطة تومض بين درجتين من الأصفر حتى تلفت النظر وسط رسوم اللوحة
@export var pending_dot_texture: Texture2D
@export var pending_dot_deep_texture: Texture2D

# مدة بقاء كل درجة قبل التبديل. 0.55 ثانية تعطي نبضة هادئة تُرى
# من بعيد ولا تشتت الانتباه عن اللوحة
const PENDING_DOT_BLINK_SECONDS := 0.55

# حجم وموقع أيقونة القفل — موحّدة لكل القطاعات.
# صور الأقفال الثلاثة بنفس المقاس وبنفس الشارة البيضاء، ومع ذلك
# يُحسب المقياس من حجم الصورة حتى يبقى الحجم موحّدا لو تغيرت صورة.
const LOCK_ICON_SIZE := 52.0     # أقصى بُعد للقفل بالبكسل
const PENDING_DOT_SIZE := 34.0   # نقطة الفرصة الثانية، أصغر بكثير

# موضع القفل: إزاحة من مركز رسم القطاع نحو أعلى اليمين، بنسبة من
# عرض الرسم وارتفاعه. رسوم القطاعات بقع دائرية محاطة بأشجار، فحدود
# الصورة الخارجية تقع فوق الأشجار لا على القطاع نفسه. الإزاحة من
# المركز تبقي القفل داخل البقعة في كل القطاعات، وبنفس النسبة
const LOCK_CENTER_OFFSET_RATIO := Vector2(0.30, -0.22)

enum CellType {
	SECTOR,
	STREET
}

signal sector_selected(sector)
signal sector_closed

var is_highlighted := false

# خاص بالقطاع
@export var questions_used: int = 0:
	set(value):
		questions_used = value
		_update_sector_lock()
@export var is_locked: int = 0

#var questions_used: int = 0
var owner_team: int = 0

# خاص بالشارع
var visits_count: int = 0

# صور الشارع حسب عدد مرات المرور عليه
# العداد مشترك بين الفريقين (أي مرور يزيده) كما هو الحال في باقي اللعبة.
# تُترك فارغة للشوارع العمودية التي لا تملك صوراً بديلة بعد.
@export var street_first_texture: Texture2D
@export var street_second_texture: Texture2D

# مشترك بين القطاع والشارع
var is_closed: bool = false
var is_broken: bool = false

var highlight_tween: Tween
var owner_color: Color = Color.WHITE

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	owner_mark.visible = false
	label.visible = false

	lock_sprite.z_index = 100
	lock_sprite.visible = false
	lock_sprite.centered = true

	_update_sector_lock()



# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(_delta: float) -> void:
	#pass


func _on_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if is_highlighted and not is_closed:
				sector_selected.emit(self)
	

func is_sector() -> bool:
	GameManagerHelper.last_effect_source_type = "SECTOR"
	return cell_type == CellType.SECTOR


func is_street() -> bool:
	GameManagerHelper.last_effect_source_type = "STREET"
	return cell_type == CellType.STREET
					
#func close_cell(team_id: int = 0) -> void:
	#is_closed = true
	#is_broken = false
#
	#lock_sprite.visible = true
	#lock_sprite.z_index = 100
	##questions_used= 2
	#
	#if is_locked == 1:
		#pass
	#else:
		#owner_team = team_id
			#
	#match team_id:
		#1:
			#lock_sprite.texture = blue_lock_texture
			#sprite.modulate = Color(0.5, 0.7, 1.0)
#
		#2:
			#lock_sprite.texture = red_lock_texture
			#sprite.modulate = Color(1.0, 0.45, 0.45)
#
		#_:
			#lock_sprite.texture = gray_lock_texture
			#sprite.modulate = Color(0.35, 0.35, 0.35, 1.0)

# توحيد حجم وموقع أيقونة القفل في الزاوية العلوية اليمنى لكل القطاعات.
# تُستدعى بعد كل تعيين لصورة القفل.
func _apply_lock_icon_layout(icon_size: float = LOCK_ICON_SIZE) -> void:
	if lock_sprite == null or lock_sprite.texture == null:
		return

	# المقياس محسوب من أبعاد الصورة مع الحفاظ على نسبة العرض إلى الارتفاع
	var tex_size: Vector2 = lock_sprite.texture.get_size()
	var largest_side: float = max(tex_size.x, tex_size.y)
	if largest_side <= 0.0:
		return
	var icon_scale: float = icon_size / largest_side
	lock_sprite.scale = Vector2(icon_scale, icon_scale)

	# الموقع محسوب من حدود الرسم الظاهر في صورة القطاع، لا من
	# مستطيل الصورة كاملا ولا من شكل الاصطدام. صور القطاعات تحمل
	# هوامش شفافة مختلفة، وشكل الاصطدام أوسع من الرسم، وكلاهما
	# كان يدفع القفل خارج حدود القطاع ويجعل موضعه يقفز بين قطاع وآخر
	var rect: Rect2 = _sector_footprint()
	if rect.size == Vector2.ZERO:
		return

	lock_sprite.position = rect.get_center() + rect.size * LOCK_CENTER_OFFSET_RATIO


# حدود الرسم الظاهر في القطاع بإحداثيات العقدة.
# ترجع حدود البكسلات غير الشفافة في صورة القطاع، فينطبق القفل
# على الرسم نفسه مهما اختلفت هوامش الصورة
func _sector_footprint() -> Rect2:
	if sprite != null and sprite.texture != null:
		var tex_size: Vector2 = sprite.texture.get_size()
		var opaque: Rect2 = _opaque_rect(sprite.texture)

		if opaque.size.x > 0.0 and opaque.size.y > 0.0:
			var offset: Vector2 = opaque.position - tex_size * 0.5
			var top_left: Vector2 = offset * sprite.scale
			return Rect2(sprite.position + top_left, opaque.size * sprite.scale)

		var art: Vector2 = tex_size * sprite.scale
		return Rect2(sprite.position - art * 0.5, art)

	if collision_shape != null and collision_shape.shape is RectangleShape2D:
		var box: Vector2 = (collision_shape.shape as RectangleShape2D).size
		return Rect2(collision_shape.position - box * 0.5, box)

	return Rect2()


# ======================================================
# حدود البكسلات غير الشفافة في صورة، بإحداثيات الصورة.
# القياس يمر بخطوة ثابتة لأن الدقة المطلوبة بضعة بكسلات فقط،
# والنتيجة تخزَّن لكل صورة فلا تُقاس إلا مرة واحدة في الجلسة
# ======================================================
const OPAQUE_SCAN_STRIDE := 4
const OPAQUE_ALPHA_MIN := 24

static var _opaque_rect_cache := {}


static func _opaque_rect(texture: Texture2D) -> Rect2:
	var key: String = texture.resource_path
	if key != "" and _opaque_rect_cache.has(key):
		return _opaque_rect_cache[key]

	var result := Rect2()
	var src: Image = texture.get_image()

	if src != null:
		var img := Image.new()
		img.copy_from(src)
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)

		var w: int = img.get_width()
		var h: int = img.get_height()
		var min_x: int = w
		var min_y: int = h
		var max_x: int = -1
		var max_y: int = -1

		var y: int = 0
		while y < h:
			var x: int = 0
			while x < w:
				if img.get_pixel(x, y).a8 >= OPAQUE_ALPHA_MIN:
					min_x = min(min_x, x)
					max_x = max(max_x, x)
					min_y = min(min_y, y)
					max_y = max(max_y, y)
				x += OPAQUE_SCAN_STRIDE
			y += OPAQUE_SCAN_STRIDE

		if max_x >= 0:
			result = Rect2(
				Vector2(min_x, min_y),
				Vector2(max_x - min_x + 1, max_y - min_y + 1)
			)

	if key != "":
		_opaque_rect_cache[key] = result

	return result


func close_cell(team_id: int = 0) -> void:
	is_closed = true
	is_broken = false

	lock_sprite.visible = true
	lock_sprite.z_index = 100
	if is_locked == 1:
		pass
	else:
		owner_team = team_id
	# حدّث الصورة والقفل بعد تثبيت المالك، لا حسب الفريق المرسل فقط.
	update_sector_owner_image()

	_apply_lock_icon_layout()
	if cell_type == CellType.SECTOR:
		sector_closed.emit()


func highlight() -> void:
	if is_closed:
		return

	# لون قوي
	if owner_team==1 || owner_team==2:
		pass
	else:
		sprite.modulate = Color(1.0, 0.9, 0.2, 1.0)

	# أوقف أي Tween سابق
	if highlight_tween:
		highlight_tween.kill()

	scale = Vector2(1.1, 1.1)

	# أنشئ Tween جديد
	highlight_tween = create_tween().set_loops()
	highlight_tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.8)
	highlight_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.8)
	is_highlighted = true
		
func clear_highlight() -> void:
	
	# 🔥 أهم سطر
	if highlight_tween:
		highlight_tween.kill()
		highlight_tween = null

	# رجّع الحجم الطبيعي
	scale = Vector2(1, 1)
	
	is_highlighted = false

	# رجّع اللون
	if is_closed:
		update_sector_owner_image()
		if owner_team == 0:
			if cell_type == CellType.STREET:
				return
			sprite.modulate = Color(0.35, 0.35, 0.35, 1.0)
		else:
			sprite.modulate = Color(1, 1, 1, 1)
	#elif is_broken:
		#sprite.modulate = Color(1.0, 0.55, 0.25, 1.0)
	#elif owner_team != 0:
		#sprite.modulate = owner_color
	elif owner_team != 0:
		update_sector_owner_image()
		sprite.modulate = Color(1, 1, 1, 1)
	
	else:
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		
		
func reset_sector() -> void:
	
	is_closed = 0
	is_locked = 0
	lock_sprite.visible = false
	
	# 🔥 أهم سطر
	if highlight_tween:
		highlight_tween.kill()
		highlight_tween = null
	# رجّع الحجم الطبيعي
	scale = Vector2(1, 1)	
	is_highlighted = false
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	update_sector_owner_image()

func mark_as_team(team_id: int, color: Color) -> void:
	owner_team = team_id
	owner_color = color

	# تغيير صورة القطاع حسب الفريق
	update_sector_owner_image()

	# لا نحتاج تلوين الصورة إذا كانت الصورة نفسها زرقاء/حمراء
	sprite.modulate = Color(1, 1, 1, 1)

	label.text = str(team_id)
	owner_mark.visible = false
	label.visible = false
	owner_mark.color = color

	match team_id:
		1:
			label.text = "B"
		2:
			label.text = "G"
		_:
			label.text = "?"

#func mark_as_team(team_id: int, color: Color) -> void:
	#owner_team = team_id
	#sprite.modulate = color
	#owner_color = color
	#label.text = str(team_id)
	#owner_mark.visible = true
	#label.visible = true
	#owner_mark.color = color
	#match team_id:
		#1:
			#label.text = "B"
		#2:
			#label.text = "G"
		#_:
			#label.text = "?"

# بعد ما قمنا بإنشاء الشوارع
func register_street_visit() -> void:
	if not is_street():
		return
	
	if is_closed:
		return
	
	visits_count += 1

	if visits_count == 1:
		break_street()

	elif visits_count >= 2:
		close_cell()
		# close_cell() يستبدل الصورة ويضيف تعتيماً رمادياً،
		# لذلك نُعيد صورة المرور الثاني بعده وليس قبله.
		_apply_street_texture(street_second_texture)

# تغيير صورة الشارع مع الحفاظ على مساحته الظاهرة على اللوحة.
#
# صور الحالات الثلاث (سليم، أول مرور، ثاني مرور) صارت على قياس واحد
# لكل اتجاه، والطريق مرسوم في الموضع نفسه داخل كل صورة، فالتبديل
# بينها لا يحرك شيئا ولا يحتاج أي معاملات تصحيح.
#
# القسمة أدناه تبقى كحماية: لو استُبدلت صورة بأخرى بقياس مختلف
# لاحقا، يُعاد حساب المقياس تلقائيا فلا يتمدد البلاط فوق القطاعات
# المجاورة. وهي تضرب المقياس الحالي فتحافظ على إشارته لو كان مقلوبا
func _apply_street_texture(tex: Texture2D) -> void:
	if sprite == null or tex == null or sprite.texture == null:
		return

	var old_size: Vector2 = sprite.texture.get_size()
	var new_size: Vector2 = tex.get_size()

	if new_size.x <= 0.0 or new_size.y <= 0.0:
		return

	sprite.scale = Vector2(
		sprite.scale.x * (old_size.x / new_size.x),
		sprite.scale.y * (old_size.y / new_size.y)
	)
	sprite.texture = tex


func break_street() -> void:
	if cell_type != CellType.STREET:
		return

	is_broken = true
	_apply_street_texture(street_first_texture)



func show_step_number(step: int) -> void:
	step_label.text = str(step)
	step_label.visible = false

func hide_step_number() -> void:
	step_label.text = ""
	step_label.visible = false
	
func occupies_position(pos: Vector2i) -> bool:
	if pos == grid_pos:
		return true

	if pos in extra_grid_positions:
		return true

	return false
	
	
func get_all_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []

	positions.append(grid_pos)

	for extra_pos in extra_grid_positions:
		positions.append(extra_pos)
	return positions

# --------------
# المعركة
#-------------
#func set_neutral_closed() -> void:
	#is_closed = true
	#owner_team = -1
	#sprite.modulate = Color.GRAY
	#show_neutral_lock()
func close_neutral_cell() -> void:
	# القفل المحايد الناتج عن المعركة يستخدم الآن نفس مظهر القفل الرمادي
	# الناتج عن استنفاد الأسئلة (gray_lock_texture + تعتيم رمادي 0.35)،
	# لتوحيد شكل القطاع المقفل رماديًا في كل اللعبة.
	# نضبط المالك على -1 قبل الاستدعاء، لأن قطاع المعركة يكون is_locked == 1
	# فلا تعيد close_cell تعيين المالك، فيبقى محايدًا كما نريد.
	owner_team = -1
	close_cell(-1)

func shake_cell() -> void:
	var p := position
	#battle_start_sound.play()
	

	var tween := create_tween()

	tween.tween_property(self, "position", p + Vector2(8, -4), 0.05)
	tween.tween_property(self, "position", p + Vector2(-8, 4), 0.05)
	tween.tween_property(self, "position", p + Vector2(6, -6), 0.05)
	tween.tween_property(self, "position", p + Vector2(-6, 6), 0.05)
	tween.tween_property(self, "position", p, 0.05)

	await tween.finished

func flash_red() -> void:
	var original_modulate := modulate

	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 0.25, 0.25), 0.12)
	tween.tween_property(self, "modulate", original_modulate, 0.12)
	tween.tween_property(self, "modulate", Color(1, 0.25, 0.25), 0.12)
	tween.tween_property(self, "modulate", original_modulate, 0.12)

	await tween.finished	

func cancel_investment() -> void:
	is_closed = false
	is_broken = false
	owner_team = 0
	questions_used = 0
	update_sector_owner_image()

	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

	owner_color = Color.WHITE
	owner_mark.visible = false
	label.visible = false
	label.text = ""

	_update_sector_lock()

	clear_highlight()

	print("تمت إعادة القطاع كقطاع غير مملوك: ", name)

# تغيير صورة القطاع حسب الفريق المالك
func update_sector_owner_image() -> void:
	#print("owner_team=", owner_team, " blue_texture=", blue_texture)
	
	#print("owner_team=",owner_team)
	
	if sprite == null:
		return

	if owner_team == 1:
		if blue_texture != null:
			sprite.texture = blue_texture

	elif owner_team == 2:
		if red_texture != null:
			sprite.texture = red_texture

	else:
		if normal_texture != null:
			if is_closed:
				sprite.texture = normal_texture
			else:
				sprite.texture = basic_texture
	_update_sector_lock()


# ======================================================
# علامة القطاع
# ------------------------------------------------------
# ثلاث حالات لا رابع لها:
#
#   مقفل                     -> قفل بلون مالكه (أو رمادي للمحايد)
#   مفتوح وله مالك           -> لا علامة. فريق أجاب أولا وفاز به،
#                               ويبقى قابلا لإعادة المرور أو للمعركة
#   مفتوح بلا مالك وسؤال مستهلك -> نقطة صغيرة: أول من مرّ عليه أخطأ،
#                               فله فرصة ثانية لم تُستخدم بعد
#
# القطاع الذي لم يُلعب بعد لا يحمل أي علامة
# ======================================================
var _pending_dot_blink: Tween = null


# ======================================================
# وميض نقطة الفرصة الثانية
# ------------------------------------------------------
# دورة لا نهائية تبدّل صورة النقطة بين الدرجة الفاتحة والغامقة.
# الصورتان بنفس المقاس، فلا يتغير المقياس مع التبديل ولا يحتاج
# الأمر إعادة حساب الموضع في كل نبضة
# ======================================================
func _start_pending_dot_blink() -> void:
	if pending_dot_deep_texture == null:
		return

	# الوميض شغّال أصلا: لا نعيد تشغيله فتُقطع الدورة في منتصفها
	if _pending_dot_blink != null and _pending_dot_blink.is_valid():
		return

	_pending_dot_blink = create_tween().set_loops()
	_pending_dot_blink.tween_callback(_set_dot_light)
	_pending_dot_blink.tween_interval(PENDING_DOT_BLINK_SECONDS)
	_pending_dot_blink.tween_callback(_set_dot_deep)
	_pending_dot_blink.tween_interval(PENDING_DOT_BLINK_SECONDS)


func _set_dot_light() -> void:
	if lock_sprite != null:
		lock_sprite.texture = pending_dot_texture


func _set_dot_deep() -> void:
	if lock_sprite != null:
		lock_sprite.texture = pending_dot_deep_texture


func _stop_pending_dot_blink() -> void:
	if _pending_dot_blink != null and _pending_dot_blink.is_valid():
		_pending_dot_blink.kill()
	_pending_dot_blink = null


func _update_sector_lock() -> void:
	if cell_type != CellType.SECTOR or lock_sprite == null:
		return

	if is_closed:
		match owner_team:
			1:
				lock_sprite.texture = blue_lock_texture
			2:
				lock_sprite.texture = red_lock_texture
			_:
				lock_sprite.texture = gray_lock_texture

		_stop_pending_dot_blink()
		lock_sprite.visible = true
		_apply_lock_icon_layout(LOCK_ICON_SIZE)
		return

	if owner_team == 1 or owner_team == 2:
		_stop_pending_dot_blink()
		lock_sprite.visible = false
		return

	if questions_used >= 1 and pending_dot_texture != null:
		lock_sprite.texture = pending_dot_texture
		lock_sprite.visible = true
		_apply_lock_icon_layout(PENDING_DOT_SIZE)
		_start_pending_dot_blink()
		return

	_stop_pending_dot_blink()
	lock_sprite.visible = false
