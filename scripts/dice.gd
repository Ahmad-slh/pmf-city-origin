extends Node2D
@onready var dice_sprite: AnimatedSprite2D = $AnimatedSprite2D

# إعدادات حركة تدحرج النرد
const ROLL_SWAPS := 10          # عدد تبديلات الوجه أثناء التدحرج
const SWAP_TIME_START := 0.05   # مدة أول تبديل (سريع)
const SWAP_TIME_END := 0.18     # مدة آخر تبديل (بطيء)
const WOBBLE_DEGREES := 18.0    # أقصى ميلان أثناء التدحرج
const LAND_TIME := 0.15         # مدة ارتداد الاستقرار
const LAND_SQUASH := 1.15       # مقدار التكبير عند الاستقرار

var is_rolling := false
var board = null
signal dice_rolled(value)

var roll_tween: Tween = null
var base_scale := Vector2.ONE

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	randomize()
	base_scale = dice_sprite.scale
	dice_sprite.stop()
	dice_sprite.frame = 0

func _show_face(face: int) -> void:
	dice_sprite.frame = face - 1

func roll_dice(p_dice: int = -1) -> void:

	if is_rolling:
		return

	# ------------------------------------------------------
	# لا يرمى النرد ما دام أي تفاعل معلّقا على الشاشة:
	# بطاقة سؤال أو حدث، أو أي نافذة تنتظر ضغطة اللاعب.
	#
	# الفحص هنا وليس في _on_input_event فقط، حتى يشمل أي
	# استدعاء آخر للدالة مستقبلا وليس ضغطة الفأرة وحدها
	# ------------------------------------------------------
	if board != null:

		# استثناء مقصود: قرعة البداية تحتاج النرد قابلا للضغط
		# داخل نافذة "دور هذا الفريق ليرمي" وحدها
		if board.roll_off_active:
			if not board.roll_off_accepting_click:
				print("لا يمكن رمي النرد الآن أثناء قرعة البداية")
				return

		elif board.is_dice_locked():
			print("لا يمكن رمي النرد أثناء وجود تفاعل معلّق")
			return

	is_rolling = true

	# إيقاف أي حركة سابقة حتى لا تتداخل الحركات عند التدحرج المتكرر
	if roll_tween != null and roll_tween.is_valid():
		roll_tween.kill()
	dice_sprite.stop()
	dice_sprite.rotation_degrees = 0.0
	dice_sprite.scale = base_scale

	var result := randi_range(1, 6)

	if p_dice != -1:
		result = p_dice

	roll_tween = create_tween()

	# مرحلة التدحرج: تبديل وجوه عشوائية مع ميلان يتناقص تدريجياً
	var last_face := dice_sprite.frame + 1
	for i in ROLL_SWAPS:
		var t := float(i) / float(ROLL_SWAPS - 1)
		var step_time: float = lerp(SWAP_TIME_START, SWAP_TIME_END, t * t)

		var face := randi_range(1, 6)
		if face == last_face:
			face = (face % 6) + 1
		last_face = face

		var amplitude := WOBBLE_DEGREES * (1.0 - t)
		var direction := 1.0 if i % 2 == 0 else -1.0

		roll_tween.tween_callback(_show_face.bind(face))
		roll_tween.tween_property(dice_sprite, "rotation_degrees", amplitude * direction, step_time)

	# مرحلة الاستقرار: إظهار النتيجة الحقيقية مع تسوية الدوران وارتداد بسيط
	roll_tween.tween_callback(_show_face.bind(result))
	roll_tween.tween_property(dice_sprite, "rotation_degrees", 0.0, LAND_TIME * 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	roll_tween.parallel().tween_property(dice_sprite, "scale", base_scale * LAND_SQUASH, LAND_TIME * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	roll_tween.chain().tween_property(dice_sprite, "scale", base_scale, LAND_TIME * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	roll_tween.tween_callback(func() -> void:
		is_rolling = false
		dice_rolled.emit(result)
	)



func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var team_id = GameManager.current_team

			roll_dice(-1)
