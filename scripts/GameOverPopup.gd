extends CanvasLayer

signal return_to_menu_requested
signal tie_breaker_requested

const BLUE_TEAM_TEXTURE := preload("res://assets/images/تصميم حنظلة/باتل الفريق الأزرق.png")
const RED_TEAM_TEXTURE := preload("res://assets/images/تصميم حنظلة/باتل الفريق الاحمر.png")

const BLUE_COLOR := Color("#1565C0")
const RED_COLOR := Color("#C62828")
const DRAW_COLOR := Color("#546E7A")

@onready var winner_banner: Panel = $Overlay/ResultPanel/WinnerBanner
@onready var winner_label: Label = $Overlay/ResultPanel/WinnerBanner/WinnerLabel
@onready var sectors_label: Label = $Overlay/ResultPanel/SectorsLabel
@onready var scores_label: Label = $Overlay/ResultPanel/ScoresLabel
@onready var winner_character: TextureRect = $Overlay/ResultPanel/WinnerCharacter
@onready var return_button: Button = $Overlay/ResultPanel/ReturnButton

var current_winner := 0


func _ready() -> void:
	return_button.pressed.connect(_on_return_button_pressed)
	hide()


func show_result(result: Dictionary) -> void:
	var winner: int = int(result.get("winner", 0))
	var sectors: Dictionary = result.get("sectors", {1: 0, 2: 0})
	var winner_color := _winner_color(winner)
	current_winner = winner

	winner_label.text = _winner_message(winner)
	winner_label.add_theme_color_override("font_color", Color.WHITE)

	var banner_style := winner_banner.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	banner_style.bg_color = winner_color
	banner_style.border_color = winner_color.lightened(0.22)
	winner_banner.add_theme_stylebox_override("panel", banner_style)

	sectors_label.text = "القطاعات:   الأزرق %d   |   الأحمر %d" % [
		int(sectors.get(1, 0)), int(sectors.get(2, 0))
	]
	scores_label.visible = winner == 0
	scores_label.text = "سيحسم سؤال التعادل الفريق الفائز"
	return_button.text = "بدء السؤال الحاسم" if winner == 0 else "العودة إلى القائمة الرئيسية"

	if winner == 1:
		winner_character.texture = BLUE_TEAM_TEXTURE
		winner_character.show()
	elif winner == 2:
		winner_character.texture = RED_TEAM_TEXTURE
		winner_character.show()
	else:
		winner_character.hide()

	show()
	GameManagerHelper.push_input_block(self, "game_over_popup")
	return_button.call_deferred("grab_focus")


func _winner_message(winner: int) -> String:
	if winner == 1:
		return "الفريق الأزرق قد فاز!"
	if winner == 2:
		return "الفريق الأحمر قد فاز!"
	return "انتهت المباراة بالتعادل!"


func _winner_color(winner: int) -> Color:
	if winner == 1:
		return BLUE_COLOR
	if winner == 2:
		return RED_COLOR
	return DRAW_COLOR


func _on_return_button_pressed() -> void:
	GameManagerHelper.pop_input_block(self)
	if current_winner == 0:
		hide()
		tie_breaker_requested.emit()
	else:
		return_to_menu_requested.emit()
