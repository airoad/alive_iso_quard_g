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
