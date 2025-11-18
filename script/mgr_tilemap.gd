extends Node2D

@onready var mgr_input = $"../Input"
@onready var mgr_ui = $"../UI"
@onready var wtml: TileMapLayer = $WorldTileMapLayer
@onready var vtml_scene: PackedScene = preload("res://scene/visual_tilemap_layer_single_set.tscn")
@onready var tile_set_main = preload("res://tileset/single_set.tres")
@onready var tile_set_debug = preload("res://tileset/debug.tres")

var curr_sid: int = -1
var vtml: TileMapLayer = null
var dbg_vtml: TileMapLayer = null
var activated_cells: Dictionary = {}  # 修复：单层类型标注（key=wcc, value=sid）
var vcell_dic: Dictionary = {}        # 修复：单层类型标注（key=vcc_coord, value=VCell）

# 缓存常用常量（避免重复调用工具类）
var direction_mapping: Dictionary = {}
var neighbor_8dir: Array = []
var neighbor_4dir: Array = []
var area_start_cc
var area_end_cc

# ======================================
# 初始化（缓存常量+创建图层）
# ======================================
func _ready() -> void:
	# 缓存工具类常量，减少重复调用
	direction_mapping = TilemapUtils.get_direction_mapping()
	neighbor_8dir = TilemapUtils.NEIGHBOR_8DIR
	neighbor_4dir = TilemapUtils.NEIGHBOR_4DIR
	
	# 连接信号
	mgr_input.connect("sgl_click", on_click)
	mgr_input.connect("sgl_drag", on_mouse_drag)
	mgr_ui.connect("sgl_ui_card_selected", on_ui_card_selected)
	
	# 创建可视化图层
	create_visual_tilmap_layer()
	
	# 读取ac_dic
	#ac_dic = NFucn.load_dic_vec(ac_dic_file_path)
	
# ======================================
# 通用函数（提取重复逻辑，减少冗余）
# ======================================
# 创建可视化TileMap图层
func create_visual_tilmap_layer() -> void:	
	# 主可视化图层
	if vtml == null:
		vtml = vtml_scene.instantiate()
		vtml.position.x = 8
		vtml.tile_set = tile_set_main
		wtml.add_child(vtml)
	
	# 调试图层
	if dbg_vtml == null:
		dbg_vtml = vtml_scene.instantiate()
		dbg_vtml.position.x = 8
		dbg_vtml.tile_set = tile_set_debug
		wtml.add_child(dbg_vtml)

# 获取WCC对应的所有VC坐标（直接调用工具类，避免重复计算）
func _get_wcc_vccs(wcc: Vector2i) -> Array:
	return TilemapUtils.get_wcc_vcc_list(wcc)

# 更新单个WCC的所有VC显示（复用渲染逻辑）
func _update_wcc_vcells(wcc: Vector2i) -> void:
	for vcc_coord in _get_wcc_vccs(wcc):
		var vcell = vcell_dic.get(vcc_coord)
		if vcell:
			vtml.set_cell(vcell.coord, vcell.source_id, vcell.atlas_coord, vcell.alter)
		else:
			vtml.erase_cell(vcc_coord)
			dbg_vtml.erase_cell(vcc_coord)

# 刷新邻居WCC的VC（8向，含斜向）
func _refresh_neighbor_wccs(target_wcc: Vector2i) -> void:
	for dir_offset in neighbor_8dir:
		var adj_wcc = target_wcc + dir_offset
		if adj_wcc not in activated_cells:
			continue
		
		# 重新计算邻居的VC Atlas坐标
		var adj_sid = activated_cells[adj_wcc]
		for vcc_coord in _get_wcc_vccs(adj_wcc):
			var vcell = vcell_dic.get(vcc_coord)
			if vcell:
				vcell.atlas_coord = calculate_vcc_atlas_coord(adj_wcc, vcc_coord, adj_sid)
		
		# 更新显示
		_update_wcc_vcells(adj_wcc)
		#print("✅ 刷新邻居WCC %s 完成" % adj_wcc)

# ======================================
# 信号回调（保持原逻辑）
# ======================================
func on_ui_card_selected(sid: int, _count: int) -> void:
	curr_sid = sid
	#print("选中的SID：", curr_sid)

func on_click(_wp: Vector2, control: String) -> void:
	handle_tile_data(get_local_mouse_position(), control)

func on_mouse_drag(wp: Vector2, phase: String, control: String, shift: String) -> void:
	if phase == "dragging" and shift == "just_released_shift":
		handle_tile_data(get_local_mouse_position(), control)
	
	##print(coord,"|",phase,"|",control,"|",shift)
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
				var wcc_arr = TilemapUtils.get_all_cells_in_rect(area_start_cc,area_end_cc)
				for wcc in wcc_arr:
					var wpos = wtml.map_to_local(wcc)
					match control:
						"just_released_left":
							handle_tile_data(wpos, "just_left")
						"just_released_right":
							handle_tile_data(wpos, "just_right")

# ======================================
# 核心业务逻辑（保持原功能，优化调用）
# ======================================
func handle_tile_data(wp: Vector2, control: String) -> void:
	if curr_sid == -1 || vtml == null:
		return
	if control in ["just_middle", "pressing_middle", "just_released_middle"]:
		return
	
	var world_cell_coord = wtml.local_to_map(wp)
	#print("操作的WCC坐标：", world_cell_coord)
	
	# 左键：生成/更新VC
	if control in ["just_left", "pressing_left"]:
		generate_visual_cells(world_cell_coord)
	# 右键：删除VC
	elif control in ["just_right", "pressing_right"]:
		remove_visual_cell(world_cell_coord)

# 生成可视化单元格（VC）
func generate_visual_cells(wcc: Vector2i) -> void:
	for vcc_coord in _get_wcc_vccs(wcc):
		# 计算Atlas坐标（复用核心算法）
		var atlas_coord = calculate_vcc_atlas_coord(wcc, vcc_coord, curr_sid)
		
		# 更新或创建VCell
		if vcc_coord in vcell_dic:
			var exist_vcell = vcell_dic[vcc_coord]
			exist_vcell.source_id = curr_sid
			exist_vcell.atlas_coord = atlas_coord
		else:
			vcell_dic[vcc_coord] = VCell.new(vcc_coord, curr_sid, atlas_coord)
	
	# 更新显示+标记激活+刷新邻居
	_update_wcc_vcells(wcc)
	activated_cells[wcc] = curr_sid
	_refresh_neighbor_wccs(wcc)

# 删除可视化单元格（VC）
func remove_visual_cell(wcc: Vector2i) -> void:
	#print("删除前激活的WCC：", activated_cells.keys())
	
	# 1. 删除VC实例+清除显示
	for vcc_coord in _get_wcc_vccs(wcc):
		vcell_dic.erase(vcc_coord)
		vtml.erase_cell(vcc_coord)
		dbg_vtml.erase_cell(vcc_coord)
	
	# 2. 移除激活标记
	activated_cells.erase(wcc)
	#print("删除后激活的WCC：", activated_cells.keys())
	
	# 3. 刷新邻居
	_refresh_neighbor_wccs(wcc)


# 计算VC的Atlas坐标（核心算法，保持原逻辑）
func calculate_vcc_atlas_coord(wcc: Vector2i, vcc_coord: Vector2i, current_sid: int) -> Vector2i:
	# 获取VC位置索引（0-3，O(1)查询）
	var pos_index = TilemapUtils.get_vcc_index(vcc_coord, wcc)
	if pos_index == -1:
		#print("⚠️ VC坐标 %s 索引获取失败" % vcc_coord)
		return Vector2i.ZERO
	
	# 1. 统计接触数（同SID正向邻居）
	var contact_count_dict = _get_vcc_contact_count(wcc, current_sid)
	var contact_count = contact_count_dict[pos_index] if pos_index in contact_count_dict else 0
	contact_count = clamp(contact_count, 0, 2)
	
	# 2. 识别主要接触方向
	var main_contact_dir: Vector2i = Vector2i.ZERO
	var neighbor_nvc_pos: int = -1
	for dir_offset in direction_mapping:
		var adj_wcc = wcc + dir_offset
		if adj_wcc not in activated_cells || activated_cells[adj_wcc] != current_sid:
			continue
		
		var dir_data = direction_mapping[dir_offset]
		var self_vcc_list = dir_data[0]
		var neighbor_vcc_list = dir_data[1]
		
		# 验证邻居VC是否存在
		#var adj_vcc_dic = TilemapUtils.get_wcc_vcc_dict(adj_wcc)
		var neighbor_vc_valid = true
		for nvc_pos in neighbor_vcc_list:
			var nvc_coord = TilemapUtils.get_vcc_coord(adj_wcc, nvc_pos)
			if nvc_coord not in vcell_dic:
				neighbor_vc_valid = false
				break
		if not neighbor_vc_valid:
			continue
		
		# 记录主要方向和对应邻居VC位置
		if pos_index in self_vcc_list:
			main_contact_dir = dir_offset
			var self_idx = self_vcc_list.find(pos_index)
			neighbor_nvc_pos = neighbor_vcc_list[self_idx] if self_idx != -1 else -1
			break
	
	# 3. 核心映射逻辑（保持原规则）
	var atlas_x = pos_index
	var atlas_y = contact_count
	
	#var ac_key = "%s|%s|%s|%s" % [contact_count, main_contact_dir, pos_index, neighbor_nvc_pos]
	#if ac_dic.has(ac_key): 
		#print(ac_dic[ac_key])
		#atlas_x = ac_dic[ac_key].x
	#else : print("🈚没有记录: ", ac_key)

	# 接触数2（L形，y=2）
	if contact_count == 2:
		match main_contact_dir:
			Vector2i(1, 0):  atlas_x = 1 if pos_index == 1 else 2
			Vector2i(0, 1):  atlas_x = 2 if pos_index == 2 else 3
			Vector2i(-1, 0): atlas_x = 3 if pos_index == 3 else 0
			Vector2i(0, -1): atlas_x = 0 if pos_index == 0 else 1
	# 接触数1（y=1）
	elif contact_count == 1:
		match [pos_index, neighbor_nvc_pos]:
			[0, 3], [3, 0]: atlas_x = 0
			[1, 2], [2, 1]: atlas_x = 1
			[0, 1], [1, 0]: atlas_x = 3
			[3, 2], [2, 3]: atlas_x = 2
	# 接触数0（y=0，默认索引）
	
	# 4. 情况4：闭合内角判定（保持原规则）
	var neighbor_info = check_8dir_same_sid_neighbor(wcc, current_sid)
	var is_closed_corner = false
	match pos_index:
		0:  # 上VC：左+左上 或 右+右上
			is_closed_corner = (neighbor_info.has_left && activated_cells.has(wcc + Vector2i(-1, -1)) && activated_cells[wcc + Vector2i(-1, -1)] == current_sid) || \
							  (neighbor_info.has_right && activated_cells.has(wcc + Vector2i(1, -1)) && activated_cells[wcc + Vector2i(1, -1)] == current_sid)
		1:  # 右VC：上+右上 或 下+右下
			is_closed_corner = (neighbor_info.has_up && activated_cells.has(wcc + Vector2i(1, -1)) && activated_cells[wcc + Vector2i(1, -1)] == current_sid) || \
							  (neighbor_info.has_down && activated_cells.has(wcc + Vector2i(1, 1)) && activated_cells[wcc + Vector2i(1, 1)] == current_sid)
		2:  # 下VC：左+左下 或 右+右下
			is_closed_corner = (neighbor_info.has_left && activated_cells.has(wcc + Vector2i(-1, 1)) && activated_cells[wcc + Vector2i(-1, 1)] == current_sid) || \
							  (neighbor_info.has_right && activated_cells.has(wcc + Vector2i(1, 1)) && activated_cells[wcc + Vector2i(1, 1)] == current_sid)
		3:  # 左VC：上+左上 或 下+左下
			is_closed_corner = (neighbor_info.has_up && activated_cells.has(wcc + Vector2i(-1, -1)) && activated_cells[wcc + Vector2i(-1, -1)] == current_sid) || \
							  (neighbor_info.has_down && activated_cells.has(wcc + Vector2i(-1, 1)) && activated_cells[wcc + Vector2i(-1, 1)] == current_sid)
	
	# 触发情况4（闭合内角）
	if neighbor_info.count >= 3 && neighbor_info.has_diagonal && is_closed_corner && atlas_y == 2:
		atlas_x = 0
		atlas_y = 3
		#print("📌 VC位置%d 触发闭合内角，Atlas坐标改为(0,3)" % pos_index)
	
	# 限制坐标范围（避免越界）
	atlas_x = clamp(atlas_x, 0, 3)
	atlas_y = clamp(atlas_y, 0, 4)
	
	# 调试输出（精简关键信息）
	#var tile_num = 4 * atlas_y + atlas_x
	#print("🔍 VC坐标%s（位置%d）→ Atlas(%d,%d)（数字%d）" % [vcc_coord, pos_index, atlas_x, atlas_y, tile_num])
	
	#ac_dic.get_or_add(ac_key,Vector2i(atlas_x,atlas_y))

	return Vector2i(atlas_x, atlas_y)

# 统计VC接触数（同SID正向邻居）
func _get_vcc_contact_count(wcc: Vector2i, current_sid: int) -> Dictionary:
	var contact_count: Dictionary = {0:0, 1:0, 2:0, 3:0}
	
	for dir_offset in direction_mapping:
		var adj_wcc = wcc + dir_offset
		if adj_wcc not in activated_cells || activated_cells[adj_wcc] != current_sid:
			continue
		
		var dir_data = direction_mapping[dir_offset]
		var self_vcc_list = dir_data[0]
		var neighbor_vcc_list = dir_data[1]
		
		# 验证邻居VC有效性
		#var adj_vcc_dic = TilemapUtils.get_wcc_vcc_dict(adj_wcc)
		var neighbor_vc_valid = true
		for nvc_pos in neighbor_vcc_list:
			var nvc_coord = TilemapUtils.get_vcc_coord(adj_wcc, nvc_pos)
			if nvc_coord not in vcell_dic:
				neighbor_vc_valid = false
				break
		if not neighbor_vc_valid:
			continue
		
		# 累计接触数（最多2次）
		for self_vc_pos in self_vcc_list:
			if contact_count[self_vc_pos] < 2:
				contact_count[self_vc_pos] += 1
	
	return contact_count

# 检测8向同SID邻居情况
func check_8dir_same_sid_neighbor(wcc: Vector2i, current_sid: int) -> Dictionary:
	var same_sid_count = 0
	var has_diagonal = false
	var has_up = false
	var has_right = false
	var has_down = false
	var has_left = false
	
	for dir_vec in neighbor_8dir:
		var neighbor_wcc = wcc + dir_vec
		if activated_cells.has(neighbor_wcc) && activated_cells[neighbor_wcc] == current_sid:
			same_sid_count += 1
			# 标记斜向邻居
			if dir_vec.x != 0 && dir_vec.y != 0:
				has_diagonal = true
			# 标记正向邻居
			match dir_vec:
				Vector2i(0, -1): has_up = true
				Vector2i(1, 0): has_right = true
				Vector2i(0, 1): has_down = true
				Vector2i(-1, 0): has_left = true
	
	return {
		"count": same_sid_count,
		"has_diagonal": has_diagonal,
		"has_up": has_up,
		"has_right": has_right,
		"has_down": has_down,
		"has_left": has_left
	}
