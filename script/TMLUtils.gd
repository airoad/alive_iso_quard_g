class_name TMLUtils
extends RefCounted


# 8向邻居偏移（含斜向）
const NEIGHBOR_OFFSET_8DIR: Array[Vector2i] = [
	Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1),
	Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1)
]

const NEIGHBOR_OFFSET_8DIR_MAP: Dictionary[Vector2i,int] = {
	Vector2i(1, -1):0, Vector2i(1, 0):1, Vector2i(1, 1):2, Vector2i(0, 1):3,
	Vector2i(-1, 1):4, Vector2i(-1, 0):5, Vector2i(-1, -1):6, Vector2i(0, -1):7
}

# 4向邻居偏移（正向）
const NEIGHBOR_OFFSET_4DIR: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)
]

const INVALID_WCC: Vector2i = Vector2i(-1, -1)

# VC位置索引映射（0=上，1=右，2=下，3=左）
const VCC_POS_OFFSET_MAP: Dictionary = {
	Vector2i(0, 0): 0,Vector2i(0, 1): 1,Vector2i(-1, 1): 2,Vector2i(-1, 0): 3
}

# VC位置反向映射（index→coord）
const VCC_OFFSET_INDEX_MAP: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0)
]

const EDGE_STR_AC_DIC:Dictionary = {
	"00011100|0":0, "00000111|1":1, "11000001|2":2, "01110000|3":3,  #0-3
	"01111100|0":4, "11000111|1":6, "00011111|0":5, "11110001|2":7,  #4-7
	"01111100|3":4, "11000111|2":6, "00011111|1":5, "11110001|3":7,  #4-7
	"11011111|1":9, "11110111|2":10,"11111101|3":11,"01111111|0":8,  #8-11
	"11001001|2":2, "10011100|0":0, "00100111|1":1, "01110010|3":3,  #12-15
	"01111110|3":4, "11001111|2":6, "10011111|0":5, "11110011|3":7,  #16-19
	"11100111|1":6, "11111100|0":4, "11111001|2":7, "00111111|1":5,  #20-23
	"11111111|0":12,"11111111|1":12,"11111111|2":12,"11111111|3":12, #24
}

static func get_vcc_idx_dic(wcc:Vector2i)->Dictionary:
	var dic: Dictionary = {}
	for offset in VCC_POS_OFFSET_MAP:
		var vcc = wcc*2 + offset
		dic[vcc] = VCC_POS_OFFSET_MAP[offset]
	return dic

# 通过VC坐标获取位置索引（0-3，O(1)查询 -1 不存在）
static func get_idx_of_vcc(vcc: Vector2i, wcc: Vector2i) -> int:
	var coord = vcc - wcc*2
	return VCC_POS_OFFSET_MAP.get(coord, -1)

# 通过索引获取VC坐标（O(1)查询）
static func get_vcc_by_idx(wcc: Vector2i, index: int) -> Vector2i:
	if index < 0 or index >= VCC_OFFSET_INDEX_MAP.size():
		return Vector2i.ZERO
	return wcc*2 + VCC_OFFSET_INDEX_MAP[index]

# 获取WCC对应的所有VC坐标（直接返回列表，避免业务层遍历）
static func get_vcc_list_in_wcc(wcc: Vector2i) -> Array:
	return get_vcc_idx_dic(wcc).keys()

# 获取区域内所有cell coord。考虑的是屏幕空间矩形区域
static func get_all_cc_in_screen_rect(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var cc:Array[Vector2i] = []
	# 计算对角cell的s和t（x-y和x+y）
	var s1 = start.x - start.y
	var t1 = start.x + start.y
	var s2 = end.x - end.y
	var t2 = end.x + end.y
	
	# 严格使用对角cell的s-t范围，不扩展
	var s_min = min(s1, s2)
	var s_max = max(s1, s2)
	var t_min = min(t1, t2)
	var t_max = max(t1, t2)
	
	# 遍历范围内的s和t，只保留整数x,y的cell
	for s in range(s_min, s_max + 1):
		for t in range(t_min, t_max + 1):
			# 确保x和y是整数（s和t同奇偶）
			if (s + t) % 2 != 0:
				continue
			var x = int((s + t) / 2.0)
			var y = int((t - s) / 2.0)
			cc.append(Vector2i(x, y))
	return cc

# 获取区域内所有cell coord。考虑的是世界空间矩形区域
static func get_all_cc_in_world_rect(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var ccs:Array[Vector2i] = []
	var step = (end - start).sign()
	step.x = 1 if step.x == 0 else step.x
	step.y = 1 if step.y == 0 else step.y
	for y in range(start.y,end.y+step.y,step.y):
		for x in range(start.x,end.x+step.x,step.x):
			var cc = Vector2i(x,y)
			ccs.append(cc)
	return ccs
	
# isometric 中，get_suround_cells 得到的是4方向邻居故不采用 key:ncc value:ncc pos index (0-7)
static func get_used_neighbors_by_sid(cc: Vector2i, sid:int, tml:TileMapLayer, use_sid:bool = true) -> Dictionary:
	var out: Dictionary = {}
	for i in NEIGHBOR_OFFSET_8DIR.size():
		var offset = NEIGHBOR_OFFSET_8DIR[i]
		var ncc = cc + offset
		if use_sid:
			if tml.get_used_cells_by_id(sid).has(ncc):
				out.set(ncc,i)
		else:
			if tml.get_used_cells().has(ncc):
				out.set(ncc,i)
	return out

static func get_used_surround_neighbors(cc: Vector2i, tml:TileMapLayer,is_used:bool = true) -> Dictionary:
	var out: Dictionary = {}
	for i in NEIGHBOR_OFFSET_4DIR.size():
		var offset = NEIGHBOR_OFFSET_4DIR[i]
		var ncc = cc + offset
		if is_used:
			if tml.get_used_cells().has(ncc):
				out.set(ncc,i)
		else:out.set(ncc,i)
	return out

const CORNER_IDX_DIC:Dictionary ={
	0:[0,1,8,7],
	1:[1,2,3,8],
	2:[8,3,4,5],
	3:[7,8,5,6],
}

const OFFSET_8DIR_CENTER: Array[Vector2i] = [
	Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1),
	Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1),
	Vector2i(0, 0),
]

const OFFSET_8DIR_CENTER_MAP: Dictionary[int,Vector2i] = {
	0:Vector2i(1, -1), 1:Vector2i(1, 0), 2:Vector2i(1, 1), 3:Vector2i(0, 1),
	4:Vector2i(-1, 1), 5:Vector2i(-1, 0), 6:Vector2i(-1, -1), 7:Vector2i(0, -1),
	8:Vector2i(0, 0),
}

# get surounding cell 的顺序是下左上右 故不采用
# 左上：0 右上：1 右下：2 左下：3
static func get_used_suround_neighbors(cc: Vector2i, tml:TileMapLayer)-> Dictionary:
	var out: Dictionary = {}
	for i in NEIGHBOR_OFFSET_4DIR.size():
		var offset = NEIGHBOR_OFFSET_4DIR[i]
		var ncc = cc + offset
		if tml.get_used_cells().has(ncc):
			out.set(ncc,i)
	return out

static func set_cell(tml:TileMapLayer,cc:Vector2i,sid:int = 0, ac:Vector2i = Vector2i.ZERO, aid:int = 0)->void:
	tml.set_cell(cc,sid,ac,aid)

static func get_vcc_atlas_y(vcc: Vector2i, wcc: Vector2i, sid: int, is_border: bool, vtml:TileMapLayer) -> int:
	if not is_border:
		return 12
	var idx = get_idx_of_vcc(vcc, wcc)
	var nvcc_idxs = get_used_neighbors_by_sid(vcc, sid, vtml).values()
	var ac_array: Array = ["0","0","0","0","0","0","0","0"] # 使用 Array 避免多次创建字符串
	for i in nvcc_idxs:
		ac_array[i] = "1"
	var final_ac_str = "".join(ac_array) + "|" + str(idx) # <-- 字符串只拼接一次
	return EDGE_STR_AC_DIC.get(final_ac_str, 12) # 使用 get(key, default) 避免查找失败

#static func get_vcc_atlas_y_by_cache(vcc: Vector2i, wcc: Vector2i, sid: int, is_border: bool, vcc_sid_cache:Dictionary) -> int:
	#if not is_border:
		#return 12
	#var idx = get_idx_of_vcc(vcc, wcc)
	##if idx == -1 : return 12
	#var used_neighbors_cache = get_used_neighbors_from_cache(vcc, sid, vcc_sid_cache)
	#var nvcc_idxs = used_neighbors_cache.values()
	#var ac_array: Array = ["0","0","0","0","0","0","0","0"] # 使用 Array 避免多次创建字符串
	#for i in nvcc_idxs:
		#ac_array[i] = "1"
	#var final_ac_str = "".join(ac_array) + "|" + str(idx) # <-- 字符串只拼接一次
	#return EDGE_STR_AC_DIC.get(final_ac_str, 12) # 使用 get(key, default) 避免查找失败

static func get_vcc_atlas_y_by_cache(vcc: Vector2i, sid: int, vcc_sid_border_idx_cache:Dictionary) -> int:
	if not vcc_sid_border_idx_cache[vcc][2]: # not border vcell
		return 12
	var idx = vcc_sid_border_idx_cache[vcc][0]
	if idx == -1 : return 12
	
	var used_neighbors_cache = get_used_neighbors_from_cache(vcc, sid, vcc_sid_border_idx_cache)
	var nvcc_idxs = used_neighbors_cache.values()
	var ac_array: Array = ["0","0","0","0","0","0","0","0"] # 使用 Array 避免多次创建字符串
	for i in nvcc_idxs:
		ac_array[i] = "1"
	var final_ac_str = "".join(ac_array) + "|" + str(idx) # <-- 字符串只拼接一次
	return EDGE_STR_AC_DIC.get(final_ac_str, 12) # 使用 get(key, default) 避免查找失败


# 使用缓存 CC_CACHE 查找邻居的使用状态，并返回位置索引
# CC_CACHE: Key: Vector2i (vcc), Value: int (sid)
# use_sid:找到sid相同的所有存在的邻居
# not use_sid:找到所有存在的邻居，不论sid是否一致
static func get_used_neighbors_from_cache(cc: Vector2i, sid:int, cc_cache: Dictionary, use_sid:bool = true) -> Dictionary:
	var out: Dictionary = {} # Key: Vector2i (ncc), Value: int (i, the index 0-7)
	for i in NEIGHBOR_OFFSET_8DIR.size():
		var offset = NEIGHBOR_OFFSET_8DIR[i] # [cite: 7]
		var ncc = cc + offset
		var ncc_sid = cc_cache.get(ncc, -1) # 从缓存中获取邻居 VCC 的 Source ID。如果不存在，则返回 -1
		if ncc_sid != -1: # vcc存在
			if use_sid: #考虑sid是否一致
				if ncc_sid == sid:
					out[ncc] = i # <-- 确保返回的是索引 i (0-7)
			else : out[ncc] = i
	return out

# 获取 CC 列表中所有 VCC 的 Source ID - 用于构建缓存 如果sid是-1说明此vcc不存在，从而避免使用原生的get_used_cells_by_id(sid).has(cc)
static func get_vcc_sid_dic_of_wcc_arr(cc_arr: Array[Vector2i], tml: TileMapLayer) -> Dictionary:
	var vcc_sid_dic: Dictionary = {} # Key: Vector2i (vcc), Value: int (sid)
	for cc in cc_arr:
		var vcc_list = get_vcc_list_in_wcc(cc)
		for vcc in vcc_list:
			var sid = tml.get_cell_source_id(vcc)
			vcc_sid_dic[vcc] = sid
	return vcc_sid_dic

static func get_neighbors(wcc:Vector2i)->Array[Vector2i]:
	var out : Array[Vector2i] = []
	for i in NEIGHBOR_OFFSET_8DIR.size():
		var offset = NEIGHBOR_OFFSET_8DIR[i]
		var ncc = wcc + offset
		out.append(ncc)
	return out
