class_name TilemapUtils
extends RefCounted

# ======================================
# 核心常量（集中管理，避免重复创建）
# ======================================
# 8向邻居偏移（含斜向）
const NEIGHBOR_8DIR: Array[Vector2i] = [
	Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1),
	Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1)
]
# 4向邻居偏移（正向）
const NEIGHBOR_4DIR: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)
]
const NCC_ARRAY_SIZE: int = 8
const INVALID_WCC: Vector2i = Vector2i(-1, -1)
# VC位置索引映射（0=上，1=右，2=下，3=左）
const VCC_POS_MAP: Dictionary = {
	Vector2i(0, 0): 0,
	Vector2i(0, 1): 1,
	Vector2i(-1, 1): 2,
	Vector2i(-1, 0): 3
}
# VC位置反向映射（index→coord）
const VCC_INDEX_MAP: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0)
]

# vc接触情况：
# contact_count|main_contact_dir|pos_index|neighbor_nvc_pos
# 接触数|接触方向|vc位置|nvc位置
const AC_DIC:Dictionary[String, Vector2i] = { 
	"0|(0,0)|0|-1": Vector2i(0,0), "0|(0,0)|1|-1": Vector2i(1,0), "0|(0,0)|2|-1": Vector2i(2,0), "0|(0,0)|3|-1": Vector2i(3,0), 
	"1|(0,-1)|0|1": Vector2i(3,1), "1|(0,-1)|3|2": Vector2i(2,1), "1|(0,1)|1|0": Vector2i(3,1), "1|(0,1)|2|3": Vector2i(2,1), 
	"1|(-1,0)|2|1": Vector2i(1,1), "1|(-1,0)|3|0": Vector2i(0,1),  "1|(1,0)|1|2": Vector2i(1,1), "1|(1,0)|0|3": Vector2i(0,1), 
	"2|(1,0)|1|2": Vector2i(1,2), "2|(-1,0)|3|0": Vector2i(3,2), "2|(-1,0)|2|1": Vector2i(0,2),"2|(1,0)|0|3": Vector2i(2,2),
 }



# ======================================
# 缓存与对象池（修复：单层类型标注）
# ======================================
static var _vcc_sub_dict_cache: Dictionary = {}  # key=wcc(Vector2i), value=dict(vcc→index)
static var _vcc_neighbor_cache: Dictionary = {}  # key=wcc(Vector2i), value=dict(vcc→array[Vector2i])
static var _ncc_array_pool: Array = []           # 元素=array[Vector2i]

# ======================================
# 高效接口（修复：返回值单层类型）
# ======================================
# 获取WCC对应的VC字典（直接返回sub_dict，去外层嵌套）
static func get_wcc_vcc_dict(wcc: Vector2i) -> Dictionary:
	# 缓存命中直接返回副本
	if wcc in _vcc_sub_dict_cache:
		return _vcc_sub_dict_cache[wcc].duplicate()
	
	# 缓存未命中：计算VC坐标（基于WCC偏移）
	var vcc_dict: Dictionary = {}
	for base_coord in VCC_POS_MAP:
		var vcc_coord = wcc * 2 + base_coord
		vcc_dict[vcc_coord] = VCC_POS_MAP[base_coord]
	
	_vcc_sub_dict_cache[wcc] = vcc_dict.duplicate()
	return vcc_dict

# 通过VC坐标获取位置索引（0-3，O(1)查询）
static func get_vcc_index(vcc_coord: Vector2i, wcc: Vector2i) -> int:
	var base_coord = vcc_coord - wcc * 2
	return VCC_POS_MAP.get(base_coord, -1)

# 通过索引获取VC坐标（O(1)查询）
static func get_vcc_coord(wcc: Vector2i, index: int) -> Vector2i:
	if index < 0 or index >= VCC_INDEX_MAP.size():
		return Vector2i.ZERO
	return wcc * 2 + VCC_INDEX_MAP[index]

# 获取WCC对应的所有VC坐标（直接返回列表，避免业务层遍历）
static func get_wcc_vcc_list(wcc: Vector2i) -> Array:
	return get_wcc_vcc_dict(wcc).keys()

# ======================================
# 对象池操作（修复：类型校验简化）
# ======================================
static func fetch_ncc_array() -> Array:
	if _ncc_array_pool.size() > 0:
		return _ncc_array_pool.pop_back()
	
	var new_array: Array = []
	for i in NCC_ARRAY_SIZE:  # 修复：无范围语法，直接用数量
		new_array.append(Vector2i.ZERO)
	return new_array

static func return_ncc_array(array: Array) -> void:
	if array.size() != NCC_ARRAY_SIZE:
		push_warning("对象池：非法数组（需8个Vector2i），已忽略")
		return
	
	# 重置数组元素
	for i in NCC_ARRAY_SIZE:
		array[i] = Vector2i.ZERO
	_ncc_array_pool.append(array)

# ======================================
# 邻居计算（修复：循环语法+返回值类型）
# ======================================
static func batch_get_vcc_neighbors(wcc_list: Array) -> Dictionary:
	var out: Dictionary = {}
	
	for wcc in wcc_list:
		if wcc in _vcc_neighbor_cache:
			# 深拷贝缓存，避免原数据被修改（修复：字典遍历语法）
			var cached = _vcc_neighbor_cache[wcc]
			var duplicated: Dictionary = {}
			for vcc in cached:
				var ncc_array = cached[vcc]
				duplicated[vcc] = ncc_array.duplicate()
			out[wcc] = duplicated
			continue
		
		var vcc_dict = get_wcc_vcc_dict(wcc)
		var vcc_neighbors: Dictionary = {}
		
		for vcc_coord in vcc_dict:
			var ncc_array = fetch_ncc_array()
			for i in NCC_ARRAY_SIZE:
				ncc_array[i] = vcc_coord + NEIGHBOR_8DIR[i]
			vcc_neighbors[vcc_coord] = ncc_array
		
		# 缓存副本（修复：字典遍历语法）
		var cache_copy: Dictionary = {}
		for vcc in vcc_neighbors:
			var ncc_array = vcc_neighbors[vcc]
			cache_copy[vcc] = ncc_array.duplicate()
		_vcc_neighbor_cache[wcc] = cache_copy
		
		out[wcc] = vcc_neighbors.duplicate()
	
	return out

static func get_vcc_neighbors(wcc: Vector2i) -> Dictionary:
	return batch_get_vcc_neighbors([wcc]).get(wcc, {})

# ======================================
# 清理接口（保持原功能）
# ======================================
static func clear_cache(wcc: Vector2i = INVALID_WCC) -> void:
	if wcc == INVALID_WCC:
		_vcc_sub_dict_cache.clear()
		_vcc_neighbor_cache.clear()
	else:
		_vcc_sub_dict_cache.erase(wcc)
		_vcc_neighbor_cache.erase(wcc)

static func clear_pool() -> void:
	_ncc_array_pool.clear()

static func clear_all() -> void:
	clear_cache()
	clear_pool()

# ======================================
# 方向映射（修复：单层类型标注）
# ======================================
static func get_direction_mapping() -> Dictionary:
	return {
		Vector2i(-1, 0):  [ [2, 3], [1, 0] ],
		Vector2i(1, 0):   [ [0, 1], [3, 2] ],
		Vector2i(0, -1):  [ [0, 3], [1, 2] ],
		Vector2i(0, 1):   [ [1, 2], [0, 3] ]
	}
	
static func get_all_cells_in_rect(start: Vector2i, end: Vector2i) -> Array:
	var cells = []
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
			cells.append(Vector2i(x, y))
	return cells
