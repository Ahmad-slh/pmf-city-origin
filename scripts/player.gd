extends Node2D

@onready var anim: AnimationPlayer = $Area2D2/AnimationPlayer

var board = null

var team_id: int
var team_name: String
var team_clicks: int

var is_my_turn := false
var is_dragging := false

var player_color = "blue"

# مكان اللاعب الصحيح الحالي
var allowed_position: Vector2
var return_distance := 25.0


func _ready() -> void:
	allowed_position = global_position
	show()


	# نبحث عن Board حتى لو صار داخل Board_Background
	if board == null:
		board = get_tree().get_first_node_in_group("board")


func _process(delta: float) -> void:
	if is_dragging:
		global_position = get_global_mouse_position()


func _on_area_2d_2_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			
			
			var current_team_id =GameManagerHelper.get_team_id_from_effect(GameManagerHelper.EffectType.CHOOSE_NEXT_STARTING_TEAM)
			if GoodEffects.use_choose_next_starting_team(current_team_id):
				#good_dice_choose_next_roll.emit()
				#return
				print("Player= ", team_id)
				GameManager.current_team=team_id
				#GameManagerHelper.set_effect_display_turns(current_team_id,
						#GameManagerHelper.EffectType.CHOOSE_NEXT_STARTING_TEAM, 2)
				GameManager.update_active_players()

			else:

				if not GameManager.is_current_team(team_id):
					return

			is_dragging = true


func _unhandled_input(event):
	if is_dragging:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				is_dragging = false
				team_clicks += 1

				var moved := check_drop_sector()

				if not moved:
					return_to_allowed_position()


func check_drop_sector() -> bool:
	var space_state = get_world_2d().direct_space_state

	var query = PhysicsPointQueryParameters2D.new()
	query.position = $Area2D2.global_position
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var result = space_state.intersect_point(query)


	for item in result:
		var collider = item["collider"]


		var sector = null

		if collider.is_in_group("board_sectors"):
			sector = collider
		elif collider.is_in_group("sectors"):
			sector = collider
		elif collider.get_parent() and collider.get_parent().is_in_group("board_sectors"):
			sector = collider.get_parent()
		elif collider.get_parent() and collider.get_parent().is_in_group("sectors"):
			sector = collider.get_parent()

		if sector != null:
			

			if sector.is_highlighted:
				allowed_position = sector.global_position
				board._on_sector_selected(sector)
				return true

	return false
	
func return_to_allowed_position() -> void:
	var tween := create_tween()
	tween.tween_property(self, "global_position", allowed_position, 0.75)

func set_active_turn(active: bool) -> void:
	if active:
		if anim.has_animation("active_turn"):
			anim.play("active_turn")
		else:
			print("Animation active_turn غير موجودة داخل ", name)
	else:
		anim.stop()
		scale = Vector2.ONE
