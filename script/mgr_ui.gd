extends Node2D

signal sgl_ui_card_selected(sid:int, card_count:int)

@onready var cursor_normal: Texture2D = preload("res://image/cursor_normal.png")
@onready var cursor_pan: Texture2D = preload("res://image/cursor_pan.png")
@onready var grid_container: GridContainer = $"../../CanvasLayer/Panel/ScrollContainer/GridContainer"
@onready var utml : TileMapLayer = $"../Tilemap/UITileMapLayer"
@onready var panel = $"../../CanvasLayer/Panel"
@onready var area_frame = $"../../CanvasLayer/AreaFrame"
@onready var mgr_input = $"../Input"
@onready var camera = $"../Camera/Camera2D"
@onready var card_scene: PackedScene = preload("res://scene/card.tscn")

var icon_dic : Dictionary = {}
var selected_id : int = -1
var all_card : Array[Control] = []
var selected_card: Control = null 
var area_start_cc : Vector2i = Vector2i.ZERO
var area_start_wcc : Vector2i = Vector2i.ZERO
var area_end_wcc: Vector2i = Vector2i.ZERO
var mouse_on_ui:bool = false
var last_area_wcc_arr:Array[Vector2i] = []
var is_shift_dragging:bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	change_cursor(cursor_normal)
	handle_icon_dic()
	panel.connect("mouse_in_out",on_mouse_in_out_panel)
	mgr_input.connect("sgl_drag_screen", on_drag_screen)
	mgr_input.connect("sgl_drag_screen", on_drag_screen_world)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if not is_shift_dragging:
		update_cursor_pos()

func change_cursor(texture:Texture2D) -> void:
	if texture:
		var hotspot = Vector2(texture.get_size() / 2)
		Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, hotspot)

func update_cursor_pos() -> void:
	var cc = utml.local_to_map(get_global_mouse_position())
	if mouse_on_ui:
		utml.clear()
		return
	else :
		utml.clear()
		TMLUtils.set_cell(utml,cc)

func on_mouse_on_card(phase:bool)->void:
	mouse_on_ui = phase
	
func on_mouse_in_out_panel(phase:bool)->void:
	mouse_on_ui = phase

func handle_icon_dic() -> void:
	icon_dic = NFunc.scan_directory("res://terrain_icon/", ".png")
	if icon_dic.is_empty(): return
	
	clear_chiildren(grid_container)
	all_card.clear()
	
	for path in icon_dic:
		var sid:int = int(path.get_file().get_basename())
		var icon_instance:Texture2D = icon_dic[path]
		var card = card_scene.instantiate()
		card.sid = sid
		card.icon_texture = icon_instance
		
		## 连接卡片的选中信号
		card.connect("sgl_card_selected", on_card_selected)
		card.connect("sgl_mouse_on_card", on_mouse_on_card)
		grid_container.add_child(card)
		all_card.append(card)

# 卡片被点击选中时触发
func on_card_selected(sid:int, card:Control) -> void:
	selected_id = sid
	selected_card = card
	
	# 1. 取消所有卡片的选中状态
	for c in all_card:
		c.deselect_card()
		if c != card: 
			c.hide_marker()

	sgl_ui_card_selected.emit(selected_id, all_card.size())
			
# 外部获取当前选中资源的接口
func get_selected_asset() -> int:
	return selected_id

func clear_chiildren(node : Node) -> void:
	for i in node.get_child_count():
		var c = node.get_child(0)
		node.remove_child(c)
		node.queue_free()

func on_drag_screen(_coord: Vector2i, phase : String, control: String, shift: String) -> void:
	if shift == "just_released_shift":
		area_frame.visible = false
		area_frame.size = Vector2.ZERO
		return
	
	var wcc = utml.local_to_map(get_global_mouse_position())
	match phase:
		"start_dragging":
			if not control == "just_middle": 
				area_start_cc = wcc
				area_frame.position = area_start_cc
				area_frame.size = Vector2.ZERO
		"dragging":
			if not control == "pressing_middle": 
				area_frame.visible = true
				var fsize = wcc - area_start_cc
				var fscale = Vector2.ONE
				if fsize.x > 0 : fscale.x = 1
				else :
					fscale.x = -1
					fsize.x = abs(fsize.x) 
				if fsize.y > 0 : fscale.y = 1
				else : 
					fscale.y = -1
					fsize.y = abs(fsize.y)
				area_frame.size = fsize
				area_frame.scale = fscale
		"end_dragging":
			if not control == "just_released_middle": 
				area_frame.visible = false
				area_frame.size = Vector2.ZERO

func on_drag_screen_world(_coord: Vector2i, phase : String, control: String, shift: String) -> void:
	if shift == "just_released_shift": 
		is_shift_dragging = false
		return
	var wcc = utml.local_to_map(get_global_mouse_position())
	match phase:
		"start_dragging":
			if not control == "just_middle": 
				area_start_wcc = wcc
		"dragging":
			if not control == "pressing_middle":
				area_end_wcc = wcc
				var temp_wcc_arr:Array[Vector2i] = TMLUtils.get_all_cc_in_world_rect(area_start_wcc,area_end_wcc)
				if temp_wcc_arr.size() != last_area_wcc_arr.size():
					last_area_wcc_arr = temp_wcc_arr
					utml.clear()
					var aid:int = 0
					if control in ["pressing_right","just_right"]: aid = 1
					for area_cc in last_area_wcc_arr:
						TMLUtils.set_cell(utml,area_cc,0,Vector2i.ZERO,aid)
				is_shift_dragging = true
		"end_dragging":
			if not control == "just_released_middle": 
				area_end_wcc = wcc
				utml.clear()
				is_shift_dragging = false
