extends Node2D

@onready var mgr_input = $"../Input"
@onready var mgr_ui = $"../UI"
@onready var wtml: TileMapLayer = $WorldTileMapLayer

var terrain_set:int = 0
var terrain_id:int = -1
var area_start_cc:Vector2i = -Vector2i.ONE
var area_end_cc:Vector2i = -Vector2i.ONE

func _ready() -> void:
	mgr_input.connect("sgl_click", on_click)
	mgr_input.connect("sgl_drag", on_mouse_drag)
	mgr_ui.connect("sgl_ui_card_selected", on_ui_card_selected)

func on_ui_card_selected(tid: int, _count: int) -> void:
	terrain_id = tid

func on_click(_wp: Vector2, control: String) -> void:
	var wcc = wtml.local_to_map(get_local_mouse_position())
	handle_tile_data([wcc], control)
	
func on_mouse_drag(wp: Vector2, phase: String, control: String, shift: String) -> void:
	if phase == "dragging" and shift == "just_released_shift":
		var wcc = wtml.local_to_map(get_local_mouse_position())
		handle_tile_data([wcc], control)
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
				var wccs:Array[Vector2i] = TMLUtils.get_all_cc_in_world_rect(area_start_cc,area_end_cc)
				handle_tile_data(wccs, control)

func handle_tile_data(wccs: Array[Vector2i], control: String) -> void:
	if wccs.is_empty(): return
	if terrain_id == -1 || wtml == null: return
	if control in ["just_middle", "pressing_middle", "just_released_middle"]: return
	
	# 左键：生成VC
	if control in ["pressing_left", "just_released_left"]:
		update_visual_cell(wccs,true)
	# 右键：删除VC
	elif control in ["pressing_right", "just_released_right"]:
		update_visual_cell(wccs,false)

func update_visual_cell(wccs: Array[Vector2i], is_add:bool = true, tset:int = terrain_set, tid:int = terrain_id) -> void:
	if is_add:
		wtml.set_cells_terrain_connect(wccs,tset,tid,true)
	else :
		var cc_need_refresh:Dictionary[Vector2i,bool] = {}
		for wcc in wccs:
			var ncc_arr = TMLUtils.get_neighbors(wcc)
			for ncc in ncc_arr:
				if wtml.get_cell_source_id(ncc) != -1: # ncc exist
					cc_need_refresh[ncc] = true
		for wcc in wccs: # 擦除wcc 从tml 和 need refresh 中
			if cc_need_refresh.has(wcc):cc_need_refresh.erase(wcc)
			wtml.erase_cell(wcc)
		for wcc in cc_need_refresh: # 擦除 need refresh 从tml中
			wtml.erase_cell(wcc)
		wtml.set_cells_terrain_connect(cc_need_refresh.keys(),tset,tid,true) # 重建 need refresh 
