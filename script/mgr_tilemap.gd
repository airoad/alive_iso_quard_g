extends Node2D

@onready var mgr_input = $"../Input"
@onready var mgr_ui = $"../UI"
@onready var wtml: TileMapLayer = $WorldTileMapLayer
@onready var vtml: TileMapLayer = $WorldTileMapLayer/VisualTileMapLayer
@onready var tile_set_visual = preload("res://tileset/tile_set_visual.tres")
@onready var tile_set_debug = preload("res://tileset/debug.tres")

var curr_sid: int = -1
var area_start_cc
var area_end_cc
const SID_CAPACITY = 100

func _ready() -> void:
	mgr_input.connect("sgl_click", on_click)
	mgr_input.connect("sgl_drag", on_mouse_drag)
	mgr_ui.connect("sgl_ui_card_selected", on_ui_card_selected)


func on_ui_card_selected(sid: int, _count: int) -> void:
	curr_sid = sid

func on_click(_wp: Vector2, control: String) -> void:
	handle_tile_data([{wtml.local_to_map(get_local_mouse_position()):true}], control)
	
func on_mouse_drag(wp: Vector2, phase: String, control: String, shift: String) -> void:
	if phase == "dragging" and shift == "just_released_shift":
		handle_tile_data([{wtml.local_to_map(get_local_mouse_position()):true}], control)
	if shift == "just_released_shift": return
	match phase:
		"start_dragging":
			if not control == "just_middle": 
				area_start_cc = wtml.local_to_map(wp)
		"dragging":
			if not control == "pressing_middle": 
				area_end_cc = wtml.local_to_map(wp)
		"end_dragging":
			if not control == "just_released_middle": 
				area_end_cc = wtml.local_to_map(wp)
				var wccs:Array[Dictionary] = TMLUtils.get_all_cc_in_world_rect(area_start_cc,area_end_cc)
				handle_tile_data(wccs, control)

func handle_tile_data(wccs: Array[Dictionary], control: String) -> void:
	if wccs.is_empty(): return
	if curr_sid == -1 || vtml == null:
		return
	if control in ["just_middle", "pressing_middle", "just_released_middle"]:
		return
	
	for wcc_border_state_dic in wccs: 
		# 左键：生成VC
		if control in ["pressing_left", "just_released_left"]:
			generate_visual_cells(wcc_border_state_dic)
		# 右键：删除VC
		elif control in ["pressing_right", "just_released_right"]:
			remove_visual_cell(wcc_border_state_dic)

# 生成VC
func generate_visual_cells(wcc_border_state_dic: Dictionary, sid:int = curr_sid) -> void:
	var wcc = wcc_border_state_dic.keys()[0]
	if wtml.get_used_cells().has(wcc):
		var source_id = wtml.get_cell_source_id(wcc)
		if source_id != sid:
			wtml.erase_cell(wcc)
			update_visual_cell(wcc_border_state_dic)
	TMLUtils.set_cell(wtml,wcc,sid)
	update_visual_cell(wcc_border_state_dic)

# 删除VC
func remove_visual_cell(wcc_border_state_dic: Dictionary, _sid:int = curr_sid) -> void:
	var wcc = wcc_border_state_dic.keys()[0]
	wtml.erase_cell(wcc)
	update_visual_cell(wcc_border_state_dic)

func update_visual_cell(wcc_border_state_dic: Dictionary, sid:int = curr_sid) -> void:
	var wcc = wcc_border_state_dic.keys()[0]
	var is_add = wtml.get_used_cells().has(wcc)
	var vcc_arr = TMLUtils.get_vcc_list_in_wcc(wcc)
	if is_add:
		for vcc in vcc_arr:
			TMLUtils.set_cell(vtml,vcc,sid)
		refresh_wc_nc(wcc_border_state_dic)
	else:
		for vcc in vcc_arr:
			vtml.erase_cell(vcc)
		refresh_wc_nc(wcc_border_state_dic)

func refresh_wc_nc(wcc_border_state_dic:Dictionary,sid:int = curr_sid)->void:
	var wcc = wcc_border_state_dic.keys()[0]
	var is_add = wtml.get_used_cells().has(wcc)
	if is_add: # 如果增加 先将增加的vcc刷新
		var border_state = wcc_border_state_dic.values()[0]
		var vcc_arr = TMLUtils.get_vcc_list_in_wcc(wcc)
		for vcc in vcc_arr:
			sid = vtml.get_cell_source_id(vcc)
			var ac = vtml.get_cell_atlas_coords(vcc)
			var ac_y = TMLUtils.get_vcc_atlas_y(vcc, wcc, sid, border_state,vtml)
			if ac_y != ac.y: # 边界处 ac.y 会产生变化，只在这种情况下更新
				ac.y = ac_y
				TMLUtils.set_cell(vtml,vcc,sid,ac)
	#更新邻居
	var need_refresh_ncc_dic = TMLUtils.get_used_neighbors_by_sid(wcc,sid,wtml,is_add)
	for ncc in need_refresh_ncc_dic:
		var nvccs = TMLUtils.get_vcc_list_in_wcc(ncc)
		for nvcc in nvccs:
			var nsid = vtml.get_cell_source_id(nvcc)
			var nac = vtml.get_cell_atlas_coords(nvcc)
			#ac.x = randi() % 2
			var nac_y = TMLUtils.get_vcc_atlas_y(nvcc, ncc, nsid, true, vtml) # 既然是删除，默认邻居是处在边界处
			if nac_y != nac.y:
				nac.y = nac_y
				TMLUtils.set_cell(vtml,nvcc,nsid,nac)
