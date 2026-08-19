extends Control

@onready var startup_sound: AudioStreamPlayer = $StartupSound

@onready var cloud_big: TextureRect = $Clouds/CloudBig
@onready var cloud_small: TextureRect = $Clouds/CloudSmall

@onready var gate: TextureRect = $Gate
@onready var gate_open: TextureRect = $GateOpen
@onready var airplane: TextureRect = $Airplane

@onready var door_button: TextureButton = $DoorButton
@onready var play_button: TextureButton = $Signpost/PlayButton
@onready var rules_button: TextureButton = $Signpost/RulesButton
@onready var tutorial_button: TextureButton = $Signpost/TutorialButton
@onready var about_button: TextureButton = $Signpost/AboutButton

@onready var character_red: TextureRect = $CharacterRed
@onready var character_blue: TextureRect = $CharacterBlue

@onready var rules_popup: Panel = $RulesPopup
@onready var tutorial_popup: Panel = $TutorialPopup
@onready var about_popup: Panel = $AboutPopup

@onready var rules_close_button: Button = $RulesPopup/CloseButton
@onready var tutorial_close_button: Button = $TutorialPopup/CloseButton

const GAME_SCENE_PATH := "res://scenes/board_background.tscn"

# مواضع وصول الشخصيات داخل فتحة البوابة (محسوبة بحيث تقف عند منتصف البوابة)
const RED_GATE_TARGET := Vector2(618.8, 589.2)
const BLUE_GATE_TARGET := Vector2(648.6, 583.6)

const GATE_FADE_TIME := 0.3
const WALK_TIME := 0.6
const BLUE_WALK_DELAY := 0.12
const WALK_SCALE := Vector2(0.65, 0.65)
const HOLD_TIME := 0.4

# سرعة انجراف الغيوم بالبكسل في الثانية
var _cloud_speeds := {}
var _active_tweens: Array[Tween] = []
var _is_transitioning := false


func _ready() -> void:
	startup_sound.play()

	_cloud_speeds[cloud_big] = 14.0
	_cloud_speeds[cloud_small] = 9.0
	_start_airplane_animation()

	door_button.pressed.connect(_on_play_pressed)
	play_button.pressed.connect(_on_play_pressed)
	rules_button.pressed.connect(func(): _show_popup(rules_popup))
	tutorial_button.pressed.connect(func(): _show_popup(tutorial_popup))
	about_button.mouse_entered.connect(func(): _show_popup(about_popup))
	about_button.mouse_exited.connect(func(): about_popup.hide())
	rules_close_button.pressed.connect(func(): rules_popup.hide())
	tutorial_close_button.pressed.connect(func(): tutorial_popup.hide())


func _process(delta: float) -> void:
	# انجراف الغيوم ببطء نحو اليمين مع إعادة إدخالها من اليسار بشكل متصل
	for cloud in _cloud_speeds:
		cloud.position.x += _cloud_speeds[cloud] * delta
		if cloud.position.x > size.x:
			cloud.position.x = -cloud.size.x


# إظهار نافذة واحدة فقط وإخفاء البقية حتى لا تتراكم فوق بعضها
func _show_popup(popup: Control) -> void:
	rules_popup.hide()
	tutorial_popup.hide()
	about_popup.hide()
	popup.show()


func _start_airplane_animation() -> void:
	# حركة الطائرة: طفو عمودي + انجراف جانبي + اهتزاز دوران خفيف، بفترات مختلفة حتى لا تتكرر بنفس النمط
	airplane.pivot_offset = airplane.size / 2.0
	var base_pos := airplane.position

	var bob := create_tween().set_loops()
	bob.tween_property(airplane, "position:y", base_pos.y + 14.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(airplane, "position:y", base_pos.y, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var drift := create_tween().set_loops()
	drift.tween_property(airplane, "position:x", base_pos.x - 30.0, 2.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	drift.tween_property(airplane, "position:x", base_pos.x, 2.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var wobble := create_tween().set_loops()
	wobble.tween_property(airplane, "rotation_degrees", 3.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wobble.tween_property(airplane, "rotation_degrees", -3.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_play_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true

	_kill_active_tweens()

	# فتح البوابة: تلاشي البوابة المغلقة وظهور البوابة المفتوحة مكانها
	gate_open.show()
	var open_tween := create_tween().set_parallel()
	open_tween.tween_property(gate, "modulate:a", 0.0, GATE_FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	open_tween.tween_property(gate_open, "modulate:a", 1.0, GATE_FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_active_tweens.append(open_tween)

	# دخول الشخصيتين عبر البوابة: مشي نحو المنتصف مع تصغير وتلاشٍ، والأحمر يبدأ أولاً
	_walk_character_into_gate(character_red, RED_GATE_TARGET, 0.0)
	_walk_character_into_gate(character_blue, BLUE_GATE_TARGET, BLUE_WALK_DELAY)

	# الانتظار حتى انتهاء دخول الشخصيتين ثم توقف قصير على البوابة المفتوحة
	var hold_tween := create_tween()
	hold_tween.tween_interval(BLUE_WALK_DELAY + WALK_TIME + HOLD_TIME)
	_active_tweens.append(hold_tween)
	await hold_tween.finished

	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _walk_character_into_gate(character: TextureRect, target_pos: Vector2, delay: float) -> void:
	var walk := create_tween().set_parallel()
	walk.tween_property(character, "position", target_pos, WALK_TIME).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	walk.tween_property(character, "scale", WALK_SCALE, WALK_TIME).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# التلاشي ينتهي بعد وصول الشخصية إلى البوابة بقليل حتى تبدو وكأنها دخلت منها
	walk.tween_property(character, "modulate:a", 0.0, WALK_TIME - 0.15).set_delay(delay + 0.25)
	_active_tweens.append(walk)


# إيقاف أي حركة سابقة على البوابة والشخصيات لتجنب التعارض عند الضغط أكثر من مرة
func _kill_active_tweens() -> void:
	for tween in _active_tweens:
		if is_instance_valid(tween) and tween.is_valid():
			tween.kill()
	_active_tweens.clear()
