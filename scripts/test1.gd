extends Button
signal  Hello_Signal


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#Hello_Signal.emit();
	emit_signal("Hello_Signal")
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_pressed() -> void:
	pass

func _on_hello_signal() -> void:
	pass
