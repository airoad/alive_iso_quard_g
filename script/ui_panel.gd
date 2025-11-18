extends Node

signal mouse_in_out(phase:bool)

func _ready() -> void:
	connect("mouse_entered", on_mouse_entered)
	connect("mouse_exited", on_mouse_exited)

func on_mouse_entered() -> void:
	mouse_in_out.emit(true)
	
func on_mouse_exited() -> void:
	mouse_in_out.emit(false)
