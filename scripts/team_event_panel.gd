extends Control

@onready var panel: Panel = $Panel
@onready var team_label: Label = $Panel/TeamLabel
@onready var event_title_label: Label = $Panel/EventTitleLabel
@onready var event_body_label: Label = $Panel/EventBodyLabel


func _ready() -> void:
	visible = true
	clear_event()


func setup_team(team_id: int) -> void:
	if team_id == GameManager.Team.BLUE:
		team_label.text = "الفريق الأزرق"
	else:
		team_label.text = "الفريق الأحمر"


func show_event(event_title: String, event_body: String) -> void:
	event_title_label.text = event_title
	event_body_label.text = event_body


func clear_event() -> void:
	event_title_label.text = "لا يوجد حدث حاليًا"
	event_body_label.text = "ستظهر هنا أحداث الشوارع الخاصة بهذا الفريق."
