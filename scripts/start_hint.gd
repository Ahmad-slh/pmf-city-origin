extends Node2D

# ======================================================
#   مؤشر "ابدأ من هنا"
# ------------------------------------------------------
# سهم بسيط على يسار قطاع البداية يشير إليه، بلا حلقة
# ولا توهج ولا ظل. يظهر بعد حسم قرعة البداية ويختفي بعد
# أول حركة حقيقية للفريق.
#
# يعيش داخل CanvasLayer خاص فوق لوحات الواجهة، لأن أي
# CanvasLayer يرسم فوق عناصر اللوحة مهما كان z_index،
# فيتبع هنا موضع القطاع ومقياسه يدويا في كل إطار
# ======================================================

const ARROW_COLOR := Color(0.88, 0.54, 0.12)

const GAP := 10.0
const HEAD_LEN := 22.0
const HEAD_HALF := 16.0
const TAIL_LEN := 26.0
const TAIL_HALF := 6.0
const BOUNCE := 5.0

# مقاس خلية القطاع، يضبطه المستدعي من CollisionShape2D
var cell_size: Vector2 = Vector2(262.0, 233.0)

# العقدة التي يلاحقها المؤشر (CollisionShape2D للقطاع)
var follow_target: Node2D = null

var _elapsed: float = 0.0
var _dismissing: bool = false
var _fitted: bool = false

# ‎+1 على يسار القطاع يشير يمينا، ‎-1 على يمينه يشير يسارا
var _dir: float = 1.0


func _process(delta: float) -> void:
	_elapsed += delta
	_sync_to_target()
	queue_redraw()


# المؤشر داخل CanvasLayer مستقل، فيجب نقل موضع القطاع ومقياسه إليه
func _sync_to_target() -> void:
	if not is_instance_valid(follow_target) or not follow_target.is_inside_tree():
		return

	var xf := follow_target.get_global_transform_with_canvas()
	position = xf.origin
	scale = xf.get_scale()

	if not _fitted:
		_fitted = true
		_fit_on_screen()


# اليسار هو الأصل، وننتقل لليمين فقط إن خرج السهم عن الشاشة
func _fit_on_screen() -> void:
	if not is_inside_tree():
		return

	var xf := get_global_transform_with_canvas()
	var scale_x: float = maxf(absf(xf.get_scale().x), 0.001)
	var reach: float = (cell_size.x * 0.5 + GAP + BOUNCE + HEAD_LEN + TAIL_LEN) * scale_x

	_dir = -1.0 if xf.origin.x - reach < 8.0 else 1.0

	queue_redraw()


# اختفاء ناعم ثم حذف، حتى لا يختفي المؤشر فجأة
func dismiss() -> void:
	if _dismissing:
		return
	_dismissing = true
	set_process(false)

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)


func _draw() -> void:
	# قفزة أفقية خفيفة نحو القطاع
	var bounce: float = BOUNCE * (0.5 + 0.5 * sin(_elapsed * 3.2))

	# رأس السهم أقرب نقطة إلى القطاع
	var tip_x: float = -_dir * (cell_size.x * 0.5 + GAP + bounce)
	# الجسم يمتد بعيدا عن القطاع، لا نحوه
	var back: float = tip_x - _dir * HEAD_LEN
	var tail: float = tip_x - _dir * (HEAD_LEN + TAIL_LEN)

	draw_colored_polygon(
		PackedVector2Array([
			Vector2(tip_x, 0.0),
			Vector2(back, -HEAD_HALF),
			Vector2(back, -TAIL_HALF),
			Vector2(tail, -TAIL_HALF),
			Vector2(tail, TAIL_HALF),
			Vector2(back, TAIL_HALF),
			Vector2(back, HEAD_HALF),
		]),
		ARROW_COLOR
	)
