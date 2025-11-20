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
	handle_tile_data([wtml.local_to_map(get_local_mouse_position())], control)
	
func on_mouse_drag(wp: Vector2, phase: String, control: String, shift: String) -> void:
	if phase == "dragging" and shift == "just_released_shift":
		handle_tile_data([wtml.local_to_map(get_local_mouse_position())], control)
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
				var wccs:Array[Vector2i] = TilemapUtils.get_all_cc_in_rect(area_start_cc,area_end_cc)
				handle_tile_data(wccs, control)

func handle_tile_data(wccs: Array[Vector2i], control: String) -> void:
	if wccs.is_empty(): return
	if curr_sid == -1 || vtml == null:
		return
	if control in ["just_middle", "pressing_middle", "just_released_middle"]:
		return
	
	for wcc in wccs: 
		# 左键：生成VC
		if control in ["pressing_left", "just_released_left"]:
			generate_visual_cells(wcc)
		# 右键：删除VC
		elif control in ["pressing_right", "just_released_right"]:
			remove_visual_cell(wcc)

# 生成VC
func generate_visual_cells(wcc: Vector2i, sid:int = curr_sid) -> void:
	if wtml.get_used_cells().has(wcc):
		var source_id = wtml.get_cell_source_id(wcc)
		if source_id != sid:
			wtml.erase_cell(wcc)
			update_visual_cell(wcc)
	TilemapUtils.set_cell(wtml,wcc,sid)
	update_visual_cell(wcc)

# 删除VC
func remove_visual_cell(wcc: Vector2i, _sid:int = curr_sid) -> void:
	wtml.erase_cell(wcc)
	update_visual_cell(wcc)

func update_visual_cell(wcc: Vector2i, sid:int = curr_sid) -> void:
	var is_add = wtml.get_used_cells().has(wcc)
	var vcc_arr = TilemapUtils.get_wcc_vcc_list(wcc)
	if is_add:
		for vcc in vcc_arr:
			TilemapUtils.set_cell(vtml,vcc,sid)
		refresh_wc_nc(wcc)
	else:
		for vcc in vcc_arr:
			vtml.erase_cell(vcc)
		refresh_wc_nc(wcc)

func refresh_wc_nc(wcc:Vector2i,sid:int = curr_sid)->void:
	var is_add = wtml.get_used_cells().has(wcc)
	var need_refresh_cc_dic = TilemapUtils.get_used_neighbors_by_sid(wcc,sid,wtml,is_add)
	if is_add: need_refresh_cc_dic.set(wcc,8)
	for cc in need_refresh_cc_dic:
		var vccs = TilemapUtils.get_wcc_vcc_list(cc)
		for vcc in vccs:
			sid = vtml.get_cell_source_id(vcc)
			var idx = TilemapUtils.get_vcc_index(vcc,cc)
			var ac_str = "00000000" + "|" + str(idx)
			var ac = vtml.get_cell_atlas_coords(vcc)
			#ac.x = randi() % 2  
			var nvcc_idxs = TilemapUtils.get_used_neighbors_by_sid(vcc,sid,vtml).values()
			for i in nvcc_idxs:
				ac_str[i] = "1"
			ac.y = TilemapUtils.EDGE_STR_AC_DIC[ac_str]
			TilemapUtils.set_cell(vtml,vcc,sid,ac)
