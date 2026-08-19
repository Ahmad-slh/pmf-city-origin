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
@export var red_lock_texture: Texture2D
@export var blue_lock_texture: Texture2D
@export var gray_lock_texture: Texture2D
@export var neutral_lock_texture: Texture2D

# حجم وموقع أيقونة القفل — موحّدة لكل القطاعات
# صور الأقفال بأبعاد مختلفة، لذلك يُحسب المقياس من حجم الصورة
# بدل استخدام قيمة ثابتة، حتى تظهر جميعها بنفس الحجم.
const LOCK_ICON_SIZE := 40.0     # أقصى بُعد للأيقونة بالبكسل
const LOCK_ICON_MARGIN := 12.0   # المسافة من حافة القطاع

enum CellType {
	SECTOR,
	STREET
}

signal sector_selected(sector)

var is_highlighted := false

# خاص بالقطاع
@export var questions_used: int = 0
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
func _apply_lock_icon_layout() -> void:
	if lock_sprite == null or lock_sprite.texture == null:
		return

	# المقياس محسوب من أبعاد الصورة مع الحفاظ على نسبة العرض إلى الارتفاع
	var tex_size: Vector2 = lock_sprite.texture.get_size()
	var largest_side: float = max(tex_size.x, tex_size.y)
	if largest_side <= 0.0:
		return
	var icon_scale: float = LOCK_ICON_SIZE / largest_side
	lock_sprite.scale = Vector2(icon_scale, icon_scale)

	# الموقع محسوب من مستطيل صورة القطاع نفسه، لأن إزاحة الصورة
	# تختلف بين قطاع وآخر — هذا ما كان يجعل الأيقونة غير منتظمة.
	if sprite == null or sprite.texture == null:
		return
	var art_half: Vector2 = (sprite.texture.get_size() * sprite.scale) * 0.5
	var icon_half: Vector2 = (tex_size * icon_scale) * 0.5

	lock_sprite.position = Vector2(
		sprite.position.x + art_half.x - LOCK_ICON_MARGIN - icon_half.x,
		sprite.position.y - art_half.y + LOCK_ICON_MARGIN + icon_half.y
	)


func close_cell(team_id: int = 0) -> void:
	is_closed = true
	is_broken = false

	lock_sprite.visible = true
	lock_sprite.z_index = 100
	update_sector_owner_image()
	if is_locked == 1:
		pass
	else:
		owner_team = team_id
		#update_sector_owner_image()
		#sprite.modulate = Color(1, 1, 1, 1)
			
	match team_id:
		1:
			lock_sprite.texture = blue_lock_texture
			#update_sector_owner_image()

		2:
			lock_sprite.texture = red_lock_texture
			#update_sector_owner_image()

		_:
			if cell_type == CellType.STREET:
				return
			lock_sprite.texture = gray_lock_texture
			#sprite.modulate = Color(0.35, 0.35, 0.35, 1.0)

	_apply_lock_icon_layout()


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

# تغيير صورة الشارع مع الحفاظ على نفس المساحة التي كانت تشغلها الصورة السابقة.
# صور الشوارع الجديدة أكبر بكثير من الصورة الأصلية، لذلك يُعاد حساب المقياس
# من حجم الصورة الجديدة بدل ترك مقياس ثابت — وإلا تمدد البلاط فوق القطاعات المجاورة.
func _apply_street_texture(tex: Texture2D) -> void:
	if sprite == null or tex == null or sprite.texture == null:
		return
	var target: Vector2 = sprite.texture.get_size() * sprite.scale
	var tex_size: Vector2 = tex.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	
	# العرض والارتفاع الظاهران للصورة القديمة
	var old_width: float = sprite.texture.get_width() * abs(sprite.scale.x)
	var old_height: float = sprite.texture.get_height() * abs(sprite.scale.y)

	# عرض وارتفاع الصورة الجديدة الأصليان
	var new_width: float = tex.get_width()
	var new_height: float = tex.get_height()
	
		# إعطاء الصورة الجديدة نفس عرض وارتفاع الصورة القديمة
		
	if visits_count==1:
		sprite.scale.x = (old_width / new_width)*0.75
		sprite.scale.y = (old_height / new_height)*0.55
	else:
		sprite.scale.x = (old_width / new_width)
		sprite.scale.y = (old_height / new_height)

	
	sprite.texture = tex

	#if new_width <= 0.0 or new_height <= 0.0:
		#return
	#sprite.texture = tex
	#sprite.scale = (target / tex_size) 
	#sprite.modulate = Color(1, 1, 1, 1)

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

	if lock_sprite:
		lock_sprite.visible = false
		lock_sprite.texture = null

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
