class_name VCell  # 类名，全局可引用
extends RefCounted  # 继承RefCounted，支持字典存储，避免内存泄漏

# VC核心属性（与主脚本逻辑对应）
var coord: Vector2i  # 可视化单元格（VC）的坐标（唯一标识，用于复用）
var source_id: int  # TileSet中的图集ID（SId，最终渲染用）
var atlas_coord: Vector2i  # 图集内的瓦片坐标（对应nameDic的value）
var alter: int #变体 镜像旋转

# 构造函数（初始化所有属性）
func _init(
	vc_coord: Vector2i,
	sid: int,
	als_coord: Vector2i,
	alt: int = 0
) -> void:
	coord = vc_coord
	source_id = sid
	atlas_coord = als_coord
	alter = alt
