extends Node2D

@onready var mgr_input =  $"../Input"
@onready var camera : Camera2D = $Camera2D

var zoom = 1
var zoom_range : Vector2i = Vector2i(2, 8)
var fst_mouse_position : Vector2 = Vector2(0,0)
var scd_mouse_position : Vector2 = Vector2(0,0)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	sgl_connect()

func sgl_connect() -> void:
	# 连接输入管理器的信号
	if mgr_input:
		mgr_input.connect("sgl_drag", on_dragging)
		mgr_input.connect("sgl_wheel", on_wheel)
	else:
		printerr("找不到 MgrInput 节点，请检查路径！")


func on_wheel(control: String) -> void:
	if control == "down":
		zoom -= 1
		if zoom < zoom_range.x: zoom = zoom_range.x
	else :
		zoom += 1
		if zoom > zoom_range.y: zoom = zoom_range.y
		
	var befor = camera.to_local(get_global_mouse_position())
	camera.zoom = Vector2.ONE * zoom
	var after = camera.to_local(get_global_mouse_position())
	camera.position -= after - befor
	

# 拖动中：更新摄像机位置
func on_dragging(_wp: Vector2, phase : String, control : String, _shift: String) -> void:
	match [control,phase]:
		["just_middle","start_dragging"]:
			fst_mouse_position = get_global_mouse_position()
		["pressing_middle","dragging"]:
			scd_mouse_position = get_global_mouse_position()
			var dist = scd_mouse_position - fst_mouse_position
			camera.position -= Vector2(int(dist.x),int(dist.y)) # pixel snap
		["just_released_middle","end_dragging"]: 
			fst_mouse_position = scd_mouse_position
