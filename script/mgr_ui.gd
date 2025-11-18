extends Node2D

signal sgl_ui_card_selected(sid:int, card_count:int)

@onready var cursor_normal: Texture2D = preload("res://image/cursor_normal.png")
@onready var cursor_pan: Texture2D = preload("res://image/cursor_pan.png")
@onready var cursor : Sprite2D = $Cursor
@onready var wtml : TileMapLayer = $"../Tilemap/WorldTileMapLayer"
@onready var grid_container: GridContainer = $"../../CanvasLayer/Panel/ScrollContainer/GridContainer"
@onready var color_picker_button : ColorPickerButton = $"../../CanvasLayer/Panel/ColorPickerButton"
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
var area_start_coord : Vector2i = Vector2i.ZERO
var mouse_on_ui:bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	change_cursor(cursor_normal)
	handle_icon_dic()
	panel.connect("mouse_in_out",on_mouse_in_out_panel)
	mgr_input.connect("sgl_drag_screen", on_drag_screen)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	update_cursor_pos()
	
func change_cursor(texture:Texture2D) -> void:
	if texture:
		var hotspot = Vector2(texture.get_size() / 2)
		Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, hotspot)

func update_cursor_pos() -> void:
	var mp = get_global_mouse_position()
	var cc = wtml.local_to_map(mp)
	#mp = wtml.map_to_local(cc)
	if mouse_on_ui:
		utml.clear()
		return
	else :
		utml.clear()
		utml.set_cell(cc,0,Vector2i.ZERO,0)
		
	#cursor.position = mp

func on_mouse_on_card(phase:bool)->void:
	mouse_on_ui = phase
	
func on_mouse_in_out_panel(phase:bool)->void:
	mouse_on_ui = phase

	
func handle_icon_dic() -> void:
	icon_dic = NFucn.scan_directory("res://source_id_icon/", ".png")
	if icon_dic.size() <= 0: return
	
	clear_chiildren(grid_container)
	all_card.clear()
	
	for path in icon_dic:
		var sid:int = int(path.get_file().get_basename())
		var icon_instance:Texture2D = icon_dic[path]
		# 加载卡片场景（替换为你的卡片场景路径）
		var card = card_scene.instantiate()
		# 给卡片设置参数
		card.sid = sid
		## 设置预览图（TileSet 用第一个瓦片的纹理作为预览）
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
	print("sid:", sid)
			
# 外部获取当前选中资源的接口
func get_selected_asset() -> int:
	return selected_id

func clear_chiildren(node : Node) -> void:
	for i in node.get_child_count():
		var c = node.get_child(0)
		node.remove_child(c)
		node.queue_free()

func on_drag_screen(coord: Vector2i, phase : String, control: String, shift: String):
	if shift == "just_released_shift":
		area_frame.visible = false
		area_frame.size = Vector2.ZERO
		return
	#print(coord,"|",phase,"|",control,"|",shift)
	
	match phase:
		"start_dragging":
			if not control == "just_middle": 
				area_start_coord = coord
				area_frame.position = area_start_coord
				area_frame.size = Vector2.ZERO
				#print(coord, area_start_coord)
		"dragging":
			if not control == "pressing_middle": 
				area_frame.visible = true
				var fsize = coord - area_start_coord
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
	
