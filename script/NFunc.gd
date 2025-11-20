class_name NFunc  # 类名，全局可引用
extends RefCounted  # 继承RefCounted，支持字典存储，避免内存泄漏

static func scan_directory(dir_path: String, ex: String) -> Dictionary:
	var dic : Dictionary = {}
	var dir = DirAccess.open(dir_path)
	if not dir:
		printerr("目录不存在或无法访问：", dir_path)
		return dic
	# 关键：开启递归扫描（必须传true，否则不扫描子目录）
	dir.list_dir_begin() 
	var current_entry = dir.get_next()
	while current_entry != "":
		var full_path = dir.get_current_dir() + "/" + current_entry
		# 筛选.tres文件并尝试加载为TileSet
		if dir.file_exists(full_path) and current_entry.ends_with(ex):
			var loaded_asset = load(full_path)
			if loaded_asset:
				dic[full_path] = loaded_asset
		current_entry = dir.get_next()
	dir.list_dir_end()
	return dic

static func get_vcc_dic(wcc:Vector2i)->Dictionary[int,Vector2i]:
	var out:Dictionary[int,Vector2i] = {
		0:wcc+Vector2i(0,0), 
		1:wcc+Vector2i(0,1), 
		2:wcc+Vector2i(-1,1), 
		3:wcc+Vector2i(-1,0)
	}
	return out

static func get_wc_nc_arr(wcc:Vector2i)->Array[Vector2i]:
	return [
		wcc+Vector2i(1,-1),wcc+Vector2i(1,0),wcc+Vector2i(1,1),wcc+Vector2i(0,1),
		wcc+Vector2i(-1,1),wcc+Vector2i(-1,0),wcc+Vector2i(-1,-1),wcc+Vector2i(0,-1)
	]

static func get_vc_corner_coord(wcc:Vector2i)->Array[Array]:
	var wc_nc_arr = get_wc_nc_arr(wcc)
	return [
		[wc_nc_arr[0], wc_nc_arr[1], wcc, wc_nc_arr[7]],
		[wc_nc_arr[1], wc_nc_arr[2], wc_nc_arr[3], wcc],
		[wcc, wc_nc_arr[3], wc_nc_arr[4], wc_nc_arr[5]],
		[wc_nc_arr[7], wcc, wc_nc_arr[5], wc_nc_arr[6]]
	]

static func get_ncc_dic(wcc:Vector2i)->Dictionary[Vector2i,Array]:
	var vcc_dic = get_vcc_dic(wcc)
	var out:Dictionary[Vector2i,Array] = {}
	for i in 4:
		var vcc = vcc_dic[i]
		var ncc_arr:Array[Vector2i] = [
			vcc+Vector2i(1,0),
			vcc+Vector2i(0,1),
			vcc+Vector2i(-1,0),
			vcc+Vector2i(0,-1)
		]
		out.set(vcc, ncc_arr)
	return out



static func keep_by_index_arr(origin:Array,arr:Array)->Array[int]:
	var temp:Array[int] = []
	for i in arr:
		var v:int = origin[i]
		temp.append(v)
	return temp
	
static func str_set_at(original: String, index: int, new_char: String) -> String:
	if index < 0 or index >= original.length():
		return original
	var arr = []
	for i in original.length():
		arr.append(original[i])
	arr[index] = new_char
	var s = ""
	for a in arr:
		s += a
	return s

static func array_remove_duplicates_keep_order_first(arr: Array) -> Array:
	if arr.is_empty(): return []
	var fst = arr[0]
	var unique_arr: Array = []
	for elem in arr:
		# 只添加临时数组中没有的元素
		if not unique_arr.has(elem):
			unique_arr.append(elem)
	unique_arr.set(0,fst)
	return unique_arr

static func format_sid_arr(arr:Array)->Array:
	var out = array_remove_duplicates_keep_order_first(arr)
	out.sort()
	out.reverse()
	return out

static func array_to_str(arr:Array, spl:String)->String:
	var out_str:String =""
	if arr.size() == 0: return out_str
	else:
		for i in arr.size():
			if i != arr.size()-1:
				out_str += str(arr[i])+spl
			else:out_str += str(arr[i])
	return out_str

# 保存json到硬盘（处理Vector2i序列化）
static func save_json(data, path:String) -> void:	
	var file = FileAccess.open(path, FileAccess.WRITE)
	var json_string = JSON.stringify(data)
	file.store_line(json_string)
	print("✅ 已保存到：", path)

# 从硬盘加载json
static func load_json(path:String):
	if not FileAccess.file_exists:
		print("ℹ️ 未找到文件")
		return
	
	var file = FileAccess.open(path,FileAccess.READ)
	var json_string = file.get_line()
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if not parse_result == OK:
		print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
		return
	var data = json.data
	print("✅ 加载成功\n")
	return data

static func save_dic_vec(dic:Dictionary, path:String):
	# 序列化：将Vector2i转为数组，方便JSON保存
	var serial_dict: Dictionary = {}
	for key in dic:
		var vec = dic[key]
		serial_dict[key] = [vec.x, vec.y]  # Vector2i → [x,y]
	save_json(serial_dict,path)

static func load_dic_vec(path):
	var data = load_json(path)
	var dic:Dictionary[String,Array] = {}
	for k in data:
		var v = data[k]
		var vec:Vector2i = Vector2i.ZERO
		vec.x = v[0]
		vec.y = v[1]
		dic.set(k,vec)
	return dic	
	
	
