extends Area2D


enum StreetState {
	NORMAL,
	BROKEN,
	CLOSED
}

@export var sector_a: Vector2i
@export var sector_b: Vector2i

var state: StreetState = StreetState.NORMAL
var pass_count: int = 0

#
#func _ready() -> void:
	#pass


#func _process(_delta: float) -> void:
	#pass


func register_pass() -> void:
	if state == StreetState.CLOSED:
		return

	pass_count += 1

	if pass_count == 1:
		break_street()

	elif pass_count >= 2:
		close_street()


func break_street() -> void:
	state = StreetState.BROKEN
	#print(name, " is now BROKEN")


func close_street() -> void:
	state = StreetState.CLOSED
	#print(name, " is now CLOSED")


func is_available() -> bool:
	return state != StreetState.CLOSED


func is_closed() -> bool:
	return state == StreetState.CLOSED


func is_broken() -> bool:
	return state == StreetState.BROKEN
