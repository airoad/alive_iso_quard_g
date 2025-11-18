extends Node2D


signal sgl_click(wp: Vector2, control: String)
signal sgl_drag(wp: Vector2, phase : String, control: String, shift: String)
signal sgl_drag_screen(coord: Vector2i, phase : String, control: String, shift: String)
signal sgl_wheel(control: String)

var last_mouse_pos: Vector2 = Vector2.ZERO  # 上一帧鼠标位置
var control : String = ""
var is_dragging: bool = false  # 是否正在拖动
var is_wheeling : bool = false # 是否滚轮
var shift_phase : String = "just_released_shift" # 是否按着shift
var is_pressing : bool = false # 是否按住 


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	pass

func _unhandled_input(event: InputEvent) -> void:
	mouse_shift()
	mouse_click(event)
	mouse_wheel(event)
	mouse_drag(event)
	

func mouse_shift() -> void:
	if Input.is_action_just_pressed("shift"):
		shift_phase = "just_shift"
	elif Input.is_action_pressed("shift"):
		shift_phase = "pressing_shift"
	elif Input.is_action_just_released("shift"):
		shift_phase = "just_released_shift"
	

func mouse_wheel(event) -> void:
	if Input.is_action_pressed("wheel") :
		is_wheeling = true
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			sgl_wheel.emit("up")
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			sgl_wheel.emit("down")
	if Input.is_action_just_released("wheel"):
		is_wheeling = false


func mouse_click(event) -> void:
	if event is not InputEventMouseButton: return

	if Input.is_action_just_pressed("click"):
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				control = "just_left"
			MOUSE_BUTTON_RIGHT:
				control = "just_right"
			MOUSE_BUTTON_MIDDLE:
				control = "just_middle"
		sgl_click.emit(get_global_mouse_position(), control)
		sgl_drag.emit(get_global_mouse_position(), "start_dragging", control, shift_phase)
		sgl_drag_screen.emit(event.position, "start_dragging", control, shift_phase)
	if Input.is_action_pressed("click"):
		is_pressing = true
		match event.button_index: 
			MOUSE_BUTTON_LEFT:
				control = "pressing_left"
			MOUSE_BUTTON_RIGHT:
				control = "pressing_right"
			MOUSE_BUTTON_MIDDLE:
				control = "pressing_middle"
	if Input.is_action_just_released("click"):
		is_pressing = false
		is_dragging = false
		match event.button_index: 
			MOUSE_BUTTON_LEFT:
				control = "just_released_left"
			MOUSE_BUTTON_RIGHT:
				control = "just_released_right"
			MOUSE_BUTTON_MIDDLE:
				control = "just_released_middle"
	
		sgl_click.emit(get_global_mouse_position(), control)
		sgl_drag.emit(get_global_mouse_position(), "end_dragging", control, shift_phase)
		sgl_drag_screen.emit(event.position, "end_dragging", control, shift_phase)
			
func mouse_drag(event) -> void:
	if is_pressing and event is InputEventMouseMotion:
		is_dragging = true
		sgl_drag.emit(get_global_mouse_position(), "dragging", control, shift_phase)  # 发射拖动开始信号
		sgl_drag_screen.emit(event.position, "dragging", control, shift_phase)  # 发射拖动开始信号
		#print(control, is_dragging, shift_phase)
		
