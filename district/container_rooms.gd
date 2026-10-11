extends RefCounted
## 由 2026-10-03 的「鲸落港 · 场景容器扩展包」搭出来的两个新地点。
##
## 和工程里其它房间的根本差别：这里摆的是**真的能开合的容器**，
## 由 container_runtime.tscn 提供（真实铰链 / 抽屉 / 双门 / 保险柜先收锁栓再开门），
## 默认 2.4 秒一次动作，动作中反向也能接上，open 完成后发 opened_changed。
##
## 两个地点刻意选了完全不同的场合，避免和现有房间撞脸：
##   depot     港湾补给仓 —— 工业物流：混凝土灰蓝、货笼、气瓶、托盘、搬运车
##   coldstore 后厨冷藏间 —— 不锈钢后厨：冷青白、双门冷藏柜、存货抽屉、保险柜
## 现有房间都是木色 + 米白的居住感，这两个走「工作场所」，配色和物件都不重叠。
##
## 接入约定（来自素材包说明）：容器 GEOMETRY 在 models/containers/，
## container_specs.json 必须在 res:// 根目录，controller 只负责模型开合，
## 物品/背包/耗时逻辑要自己接 —— 这里只做到「能开能关 + 报出开了哪个」。

const RUNTIME := "res://container_runtime.tscn"
const PROP_DIR := "res://models/props/"
const TIDAL_DIR := "res://models/tidal/"
## 144 件现代室内家具/器材（真实尺寸、自带碰撞）。看 district/interior_props.gd 的说明。
const InteriorProps = preload("res://district/interior_props.gd")
const BUILDING_DIR := "res://models/buildings/"

## 从包的某个目录摆一个静态模型。
static func _pack_in(g, dir: String, id: String, pos: Vector3, angle: float = 0.0):
	var packed: PackedScene = load(dir + id + ".tscn")
	if packed == null:
		push_warning("ContainerRooms: 缺少模型 " + dir + id)
		return null
	var node = packed.instantiate()
	node.position = pos
	node.rotation_degrees.y = angle
	g.world.add_child(node)
	return node

static func _pack(g, id: String, pos: Vector3, angle: float = 0.0):
	return _pack_in(g, PROP_DIR, id, pos, angle)

## 把一个模型量出来再缩放到目标占地，然后摆上去。
##
## 为什么要量：GLB 的实际尺寸从文件名看不出来，手填缩放比就是在赌。
## 量出原始 AABB 再算比例，结果是确定的。
## （只用于不旋转的地面/水面这类铺开的东西；旋转过的节点缩放轴会跟着转。）
static func _pack_fit(g, dir: String, id: String, pos: Vector3, footprint: Vector2):
	var node = _pack_in(g, dir, id, Vector3.ZERO)
	if node == null:
		return null
	var box := _aabb_of(node)
	if box.size.x > 0.001 and box.size.z > 0.001:
		node.scale = Vector3(footprint.x / box.size.x, 1.0, footprint.y / box.size.z)
		# 缩放围绕原点，量出来的包围盒中心会偏移，按中心修正回去
		var c := box.get_center()
		node.position = pos - Vector3(c.x * node.scale.x, 0.0, c.z * node.scale.z)
	return node

static func _aabb_of(node: Node3D) -> AABB:
	var found := false
	var box := AABB()
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = child
		if mi.mesh == null:
			continue
		var xf: Transform3D = node.global_transform.affine_inverse() * mi.global_transform
		var b: AABB = xf * mi.get_aabb()
		box = b if not found else box.merge(b)
		found = true
	return box

static func build(g, id: String) -> Dictionary:
	_container_seq = 0
	var out: Dictionary = {}
	match id:
		"depot":
			out = _depot(g)
		"coldstore":
			out = _coldstore(g)
		"vault":
			out = _vault(g)
		"lab":
			out = _lab(g)
		"archive":
			out = _archive(g)
		"customs":
			out = _customs(g)
		"weather":
			out = _weather(g)
		"hub":
			out = _hub(g)
		"quarantine":
			out = _quarantine(g)
		"spares":
			out = _spares(g)
		"tidal_high":
			out = _tidal(g, true)
		"tidal_low":
			out = _tidal(g, false)
		"depot_2f":
			out = _gallery(g)
	# 容器全部摆完之后再统一登记进战利品系统，
	# 放在各个 _xxx() 里会重复执行、而且那时候容器还没齐
	if not out.is_empty():
		_wire_loot(g)
	return out

# ---------------------------------------------------------------- 潮汐档案馆（回字形环廊）

## 平面是个「回」字：南北两条长翼 + 东西两条短翼围成一个**封闭中庭**。
## 四翼首尾相接，所以**能绕一圈走回原地** —— 这是工程里其它任何房间都做不到的：
## 方盒子、L 形、U 形走到底都是死路，只有环廊能绕回来。
## 中庭四面都砌了墙（北 0.85 / 东西 1.15 / 南 2.6），是一个看得进、走不进的采光天井。
static func _archive(g) -> Dictionary:
	var north := Rect2(-9.0, -7.0, 18.0, 3.5)
	var south := Rect2(-9.0, 3.5, 18.0, 3.5)
	var west := Rect2(-9.0, -3.5, 3.5, 7.0)
	var east := Rect2(5.5, -3.5, 3.5, 7.0)
	var size := _shell_shaped(g, [north, south, west, east], Color("6b7078"), Color("9aa2a8"), Color("eef4f8"))
	# 中庭：下沉一档的地坪 + 绿化，从四个翼都能看进来
	var b = g._builder(g.shell)
	b.box(Vector3(10.6, .12, 6.6), Vector3(0, -.03, 0), Color("5f6a63"))
	b.box(Vector3(10.2, .02, 6.2), Vector3(0, .04, 0), Color("7d8f7a"))
	for spec in [[-3.0, -1.6], [3.0, -1.6], [-3.0, 1.6], [3.0, 1.6]]:
		_prop(g, "planter", Vector3(spec[0], .04, spec[1]))
	_prop(g, "palm", Vector3(0, .04, 0))
	_prop(g, "rocks", Vector3(-1.4, .04, .9))
	# 北翼：档案柜与海图柜（工程自己的 v18 模型也在这一排）
	for x in [-7.4, -6.1, -4.8, -3.5]:
		_container(g, "searchable_file_cabinet", Vector3(x, 0, -5.6), 0)
	_container(g, "port_manifest_drawer", Vector3(-1.6, 0, -5.6), 0)
	_container(g, "wall_data_safe", Vector3(-0.2, 0, -5.8), 0)
	g._prop("v18_special_chart_cabinet", Vector3(1.6, 0, -5.6))
	g._prop("v18_interior_ivory_bookcase", Vector3(4.2, 0, -6.0))
	g._prop("v18_interior_ivory_bookcase", Vector3(6.4, 0, -6.0))
	# 南翼：阅览与检索
	_container(g, "currency_transport_case", Vector3(-6.6, 0, 5.6), 0)
	_container(g, "cold_chain_medical_cabinet", Vector3(-5.2, 0, 5.6), 0)
	g._prop("v18_special_star_desk", Vector3(-1.4, 0, 5.8))
	g._prop("v18_reading_chair", Vector3(1.2, 0, 5.9))
	g._prop("v18_reading_chair", Vector3(3.0, 0, 5.9))
	_prop(g, "notice_board", Vector3(6.4, 0, 6.2), 180)
	# 东西短翼：各放一台冷柜
	_container(g, "laboratory_specimen_freezer", Vector3(-7.6, 0, 0), 90)
	_container(g, "encrypted_electronics_case", Vector3(7.4, 0, 0), -90)
	# 档案馆陈设（interior_pack 144 件）。约束：中庭是下沉绿地、四条翼都要能绕圈 ——
	# 所以全部贴翼的墙边摆，环廊本身留空（回字形的意义就是能走一圈）。
	InteriorProps.place(g, "storage_02", Vector3(-8.4, 0, -6.4), 0)     # 分格开放书架（北翼后墙西端）
	InteriorProps.place(g, "storage_02", Vector3(2.9, 0, -6.4), 0)      # 分格开放书架（北翼后墙中段）
	InteriorProps.place(g, "lounge_11", Vector3(-2.9, 0, -4.3), 0)      # 双面图书推车
	InteriorProps.place(g, "storage_02", Vector3(-8.5, 0, 2.2), 90)     # 西翼书架（贴西墙）
	InteriorProps.place(g, "storage_02", Vector3(8.5, 0, -2.2), -90)    # 东翼书架（贴东墙）
	InteriorProps.place(g, "lounge_04", Vector3(-3.3, 0, 5.9), 0)       # 圆形阅览桌
	# 两把椅子放桌子**南侧**。原来放在 (-4.4/-2.2, 4.8) 且转了 ±135°：
	# 旋转会把包围盒撑大，−135° 那把就蹭到了星图台（0.06 m³）。摆正、移到桌子正南。
	InteriorProps.place(g, "lounge_01", Vector3(-3.3, 0, 4.55), 0)      # 软垫餐椅 A
	InteriorProps.place(g, "lounge_01", Vector3(-1.6, 0, 4.55), 0)      # 软垫餐椅 B
	InteriorProps.place(g, "storage_08", Vector3(4.8, 0, 5.9), 180)     # 玻璃陈列柜
	InteriorProps.place(g, "lounge_05", Vector3(1.6, 0, 4.3), 180)      # 演讲台与话筒（检索台）· 原 (0.1,4.7) 压在落点 (0,4.4) 上，移到南翼空位
	_sign(g, "潮汐档案馆 · 回字形环廊（能绕一圈）", Vector3(0, 3.2, -7.5), 32, Color("eef6ff"))
	return {"bounds": size, "spawn": Vector3(0, 0, 4.4), "exit": Vector3(0, 0, 6.4), "camera_size": 34.0,
		"zones": [_zone("north", "北翼档案库", Rect2(-9.0, -7.0, 18.0, 3.5)),
			_zone("south", "南翼阅览厅", Rect2(-9.0, 3.5, 18.0, 3.5)),
			_zone("west", "西翼", Rect2(-9.0, -3.5, 3.5, 7.0)),
			_zone("east", "东翼", Rect2(5.5, -3.5, 3.5, 7.0)),
			_zone("court", "中央天井", Rect2(-5.5, -3.5, 11.0, 7.0))]}

# ---------------------------------------------------------------- 港口海关查验厅（T 形）

## 平面是个 T：20×8 的宽厅，中间往北伸出一条 7×6 的支廊。
## 进门（南侧矮墙那侧）只看到宽厅；支廊在正中，要走到中段才会发现后面还有一间。
static func _customs(g) -> Dictionary:
	var hall := Rect2(-10.0, -4.0, 20.0, 8.0)
	var stem := Rect2(-3.5, -10.0, 7.0, 6.0)
	var size := _shell_shaped(g, [hall, stem], Color("737a80"), Color("a6aeb2"), Color("f0f4f6"))
	var b = g._builder(g.shell)
	# 查验通道：地上的两条黄线把宽厅切成「待查」和「已放行」
	for z in [-2.4, -.2, 2.0]:
		b.box(Vector3(18.4, .02, .10), Vector3(0, .052, z), Color("c9b072"))
	# 支廊：过检台与货笼
	_container(g, "harbor_cargo_cage", Vector3(-2.4, 0, -8.4), 0)
	_container(g, "long_equipment_case", Vector3(1.2, 0, -8.4), 0)
	_container(g, "port_manifest_drawer", Vector3(3.0, 0, -6.0), -90)
	_prop(g, "relay_service_terminal", Vector3(-2.6, 0, -6.0))
	# 宽厅：一侧货、一侧单证
	_container(g, "marine_waterproof_case", Vector3(-8.6, 0, -2.6), 0)
	_container(g, "field_supply_crate", Vector3(-7.2, 0, -2.6), 0)
	_container(g, "reinforced_flight_case", Vector3(-5.8, 0, -2.6), 0)
	_container(g, "harbor_cargo_cage", Vector3(7.6, 0, -2.5), 0)
	_container(g, "secure_equipment_locker", Vector3(9.2, 0, .2), -90)
	_container(g, "office_armored_safe", Vector3(-9.3, 0, .4), 90)
	_container(g, "currency_transport_case", Vector3(-7.0, 0, 2.9), 0)
	_container(g, "searchable_file_cabinet", Vector3(-5.4, 0, 2.9), 0)
	_prop(g, "port_plastic_pallet", Vector3(5.4, 0, 2.6))
	_prop(g, "compact_pallet_jack", Vector3(4.0, 0, 3.0), 6)
	_prop(g, "token_currency_counter", Vector3(-1.0, 0, 3.0))
	_prop(g, "notice_board", Vector3(2.0, 0, 3.4), 180)
	_prop(g, "bar_counter", Vector3(8.6, 0, 3.0), -90)
	# 查验厅陈设（interior_pack 144 件室内模型）。
	# 约束：宽厅中间那 3.8 米是查验通道（地上三条黄线），支廊口在 x -3.5~3.5 ——
	# 所以东西全部**贴边**摆，且避开支廊正对的那一段。
	InteriorProps.place(g, "retail_01", Vector3(5.15, 0, -3.2), 180)      # 传送带收银台 → 查验线
	InteriorProps.place(g, "decor_12", Vector3(6.6, 0, -3.2), 180)        # 透明信息立牌
	InteriorProps.place(g, "storage_05", Vector3(-9.7, 0, 2.4), 90)       # 六格更衣柜（西墙）
	InteriorProps.place(g, "architecture_11", Vector3(9.7, 0, 2.4), -90)  # 嵌墙电气控制柜（东墙）
	InteriorProps.place(g, "medical_08", Vector3(9.8, 0, -2.2), -90)      # 壁挂急救药箱（东墙）
	InteriorProps.place(g, "logistics_06", Vector3(-9.7, 0, -2.2), 90)    # 落地灭火器（西墙）
	InteriorProps.place(g, "lounge_02", Vector3(-3.2, 0, 3.1), 180)       # 三席等候椅
	InteriorProps.place(g, "utility_10", Vector3(0.6, 0, 3.2), 180)       # 脚踏分类垃圾桶
	_sign(g, "港口海关查验厅 · T 形平面", Vector3(0, 3.2, -10.5), 32, Color("f2f6f8"))
	return {"bounds": size, "spawn": Vector3(0, 0, 1.6), "exit": Vector3(0, 0, 3.6), "camera_size": 36.0,
		"zones": [_zone("hall", "查验宽厅", Rect2(-10.0, -4.0, 20.0, 8.0)),
			_zone("stem", "支廊过检区", Rect2(-3.5, -10.0, 7.0, 6.0))]}

# ---------------------------------------------------------------- 山地气象站（Z 形 / 阶梯形）

## 三段错位的矩形接成一个 Z：通道先偏左、再偏右，一路转折。
## 和 L 形的区别在**转折次数** —— L 只转一次，Z 转两次，中间那段两头都看不到尽头。
static func _weather(g) -> Dictionary:
	var a := Rect2(-9.0, -6.0, 12.0, 5.0)
	var b := Rect2(-1.0, -1.0, 5.0, 6.0)
	var c := Rect2(-4.0, 5.0, 12.0, 5.0)
	var size := _shell_shaped(g, [a, b, c], Color("5f6b6a"), Color("93a19c"), Color("e8f6ef"))
	var bd = g._builder(g.shell)
	# 观测台面：抬高一级，露天的感觉
	bd.box(Vector3(11.6, .16, 4.6), Vector3(-3.0, .06, -3.5), Color("6f7d78"))
	# A 段：仪器存放
	_container(g, "encrypted_electronics_case", Vector3(-7.4, 0, -4.4), 0)
	_container(g, "sample_transport_case", Vector3(-6.1, 0, -4.4), 0)
	_container(g, "laboratory_specimen_freezer", Vector3(-4.8, 0, -4.4), 0)
	_container(g, "battery_module_crate", Vector3(-3.5, 0, -4.4), 0)
	g._prop("v18_special_weather_station", Vector3(0.4, .16, -3.6))
	g._prop("v18_interior_writing_desk", Vector3(-1.8, .16, -2.4))
	# B 段：转折处的值班位
	_container(g, "server_service_cabinet", Vector3(2.6, 0, 0), -90)
	_container(g, "wall_data_safe", Vector3(2.8, 0, 2.0), -90)
	g._prop("v18_special_chart_cabinet", Vector3(-.2, 0, 3.4))
	# C 段：观测与休整
	_container(g, "field_medical_chest", Vector3(-2.6, 0, 6.4), 0)
	_container(g, "searchable_file_cabinet", Vector3(-1.2, 0, 6.4), 0)
	# 保险柜原来在 (6.6,6.2)：它和 C 段的圆餐桌(5.2,7.6)+两把椅子连成一道篱笆，
	# 把 C 段**东端约 1.5×3 米的地板整块封死**（跨帧网格实测：那片自由格全部不可达）。
	# 挪到紧贴东墙的 (7.4,7.0)，桌子与柜子之间让出约 0.9 米通道。
	_container(g, "secure_equipment_locker", Vector3(7.4, 0, 7.0), 180)
	g._prop("v18_special_telescope", Vector3(1.8, 0, 8.4))
	g._prop("v18_reading_chair", Vector3(-3.4, 0, 8.6))
	g._prop("v18_interior_floor_lamp", Vector3(-4.6, 0, 8.2))
	g._prop("v18_special_specimen_tank", Vector3(1.2, 0, 6.0))
	# 气象站陈设（interior_pack 144 件）。约束：Z 形三段，**B 段是唯一的转折通道**，
	# 只在中段（x -1~4）留出一条直路；A 段的观测台面抬高了 0.16 米，
	# 摆在上面的仪器要一起抬（y=0.16），不然会陷进台面里。
	InteriorProps.place(g, "lab_10", Vector3(-5.6, 0, -2.0), 180)       # 实验控制双屏台（A 段前带）
	InteriorProps.place(g, "lab_03", Vector3(-8.4, 0.16, -2.0), 180)    # 双目光学显微镜（台面上）
	InteriorProps.place(g, "lab_09", Vector3(-7.4, 0.16, -2.0), 180)    # PCR热循环仪（台面上）
	InteriorProps.place(g, "utility_06", Vector3(1.6, 0.16, -2.2), 0)   # 圆柱空气净化器（A 段东端）
	# 圆桌 + 两把椅子放 **C 段**（观测休整区）。
	# 原来放在 B 段 (0.6,1.0)：B 是 Z 形的转折通道、A→C 唯一的走法，占不得 ——
	# 通行带扫描把 (0.6,1.0) 判成被圆桌挡住，就是这条改的。
	InteriorProps.place(g, "lounge_04", Vector3(4.0, 0, 7.8), 0)        # 圆形会议桌（C 段）· 原 (5.2,7.6) 与两把椅子把 C 段东端整块封死
	InteriorProps.place(g, "lounge_01", Vector3(4.0, 0, 6.4), 0)        # 软垫餐椅 A
	InteriorProps.place(g, "lounge_01", Vector3(4.0, 0, 9.2), 180)      # 软垫餐椅 B
	InteriorProps.place(g, "lab_12", Vector3(-3.8, 0, 7.0), 0)          # 实验器材推车（C 段）
	_sign(g, "山地气象站 · Z 形平面", Vector3(-3.0, 3.2, -6.5), 32, Color("eefaf2"))
	return {"bounds": size, "spawn": Vector3(-1.5, 0, -4.5), "camera_size": 34.0,
		"zones": [_zone("a", "仪器存放段", Rect2(-9.0, -6.0, 12.0, 5.0)),
			_zone("b", "转折值班段", Rect2(-1.0, -1.0, 5.0, 6.0)),
			_zone("c", "观测休整段", Rect2(-4.0, 5.0, 12.0, 5.0))]}

# ---------------------------------------------------------------- 中央枢纽站（十字形）

## 平面是个「十」字：9×9 中央大厅，四边各接一条 6~7 米的翼。
## 和 T 形的区别是**有四个方向**——站在大厅里能同时看到四个开口，
## 选哪个先走是个真实的选择；T 形只有一条支廊，没有这个分叉。
static func _hub(g) -> Dictionary:
	var center := Rect2(-4.5, -4.5, 9.0, 9.0)
	var north := Rect2(-3.0, -10.5, 6.0, 6.0)
	var south := Rect2(-3.0, 4.5, 6.0, 6.0)
	var west := Rect2(-11.5, -3.0, 7.0, 6.0)
	var east := Rect2(4.5, -3.0, 7.0, 6.0)
	var size := _shell_shaped(g, [center, north, south, west, east], Color("6a6f76"), Color("9ba3a9"), Color("f2f6fa"))
	var b = g._builder(g.shell)
	# 大厅中心：一块圆形导向地贴（用方形叠出来，像素风格不追求真圆）
	b.box(Vector3(5.6, .02, 5.6), Vector3(0, .05, 0), Color("8d949a"))
	b.box(Vector3(4.0, .02, 4.0), Vector3(0, .055, 0), Color("b6bcc0"))
	# 北翼：货运交接
	_container(g, "harbor_cargo_cage", Vector3(-1.6, 0, -8.6), 0)
	_container(g, "long_equipment_case", Vector3(1.4, 0, -8.6), 0)
	_container(g, "port_manifest_drawer", Vector3(2.6, 0, -6.2), -90)
	# 南翼：旅客寄存
	for x in [-1.9, -.6, .7, 2.0]:
		_container(g, "secure_equipment_locker", Vector3(x, 0, 8.4), 180)
	# 西翼：查验
	_container(g, "reinforced_flight_case", Vector3(-9.8, 0, -1.4), 90)
	_container(g, "marine_waterproof_case", Vector3(-9.8, 0, .2), 90)
	_container(g, "field_supply_crate", Vector3(-7.0, 0, 1.4), 0)
	# 东翼：单证与现金
	_container(g, "searchable_file_cabinet", Vector3(9.8, 0, -1.4), -90)
	_container(g, "office_armored_safe", Vector3(9.8, 0, .4), -90)
	_container(g, "currency_transport_case", Vector3(6.8, 0, 1.4), 0)
	# 大厅四角：导向牌与座椅
	for spec in [[-3.6, -3.6, 135.0], [3.6, -3.6, -135.0], [-3.6, 3.6, 45.0], [3.6, 3.6, -45.0]]:
		_prop(g, "chair", Vector3(spec[0], 0, spec[1]), spec[2])
	_prop(g, "notice_board", Vector3(0, 0, 3.9), 180)
	_prop(g, "terminal", Vector3(-2.4, 0, 3.4), 200)
	_prop(g, "trash_bin", Vector3(2.6, 0, 3.4))
	# 枢纽站陈设。约束：中央大厅是十字路口，**一件都不放**（只留地上的导向地贴），
	# 全部摆进四条翼里，每条翼都留出能过人的缺口。
	InteriorProps.place(g, "logistics_10", Vector3(-2.2, 0, -7.0), 0)     # 智能物流转运柜（北翼）
	InteriorProps.place(g, "retail_10", Vector3(1.0, 0, -7.0), 0)         # 自助售货机（北翼）
	InteriorProps.place(g, "lounge_02", Vector3(-1.0, 0, 6.6), 180)       # 三席等候椅（南翼）
	InteriorProps.place(g, "utility_07", Vector3(2.2, 0, 6.4), 180)       # 冷热饮水机（南翼）
	InteriorProps.place(g, "retail_11", Vector3(-8.3, 0, -2.2), 0)        # 四格快递取件柜（西翼）
	InteriorProps.place(g, "decor_01", Vector3(-10.8, 0, 2.4), 0)         # 落地绿植（西翼）
	InteriorProps.place(g, "utility_12", Vector3(8.3, 0, -2.2), 0)        # 室内充电终端（东翼）
	InteriorProps.place(g, "decor_01", Vector3(10.8, 0, 2.4), 0)          # 落地绿植（东翼）
	_sign(g, "中央枢纽站 · 十字形（四个方向）", Vector3(0, 3.4, -10.9), 32, Color("f4f8fc"))
	return {"bounds": size, "spawn": Vector3(0, 0, 2.6), "camera_size": 42.0,
		"zones": [_zone("center", "中央大厅", Rect2(-4.5, -4.5, 9.0, 9.0)),
			_zone("north", "北翼货运", Rect2(-3.0, -10.5, 6.0, 6.0)),
			_zone("south", "南翼寄存", Rect2(-3.0, 4.5, 6.0, 6.0)),
			_zone("west", "西翼查验", Rect2(-11.5, -3.0, 7.0, 6.0)),
			_zone("east", "东翼单证", Rect2(4.5, -3.0, 7.0, 6.0))]}

# ---------------------------------------------------------------- 分区检疫所（矩形轮廓 + 室内隔断）

## 轮廓就是个矩形 —— 变化全在**里面**。
## 两道竖隔断 + 一道横隔断把大厅切成「两间检疫室 + 一间采样室 + 一条走廊」，
## 每道墙上只留一个 2.2 米的门洞。进去之后视线被墙截断，
## 必须走到门洞才知道隔壁有什么 —— 这是轮廓形状给不了的。
static func _quarantine(g) -> Dictionary:
	var size := Vector2(22.0, 14.0)
	var shell_size := _shell_shaped(g, [Rect2(-11.0, -7.0, 22.0, 14.0)],
		Color("6e757b"), Color("9fa7ac"), Color("f0f6f4"))
	var wall := Color("828b91")
	# 竖隔断：x=-4 把西侧切出一间（门洞开在南段 z=2.4）
	_partition(g, Vector2(-4.0, -7.0), Vector2(-4.0, 7.0), 2.4, 2.4, 2.2, wall)
	# 竖隔断：x=4 把东侧切出一间（门洞开在北段 z=-2.4）
	_partition(g, Vector2(4.0, -7.0), Vector2(4.0, 7.0), 2.4, -2.4, 2.2, wall)
	# 横隔断：z=0 把西侧那间再分成上下两间（门洞开在 x=-7.5）
	_partition(g, Vector2(-11.0, 0.0), Vector2(-4.0, 0.0), 2.4, -7.5, 2.2, wall)
	# 横隔断：z=2.6 在东侧隔出一条通道（门洞开在 x=7.5）
	_partition(g, Vector2(4.0, 2.6), Vector2(11.0, 2.6), 2.4, 7.5, 2.2, wall)
	var b = g._builder(g.shell)
	b.box(Vector3(6.2, .02, 13.2), Vector3(0, .05, 0), Color("8b9298"))
	# 西上间：采血与登记
	_container(g, "searchable_file_cabinet", Vector3(-9.6, 0, -5.6), 90)
	_container(g, "cold_chain_medical_cabinet", Vector3(-9.6, 0, -3.4), 90)
	_container(g, "wall_emergency_supply_cabinet", Vector3(-6.2, 0, -6.4), 0)
	_prop(g, "stainless_prep_table", Vector3(-7.4, 0, -2.2))
	# 西下间：留观
	_container(g, "field_medical_chest", Vector3(-9.6, 0, 2.4), 90)
	_container(g, "sample_transport_case", Vector3(-9.6, 0, 5.6), 90)
	_prop(g, "chair", Vector3(-6.0, 0, 4.6), -40)
	_prop(g, "supply_service_trolley", Vector3(-6.2, 0, 6.2), 0)
	# 中间走廊：直通南北
	_container(g, "laboratory_specimen_freezer", Vector3(-2.4, 0, -6.2), 0)
	_container(g, "battery_module_crate", Vector3(-1.2, 0, -6.2), 0)
	_prop(g, "notice_board", Vector3(.4, 0, -6.6), 0)
	# 东上间：样本处理
	_container(g, "server_service_cabinet", Vector3(9.6, 0, -5.6), -90)
	_container(g, "encrypted_electronics_case", Vector3(9.6, 0, -3.4), -90)
	_container(g, "cold_chain_medical_cabinet", Vector3(5.6, 0, -6.4), 0)
	_prop(g, "kitchen_sink_station", Vector3(7.4, 0, -1.4), 0)
	# 东下通道
	_container(g, "secure_equipment_locker", Vector3(9.6, 0, 5.4), -90)
	_prop(g, "trash_bin", Vector3(5.0, 0, 5.6))
	# 检疫所陈设（interior_pack 144 件）。约束：四道隔断把房间切成五间，
	# **中央走廊是南北主干，一件不放**；东西两间各自贴边，
	# 而且隔断上的门洞（x=-4 的 z=2.4、x=4 的 z=-2.4、z=0 的 x=-7.5、z=2.6 的 x=7.5）
	# 前面必须留空，否则进不去。
	InteriorProps.place(g, "medical_01", Vector3(-6.0, 0, -4.6), 0)     # 检查诊疗床（西上间）
	InteriorProps.place(g, "utility_03", Vector3(-8.7, 0, -6.2), 0)     # 镜面洗手台（西上间）
	InteriorProps.place(g, "medical_02", Vector3(-10.2, 0, -0.6), 90)   # 超声诊断推车（西上间）
	InteriorProps.place(g, "medical_12", Vector3(-6.0, 0, 3.4), 0)      # 三折医疗屏风（西下间）
	InteriorProps.place(g, "medical_07", Vector3(-8.4, 0, 6.0), 0)      # 医疗抽屉车（西下间）
	InteriorProps.place(g, "medical_06", Vector3(7.0, 0, -4.4), 0)      # 五灯手术照明架（东上间）
	InteriorProps.place(g, "lounge_02", Vector3(6.4, 0, 5.6), 180)      # 三席等候椅（东下通道）
	InteriorProps.place(g, "utility_10", Vector3(1.6, 0, 6.4), 0)       # 脚踏分类垃圾桶（走廊南端）
	_sign(g, "分区检疫所 · 矩形轮廓 + 室内隔断", Vector3(0, 3.2, -7.5), 30, Color("eef7f4"))
	return {"bounds": shell_size, "spawn": Vector3(0, 0, 4.4), "exit": Vector3(0, 0, 6.4), "camera_size": 38.0,
		"zones": [_zone("corridor", "中央走廊", Rect2(-4.0, -7.0, 8.0, 14.0)),
			_zone("w1", "西上·采血登记", Rect2(-11.0, -7.0, 7.0, 7.0)),
			_zone("w2", "西下·留观", Rect2(-11.0, 0.0, 7.0, 7.0)),
			_zone("e1", "东上·样本处理", Rect2(4.0, -7.0, 7.0, 9.6)),
			_zone("e2", "东下·通道", Rect2(4.0, 2.6, 7.0, 4.4))]}

# ---------------------------------------------------------------- 备件长库（梳形）

## 平面像一把梳子：一条 24×4 的长脊，两侧交替伸出 5×4 的凹龛。
## 长脊本身又长又直，但每走几米侧面就开一个龛 —— 一路都是「往里看一眼」的节奏，
## 和回字形（一直绕）、十字形（四向分叉）都不同。
static func _spares(g) -> Dictionary:
	var spine := Rect2(-12.0, -2.0, 24.0, 4.0)
	var teeth := [
		Rect2(-10.0, -6.0, 5.0, 4.0),   # 北侧
		Rect2(-3.0, 2.0, 5.0, 4.0),     # 南侧
		Rect2(4.0, -6.0, 5.0, 4.0),     # 北侧
		Rect2(8.0, 2.0, 5.0, 4.0),      # 南侧
	]
	var rects: Array = [spine]
	for t in teeth:
		rects.append(t)
	var size := _shell_shaped(g, rects, Color("5e666d"), Color("98a1a7"), Color("f4f8fb"))
	var b = g._builder(g.shell)
	# 长脊地面导引线
	b.box(Vector3(23.4, .02, .12), Vector3(0, .052, 0), Color("c9b072"))
	# 长脊：每隔几米一台设备
	_container(g, "battery_module_crate", Vector3(-11.0, 0, -1.0), 0)
	_container(g, "encrypted_electronics_case", Vector3(-8.4, 0, -1.0), 0)
	_container(g, "sample_transport_case", Vector3(-5.6, 0, -1.0), 0)
	_container(g, "long_equipment_case", Vector3(-1.6, 0, -1.0), 0)
	_container(g, "rolling_logistics_case", Vector3(2.4, 0, -1.0), 0)
	_container(g, "industrial_tool_chest", Vector3(5.6, 0, -1.0), 0)
	_container(g, "reinforced_flight_case", Vector3(9.4, 0, -1.0), 0)
	# 四个龛：两两成对，主题不同
	_container(g, "laboratory_specimen_freezer", Vector3(-8.2, 0, -4.6), 0)
	_container(g, "cold_chain_medical_cabinet", Vector3(-6.4, 0, -4.6), 0)
	_container(g, "secure_equipment_locker", Vector3(-1.2, 0, 4.6), 180)
	_container(g, "office_armored_safe", Vector3(.6, 0, 4.6), 180)
	_container(g, "marine_waterproof_case", Vector3(5.8, 0, -4.6), 0)
	_container(g, "field_supply_crate", Vector3(7.4, 0, -4.6), 0)
	_container(g, "currency_transport_case", Vector3(9.8, 0, 4.6), 180)
	_container(g, "port_manifest_drawer", Vector3(11.4, 0, 4.6), 180)
	_prop(g, "port_plastic_pallet", Vector3(-3.4, 0, 1.0))
	_prop(g, "compact_pallet_jack", Vector3(-1.6, 0, 1.2), 4)
	_prop(g, "terminal", Vector3(7.4, 0, 1.0), 180)
	# 出生点净空：出生点 (-11, 1.4) 正西 0.4m 曾被信息牌堵死，长脊西端出不去。
	# 挪到北侧龛的墙上（x=-7.5，贴 n1 龛的东壁），远离长脊的西端头。
	_prop(g, "notice_board", Vector3(-7.5, 0, -1.4), 0)
	# 备件长库陈设（interior_pack 144 件）。约束：24 米长脊是唯一通道，
	# 货架一律摆**南半幅**（z=1.3），北半幅留出 1.35 米的通行带 ——
	# 这一排设备本来就压在 z=-1.0 那条线上。
	InteriorProps.place(g, "logistics_01", Vector3(-6.8, 0, 1.3), 0)    # 三层重型仓储架
	InteriorProps.place(g, "logistics_01", Vector3(0.4, 0, 1.3), 0)     # 三层重型仓储架
	InteriorProps.place(g, "logistics_01", Vector3(4.8, 0, 1.3), 0)     # 三层重型仓储架
	InteriorProps.place(g, "logistics_08", Vector3(11.0, 0, 1.3), 0)    # 带台钳维修工作台（长脊东端）
	InteriorProps.place(g, "logistics_07", Vector3(-9.6, 0, -1.85), 0)  # 壁挂工具整理板（贴北墙）
	InteriorProps.place(g, "logistics_12", Vector3(2.0, 0, -1.9), 0)    # 防护网工业风扇（贴北墙）
	InteriorProps.place(g, "storage_05", Vector3(6.0, 0, -2.8), 180)    # 六格更衣柜（北龛二前带）
	InteriorProps.place(g, "logistics_06", Vector3(-11.9, 0, -1.8), 90) # 落地灭火器（长脊西端·贴北墙）
	_sign(g, "备件长库 · 梳形（长脊 + 侧龛）", Vector3(0, 3.0, -2.6), 30, Color("f2f7fb"))
	return {"bounds": size, "spawn": Vector3(-10.0, 0, 0.5), "camera_size": 38.0,
		"zones": [_zone("spine", "长脊通道", Rect2(-12.0, -2.0, 24.0, 4.0)),
			_zone("n1", "北龛一", Rect2(-10.0, -6.0, 5.0, 4.0)),
			_zone("n2", "北龛二", Rect2(4.0, -6.0, 5.0, 4.0)),
			_zone("s1", "南龛一", Rect2(-3.0, 2.0, 5.0, 4.0)),
			_zone("s2", "南龛二", Rect2(8.0, 2.0, 5.0, 4.0))]}

# ---------------------------------------------------------------- 中央枢纽站 end

# ---------------------------------------------------------------- 港湾补给仓 · 2F 环形挑廊

## 「多层」在这台工程里的正确做法。
##
## 人物被锁在 y=0：room_3d.gd 里 player.motion_mode 是 MOTION_MODE_FLOATING，
## 而且每帧 `player.position.y=0`（实测从 y=4 扔下去，6 帧里 y 一直是 0）。
## 所有房间的地面还只有视觉 PlaneMesh、没有碰撞体 —— 改成重力模式会让每个地点都掉出世界。
## 所以可行走的多层 / 夹层做不了，工程自己的楼层也是这么解决的：
## **楼层＝独立地点 + 楼梯传送**（apt_1/2/3、inn_1/2/3、obs_1/2/3 都是）。
##
## 这一层因此不是「抬高的地板」而是「另一张地图」：
## 脚下仍然是 y=0，中间那口井往下挖到 y=-3.2 —— 一眼能看到一层货区的箱子和地面。
## 用井的深度表达高度差，用栏杆和桁架表达层次，而不是去动移动系统。
static func _gallery(g) -> Dictionary:
	var size := Vector2(20.0, 14.0)
	var b = g._builder(g.shell)
	var well := Rect2(-5.0, -3.5, 10.0, 7.0)
	var ring: Array = [
		Rect2(-10.0, -7.0, 20.0, 3.5), Rect2(-10.0, 3.5, 20.0, 3.5),
		Rect2(-10.0, -3.5, 5.0, 7.0), Rect2(5.0, -3.5, 5.0, 7.0)]
	var base := Color("6b7078")
	var tint := Color("9aa2a8")
	for r in ring:
		var c := Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.5)
		b.box(Vector3(r.size.x, .30, r.size.y), Vector3(c.x, -.16, c.y), base)
		b.box(Vector3(r.size.x, .05, r.size.y), Vector3(c.x, .003, c.y), tint)
	# 外沿整墙 / 半高 / 矮墙，沿用其它房间的剖面读法
	b.box(Vector3(size.x, 3.2, .22), Vector3(0, 1.6, -7.0), base.lightened(.10))
	g._collision(g.shell, Vector3(size.x, 3.2, .22), Vector3(0, 1.6, -7.0))
	for side in [-1.0, 1.0]:
		b.box(Vector3(.22, 1.25, size.y), Vector3(side * 10.0, .62, 0), base.lightened(.05))
		g._collision(g.shell, Vector3(.22, 1.25, size.y), Vector3(side * 10.0, .62, 0))
	b.box(Vector3(size.x, .95, .22), Vector3(0, .47, 7.0), base.lightened(.04))
	g._collision(g.shell, Vector3(size.x, .95, .22), Vector3(0, .47, 7.0))
	# 井口栏杆：立柱 + 压顶。**不做整墙** —— 挑廊的重点就是能往下看
	var rail := Color("4f6470")
	var top := Color("c8d2d6")
	for seg in [[Vector2(-5, -3.5), Vector2(5, -3.5)], [Vector2(-5, 3.5), Vector2(5, 3.5)],
			[Vector2(-5, -3.5), Vector2(-5, 3.5)], [Vector2(5, -3.5), Vector2(5, 3.5)]]:
		var a: Vector2 = seg[0]
		var c2: Vector2 = seg[1]
		var length := a.distance_to(c2)
		var steps := maxi(2, int(length / 1.05))
		for i in steps + 1:
			var p := a.lerp(c2, float(i) / float(steps))
			b.box(Vector3(.07, .92, .07), Vector3(p.x, .46, p.y), rail)
		var mid := (a + c2) * 0.5
		var span := Vector3(length + .10, .08, .10) if absf(a.y - c2.y) < 0.01 else Vector3(.10, .08, length + .10)
		b.box(span, Vector3(mid.x, .96, mid.y), top)
		# 栏杆要挡住人（挑廊上掉不下去）
		var solid := Vector3(length, .96, .16) if absf(a.y - c2.y) < 0.01 else Vector3(.16, .96, length)
		g._collision(g.shell, solid, Vector3(mid.x, .48, mid.y))
	# 井底：一层的货区。地面和箱子都在 y=-3.2，从栏杆往下看就是「楼下」
	var depth := -3.2
	b.box(Vector3(well.size.x, .30, well.size.y), Vector3(0, depth - .15, 0), Color("5b6169"))
	b.box(Vector3(well.size.x, .05, well.size.y), Vector3(0, depth + .003, 0), Color("8d959b"))
	for spec in [[-3.2, -1.8, 0.0], [-1.0, -2.2, 20.0], [2.4, -1.2, -15.0], [3.4, 1.6, 8.0], [-2.6, 2.0, -10.0]]:
		_pack_in(g, PROP_DIR, "wood_crate", Vector3(spec[0], depth, spec[1]), float(spec[2]))
	_pack_in(g, PROP_DIR, "barrel", Vector3(.6, depth, .4))
	# 屋顶桁架：跨过整个挑空，上面挂灯 —— 有它才读得出「这是高处」
	for x in range(-8, 9, 4):
		b.box(Vector3(.16, .16, 14.0), Vector3(float(x), 4.3, 0), Color("55636b"))
	b.box(Vector3(19.6, .18, .20), Vector3(0, 4.42, -3.4), Color("55636b"))
	b.box(Vector3(19.6, .18, .20), Vector3(0, 4.42, 3.4), Color("55636b"))
	for x in [-6.0, 0.0, 6.0]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(x, 3.7, 0)
		lamp.light_color = Color("e8f4f8")
		lamp.light_energy = .75
		lamp.omni_range = 10.0
		g.shell.add_child(lamp)
	# 下来/上去的楼梯（走上去就是回一层），以及挑廊上的存货
	_stairs(g, b, Vector3(-8.4, 0, 5.0), true)
	_container(g, "secure_equipment_locker", Vector3(-9.2, 0, -5.6), 0)
	_container(g, "field_supply_crate", Vector3(-7.6, 0, -5.6), 0)
	_container(g, "long_equipment_case", Vector3(8.6, 0, -5.4), 180)
	_container(g, "reinforced_flight_case", Vector3(8.6, 0, 3.9), 180)
	_container(g, "searchable_file_cabinet", Vector3(-9.3, 0, -1.6), 90)
	_container(g, "battery_module_crate", Vector3(-9.3, 0, .4), 90)
	_pack_in(g, PROP_DIR, "supply_service_trolley", Vector3(7.0, 0, .6), -6)
	_pack_in(g, PROP_DIR, "port_plastic_pallet", Vector3(-7.4, 0, 1.4))
	# 2F 挑廊陈设。约束：挑廊是**环廊**（北/南/西/东四条带），
	# 贴井口的栏杆两侧必须留出走道 —— 所以贴墙件都放**外沿**（z=±6.8），
	# 而放「栏杆边」的东西要摆在环廊**内侧**（x=±5.4），不能越过栏杆悬到井上。
	InteriorProps.place(g, "logistics_07", Vector3(0.0, 0, -6.85), 0)    # 壁挂工具整理板（北外沿）
	InteriorProps.place(g, "logistics_01", Vector3(2.2, 0, -6.4), 0)    # 三层重型仓储架（北外沿东）
	InteriorProps.place(g, "logistics_01", Vector3(-2.4, 0, -6.4), 0)   # 三层重型仓储架（北外沿西）
	InteriorProps.place(g, "decor_06", Vector3(7.0, 0, -6.85), 180)     # 蓝鲸装饰画（北外沿里端）
	InteriorProps.place(g, "medical_08", Vector3(5.6, 0, -6.8), 180)    # 壁挂急救药箱（东北角）
	InteriorProps.place(g, "logistics_06", Vector3(-5.6, 0, -6.8), 180) # 落地灭火器（西北角）
	InteriorProps.place(g, "lounge_02", Vector3(0.0, 0, 6.2), 180)      # 三席等候椅（南外沿）
	InteriorProps.place(g, "retail_11", Vector3(5.4, 0, 1.0), -90)      # 四格快递取件柜（东侧·栏杆边）
	InteriorProps.place(g, "architecture_11", Vector3(-5.4, 0, 1.0), 90) # 嵌墙电气控制柜（西侧·栏杆边）
	_sign(g, "港湾补给仓 · 2F 环形挑廊 · 楼梯下行", Vector3(0, 3.3, -7.4), 30, Color("eef6ff"))
	return {"bounds": size, "spawn": Vector3(-7.4, 0, -0.5), "camera_size": 34.0,
		"zones": [_zone("north", "北侧挑廊", Rect2(-10.0, -7.0, 20.0, 3.5)),
			_zone("south", "南侧挑廊", Rect2(-10.0, 3.5, 20.0, 3.5)),
			_zone("west", "西侧挑廊", Rect2(-10.0, -3.5, 5.0, 7.0)),
			_zone("east", "东侧挑廊", Rect2(5.0, -3.5, 5.0, 7.0)),
			_zone("well", "挑空井（一层货区）", Rect2(-5.0, -3.5, 10.0, 7.0))]}

## 一段楼梯。往上是装饰（人物上不去），往下是通往一层的传送点。
static func _stairs(g, b, at: Vector3, descending: bool) -> void:
	var steps := 7
	for i in steps:
		var y := .16 + float(i) * .30
		var z := -float(i) * .42
		var span := Vector3(1.9, .30, .48)
		var center := at + Vector3(0, y, z)
		b.box(span, center, Color("8f979c"))
		g._collision(g.shell, span, center)
	b.box(Vector3(2.2, .10, 3.2), at + Vector3(0, 2.28, -1.5), Color("c8d2d6"))

# ---------------------------------------------------------------- 保险库（L 形）

## 平面是一把 L：主库房 11×9，东翼 6×4.5 接在右上角，
## 右下角那 6×4.5 是**空的**（不是房间）—— 进门看不到东翼，要绕过拐角。
static func _vault(g) -> Dictionary:
	var hall := Rect2(-8.0, -4.5, 11.0, 9.0)
	var wing := Rect2(3.0, -4.5, 6.0, 4.5)
	var size := _shell_shaped(g, [hall, wing], Color("6f6a62"), Color("a89c88"), Color("f4e6c8"))
	var b = g._builder(g.shell)
	# 金库地坪标高 + 中央过道
	b.box(Vector3(10.4, .03, 8.2), Vector3(-2.6, .052, 0), Color("8a8478"))
	# 主库房：保险柜沿后墙与左墙排开
	_container(g, "office_armored_safe", Vector3(-6.6, 0, -3.6), 0)
	_container(g, "office_armored_safe", Vector3(-5.4, 0, -3.6), 0)
	_container(g, "wall_data_safe", Vector3(-4.2, 0, -3.8), 0)
	_container(g, "searchable_file_cabinet", Vector3(-2.6, 0, -3.7), 0)
	_container(g, "currency_transport_case", Vector3(-1.0, 0, -3.7), 0)
	# 注意：token_currency_counter 是**道具**不是容器（它在 models/props/，
	# 不在 container_specs.json 的 30 种里）。第一版我用 _container() 放它，
	# 结果场上站着一个永远打不开的柜子 —— _container 的 spec 会查空。
	_prop(g, "token_currency_counter", Vector3(5.2, 0, -3.6))
	_container(g, "secure_equipment_locker", Vector3(-7.2, 0, 1.2), 90)
	_container(g, "restaurant_cash_drop_safe", Vector3(-7.2, 0, 2.6), 90)
	# 中央岛台：点钞与清点
	_container(g, "encrypted_electronics_case", Vector3(-2.2, 0, .8), 12)
	_container(g, "battery_module_crate", Vector3(-.4, 0, 1.4), -8)
	_prop(g, "table_round", Vector3(-0.6, 0, 2.6))
	_prop(g, "chair", Vector3(0.5, 0, 2.6), -70)
	_prop(g, "notice_board", Vector3(.6, 0, 4.9), 180)
	_prop(g, "trash_bin", Vector3(-7.0, 0, 3.6))
	# 保险库陈设（interior_pack 144 件）。约束：主库房 11×9 的中央走道要通，
	# 东翼（x 3~9, z -4.5~0）是 L 的另一笔，两笔交汇处不能被堵。
	# **出生点净空**：出生点 (-3, 3.6) 南侧 0.2m 曾被 safes_12 堵死，向南一步都迈不出。
	# 挪到西南角（x=-6.6），远离出生轴。
	InteriorProps.place(g, "safes_06", Vector3(1.6, 0, -3.6), 0)        # 双门保险柜（后墙右段）
	InteriorProps.place(g, "safes_05", Vector3(2.85, 0, 2.4), -90)      # 加固高保险柜（东墙南段）
	InteriorProps.place(g, "retail_01", Vector3(5.4, 0, -1.4), 180)     # 传送带收银台 → 清点台（东翼）
	InteriorProps.place(g, "retail_09", Vector3(8.0, 0, -3.4), 0)       # 服务台与呼叫铃（东翼里端）
	InteriorProps.place(g, "safes_03", Vector3(-6.0, 0, 3.8), 180)      # 文件抽屉保险盒（南墙西段）
	InteriorProps.place(g, "safes_12", Vector3(-6.6, 0, 3.9), 180)      # 翻盖贵重物品盒（南墙·远离出生点）
	InteriorProps.place(g, "architecture_11", Vector3(-7.6, 0, -1.5), 90) # 嵌墙电气控制柜（西墙）
	InteriorProps.place(g, "lounge_02", Vector3(1.8, 0, 3.0), 180)      # 三席等候椅
	_sign(g, "港湾保险库 · L 形平面", Vector3(-2.6, 3.2, -5.1), 32, Color("f6ecd2"))
	return {"bounds": size, "spawn": Vector3(-3.0, 0, 3.6), "exit": Vector3(0, 0, 4.0), "camera_size": 28.0,
		"zones": [_zone("main", "主库房", Rect2(-8.0, -4.5, 11.0, 9.0)),
			_zone("wing", "东翼点钞室", Rect2(3.0, -4.5, 6.0, 4.5))]}

# ---------------------------------------------------------------- 地下实验区（U 形 + 中庭）

## 平面是个 U：北楼 14×4.5，东西两翼各 4×7.5，中间 6×7.5 是**中庭（空的）**，
## 中庭朝南敞开。三面走廊围着它 —— 这是方盒子做不到的空间关系。
static func _lab(g) -> Dictionary:
	var north := Rect2(-7.0, -6.0, 14.0, 4.5)
	var west := Rect2(-7.0, -1.5, 4.0, 7.5)
	var east := Rect2(3.0, -1.5, 4.0, 7.5)
	var size := _shell_shaped(g, [north, west, east], Color("64707a"), Color("93a4ad"), Color("dcf2ff"))
	var b = g._builder(g.shell)
	# 中庭：一块压低的下沉地坪 + 围栏，明确「这不是可走的房间」
	b.box(Vector3(6.4, .10, 7.9), Vector3(0, -.02, 2.25), Color("5d6a70"))
	_prop(g, "planter", Vector3(-2.2, 0, -.6))
	_prop(g, "planter", Vector3(2.2, 0, -.6))
	_prop(g, "palm", Vector3(0, 0, 4.6))
	_prop(g, "rocks", Vector3(-1.6, 0, 1.0))
	_prop(g, "rocks", Vector3(1.7, 0, 1.9), 40)
	# 北楼：样本与冷链
	_container(g, "laboratory_specimen_freezer", Vector3(-5.4, 0, -4.6), 0)
	_container(g, "sample_transport_case", Vector3(-4.1, 0, -4.6), 0)
	_container(g, "cold_chain_medical_cabinet", Vector3(-2.8, 0, -4.6), 0)
	_container(g, "server_service_cabinet", Vector3(1.0, 0, -4.6), 0)
	_container(g, "encrypted_electronics_case", Vector3(2.3, 0, -4.6), 0)
	# 同上：relay_service_terminal 是道具（港务设备终端），不是可开合容器
	_prop(g, "relay_service_terminal", Vector3(3.7, 0, -4.6))
	# 西翼：医疗与样本
	_container(g, "wall_emergency_supply_cabinet", Vector3(-5.6, 0, -.6), 90)
	_container(g, "field_medical_chest", Vector3(-5.6, 0, 1.0), 90)
	_container(g, "cold_chain_medical_cabinet", Vector3(-5.4, 0, 3.9), 0)
	# 东翼：设备维护
	_container(g, "server_service_cabinet", Vector3(5.6, 0, -.6), -90)
	_container(g, "battery_module_crate", Vector3(5.6, 0, 1.2), -90)
	_container(g, "secure_equipment_locker", Vector3(5.6, 0, 3.4), -90)
	_prop(g, "stainless_prep_table", Vector3(-2.6, 0, 3.2))
	_prop(g, "supply_service_trolley", Vector3(4.2, 0, 4.4), 8)
	_prop(g, "terminal", Vector3(1.2, 0, -.8), 180)
	# 仪器设备（interior_pack 的 144 件室内模型：真实尺寸、包装场景自带碰撞）。
	# 摆法上专门留了空档：北楼是连接东西两翼的**通道**，
	# 沿前带排一列但中间留两处 1.5 米以上的缺口，否则动线被堵死。
	var bench: Array = ["lab_01", "lab_10", "lab_06", "lab_07", "lab_08", "lab_12", "lab_03"]
	var bench_x: Array = [-5.6, -2.4, 0.4, 2.0, 3.2, 4.6, 5.8]
	for i in bench.size():
		InteriorProps.place(g, bench[i], Vector3(bench_x[i], 0, -2.3), 180)
	# 两翼尽端各摆两件，中间过道留空。
	# 位置是按 AABB 复核过的，挪了两次才对：
	#   轮椅 (-6.1, 4.0) → 压冷链保存柜 0.16 m³
	#   轮椅 (-3.8, 3.0) → 压不锈钢备餐台 0.08 m³
	#   现在 (-6.4, 5.2)：西翼南端的空地，两侧都够
	#   抽屉车 (4.5, 4.9) → 压补给推车 0.14 m³，现在 (3.6, 5.2)
	InteriorProps.place(g, "medical_02", Vector3(-3.6, 0, 5.5), 180)
	InteriorProps.place(g, "medical_11", Vector3(-6.4, 0, 5.2), 0)
	InteriorProps.place(g, "medical_07", Vector3(3.6, 0, 5.2), 180)
	InteriorProps.place(g, "medical_10", Vector3(5.8, 0, 4.9), 180)
	_sign(g, "地下实验区 · U 形中庭", Vector3(0, 3.2, -7.1), 32, Color("e6f6ff"))
	return {"bounds": size, "spawn": Vector3(-5.5, 0, 2.5), "exit": Vector3(-5.0, 0, 5.6), "camera_size": 30.0,
		"zones": [_zone("north", "北楼样本库", Rect2(-7.0, -6.0, 14.0, 4.5)),
			_zone("west", "西翼医疗间", Rect2(-7.0, -1.5, 4.0, 7.5)),
			_zone("east", "东翼设备间", Rect2(3.0, -1.5, 4.0, 7.5)),
			_zone("court", "中央中庭", Rect2(-3.0, -1.5, 6.0, 7.5))]}

# ---------------------------------------------------------------- 潮间带（室外，没有盒子）

## 这里**不是房间**：没有围墙，只有一道海堤、一片斜坡沙滩、一条木栈桥和一座灯塔。
## 涨落潮是同一片滩的两个状态 —— 落潮时水位退下去，礁石和贝壳露出来可走；
## 涨潮时水漫上来，能走的只剩堤顶和栈桥。两张地图共用同一套布局。
static func _tidal(g, high: bool) -> Dictionary:
	var size := Vector2(28.0, 21.0)
	var b = g._builder(g.shell)
	# 滩体：北高南低，靠海堤那头是干的，往南入水
	b.box(Vector3(size.x, .22, size.y), Vector3(0, -.12, 0), Color("c2ab84"))
	b.box(Vector3(size.x - .4, .04, size.y - .4), Vector3(0, .004, 0), Color("d8c199"))
	# 海堤（北端，整段自己搭 —— 包里的 harbor_seawall 是单节，拼接会有缝）
	var wall_z := -size.y * 0.5 + 1.2
	b.box(Vector3(size.x - 2.0, 1.30, 1.10), Vector3(0, .65, wall_z), Color("8b98a0"))
	b.box(Vector3(size.x - 1.6, .16, 1.30), Vector3(0, 1.38, wall_z), Color("d5dde1"))
	g._collision(g.shell, Vector3(size.x - 2.0, 1.30, 1.10), Vector3(0, .65, wall_z))
	# 堤上的栏杆
	for x in range(-12, 13, 2):
		b.box(Vector3(.07, .85, .07), Vector3(float(x), 1.90, wall_z - .55), Color("4f6470"))
	b.box(Vector3(size.x - 2.0, .07, .07), Vector3(0, 2.32, wall_z - .55), Color("4f6470"))
	# 斜坡沙滩：往南一路降到水下
	for i in 5:
		var t := float(i) / 4.0
		var z: float = -1.2 + t * 9.0
		var y: float = -.06 - t * .55
		b.box(Vector3(size.x - 3.0, .10, 2.0), Vector3(0, y, z), Color("cdb891").lerp(Color("a89272"), t))
	# 水位：涨潮高、落潮低。水面用包里的 water_surface 量了再铺开
	var water_y: float = (0.02 if high else -0.40)
	var water = _pack_fit(g, TIDAL_DIR, "water_surface", Vector3(0, water_y, 6.4), Vector2(size.x + 17.0, 15.5))
	if water != null:
		water.set_meta("water", true)
	# 礁石：落潮时露得多、涨潮时只剩顶上一点
	for spec in [[-6.4, 3.2, 0.0], [-2.0, 5.6, 25.0], [3.4, 2.4, -18.0], [7.6, 5.0, 12.0], [-9.2, 6.4, 0.0]]:
		var rock = _pack_in(g, TIDAL_DIR, "intertidal_rocks",
			Vector3(spec[0], water_y - (0.28 if high else 0.02), spec[1]), float(spec[2]))
		if rock != null and not high:
			rock.scale = Vector3(1.15, 1.0, 1.15)
	_pack_in(g, TIDAL_DIR, "seaweed_patch", Vector3(-4.6, water_y - .06, 7.8), 20)
	_pack_in(g, TIDAL_DIR, "seaweed_patch", Vector3(5.2, water_y - .06, 8.8), -30)
	_pack_in(g, TIDAL_DIR, "shell_cluster", Vector3(1.2, water_y + (0.02 if high else 0.06), 3.2), 0)
	_pack_in(g, TIDAL_DIR, "driftwood", Vector3(-7.4, .06, -.4), 22)
	_pack_in(g, TIDAL_DIR, "floating_buoy", Vector3(9.6, water_y + .02, 7.4), 0)
	_pack_in(g, TIDAL_DIR, "tide_gauge", Vector3(-10.6, 0, wall_z + 1.0), 0)
	# 木栈桥：从堤顶伸进海里
	var pier = _pack_in(g, BUILDING_DIR, "wooden_pier", Vector3(2.6, .30, 6.4), 0)
	if pier != null:
		pier.scale = Vector3(1.0, 1.0, 1.55)
	# 灯塔：立在东侧一小块岬角上
	b.box(Vector3(5.0, .40, 5.0), Vector3(9.6, .18, -6.4), Color("8f9a9e"))
	_pack_in(g, BUILDING_DIR, "lighthouse", Vector3(9.6, .38, -6.4), 0)
	_pack_in(g, BUILDING_DIR, "lifeguard_tower", Vector3(-8.2, .06, -3.6), 12)
	_pack_in(g, PROP_DIR, "beach_umbrella", Vector3(-4.2, .06, -.2), 0)
	_pack_in(g, PROP_DIR, "sun_lounger", Vector3(-5.4, .06, .9), -14)
	_pack_in(g, PROP_DIR, "sun_lounger", Vector3(-3.4, .06, 1.0), -14)
	_pack_in(g, PROP_DIR, "beach_sign", Vector3(6.2, .06, -2.4), -20)
	_pack_in(g, PROP_DIR, "bollard", Vector3(-12.0, .06, 1.4), 0)
	# 潮间带陈设。**室外**：144 件里大多是室内的（床、钢琴、货架都不合适），
	# 能用的只有耐户外的少数 —— 等候椅、垃圾桶、信息立牌、木托盘、灭火器、手推车，
	# 加一尊鲸鱼摆件立在灯塔岬角上。两张潮位图共用这批陈设（本来就是同一片滩）。
	InteriorProps.place(g, "lounge_02", Vector3(-2.6, .06, -8.4), 180)  # 三席等候椅（堤上步道·面海）
	InteriorProps.place(g, "utility_10", Vector3(1.6, .06, -8.3), 180)  # 脚踏分类垃圾桶
	InteriorProps.place(g, "decor_12", Vector3(4.6, .06, -8.2), 180)    # 透明信息立牌
	_container(g, "lifesaving_deck_box", Vector3(-6.5, .06, -8.3), 180)  # 救生甲板储物箱（西侧海堤步道）
	InteriorProps.place(g, "logistics_02", Vector3(-1.2, .06, -2.6), 0) # 木质货物托盘（滩上）
	InteriorProps.place(g, "logistics_06", Vector3(-7.0, .06, -2.6), 0) # 落地灭火器（救生塔旁）
	InteriorProps.place(g, "logistics_04", Vector3(5.0, .06, -4.4), 180) # 双层运货手推车
	InteriorProps.place(g, "decor_10", Vector3(7.6, .40, -4.4), -90)    # 大肥鱼鲸鱼摆件（岬角上）
	# 栈桥上的货物。高度 0.70 是**射线量出来的甲板面**，不是栈桥 AABB 的顶面 ——
	# 那个是 1.46，属于**栏杆顶**，照它摆会把箱子放上栏杆。
	# （量法：从 y=4 向下打 PhysicsRayQuery，命中 wooden_pier/Body 于 y=0.70。
	#   甲板视觉范围 z 3.07~9.73、宽仅 1.85 米，所以只放窄件，
	#   等候椅转 90° 让它**顺桥**而不是横桥，否则过不去。）
	InteriorProps.place(g, "logistics_05", Vector3(2.2, .70, 4.4), 0)    # 翻盖加固运输箱（桥头）
	InteriorProps.place(g, "logistics_02", Vector3(2.6, .70, 5.8), 0)    # 木质货物托盘
	InteriorProps.place(g, "logistics_05", Vector3(2.95, .70, 7.0), 180) # 翻盖加固运输箱（桥中）
	InteriorProps.place(g, "logistics_06", Vector3(2.0, .70, 8.2), 0)    # 落地灭火器（贴西侧）
	InteriorProps.place(g, "lounge_02", Vector3(2.6, .70, 8.8), 90)      # 三席等候椅（顺桥摆）
	# 你可以走到堤上、栈桥上，也可以涉水走到礁石边
	_sign(g, "潮间带 · " + ("涨潮" if high else "落潮") + " · 按 E 可切换潮位",
		Vector3(0, 3.0, wall_z), 30, Color("eaf6ff"))
	return {"bounds": size, "spawn": Vector3(0, 0, wall_z + 1.6), "exit": Vector3(0, 0, wall_z + 3.6), "camera_size": 34.0,
		"zones": [_zone("seawall", "海堤", Rect2(-13.0, wall_z - .8, 26.0, 2.2)),
			_zone("flat", "潮间滩地", Rect2(-13.0, 1.4, 26.0, 6.4)),
			_zone("water", "近岸水域", Rect2(-13.0, 7.8, 26.0, 5.2)),
			_zone("spit", "灯塔岬角", Rect2(6.6, -9.0, 6.0, 5.2))]}

# ---------------------------------------------------------------- 港湾补给仓

static func _depot(g) -> Dictionary:
	var size := Vector2(17.0, 12.5)
	_shell(g, size, Color("7c8a92"), Color("95a5ad"), Color("dff0f6"))
	var b = g._builder(g.shell)
	# 中央通道：两侧堆货，中间留出走道 —— 物流仓库的读法
	b.box(Vector3(15.4, .02, 2.6), Vector3(0, .05, 0), Color("7d8b92"))
	for x in [-7.6, 7.6]:
		b.box(Vector3(.10, .02, 11.4), Vector3(x, .052, 0), Color("d8c98a"))
	# 后墙货笼（最重的放最里面），左右各一列
	_container(g, "harbor_cargo_cage", Vector3(-6.4, 0, -5.1), 0)
	_container(g, "maritime_signal_locker", Vector3(-4.9, 0, -5.2), 0)
	_container(g, "secure_equipment_locker", Vector3(-3.6, 0, -5.2), 0)
	_container(g, "reinforced_flight_case", Vector3(2.9, 0, -5.1), 0)
	_container(g, "field_supply_crate", Vector3(4.3, 0, -5.1), 0)
	# 侧墙：长条装备箱靠左，潜水加固箱靠右
	_container(g, "long_equipment_case", Vector3(-7.5, 0, -1.6), 90)
	_container(g, "diver_equipment_case", Vector3(7.5, 0, -1.4), -90)
	_container(g, "marine_waterproof_case", Vector3(7.4, 0, .4), -90)
	# 中央通道上两件：带轮运输箱与工具箱，玩家绕着走
	_container(g, "rolling_logistics_case", Vector3(-1.9, 0, .5), 18)
	_container(g, "industrial_tool_chest", Vector3(1.4, 0, .7), -14)
	# 配套道具（同一个包里的静态模型）
	_pack(g, "port_plastic_pallet", Vector3(-6.6, 0, 2.6))
	_pack(g, "port_plastic_pallet", Vector3(-6.6, .14, 2.6))
	_pack(g, "compact_pallet_jack", Vector3(-4.6, 0, 3.2), 8)
	_pack(g, "oxygen_cylinder_pair", Vector3(5.6, 0, 3.4))
	_pack(g, "supply_service_trolley", Vector3(3.0, 0, 3.9), -12)
	_pack(g, "relay_service_terminal", Vector3(7.2, 0, -3.9), -90)
	# 补给仓 1F 陈设（interior_pack 144 件）。约束：17×12.5 里后墙、两侧、中央
	# 都已有容器/道具，只填**后墙的两个空段**、南带两角和左墙上方。
	InteriorProps.place(g, "logistics_01", Vector3(-2.0, 0, -4.4), 0)   # 三层重型仓储架（后墙空段西）
	InteriorProps.place(g, "logistics_01", Vector3(1.0, 0, -4.4), 0)    # 三层重型仓储架（后墙空段东）
	InteriorProps.place(g, "logistics_07", Vector3(0.0, 0, -6.1), 0)    # 壁挂工具整理板（后墙）
	InteriorProps.place(g, "logistics_06", Vector3(8.3, 0, -4.6), -90)  # 落地灭火器（右墙里端）
	InteriorProps.place(g, "utility_08", Vector3(-8.3, 0, 2.0), 90)     # 壁挂空调（左墙）
	InteriorProps.place(g, "lounge_02", Vector3(-2.6, 0, 5.6), 180)     # 三席等候椅（南带）
	InteriorProps.place(g, "utility_10", Vector3(7.9, 0, 5.4), 180)     # 脚踏分类垃圾桶
	_sign(g, "港湾补给仓 · 按 E 开合容器", Vector3(0, 3.0, -6.1), 34, Color("e8f4f8"))
	return {"bounds": size, "spawn": Vector3(0, 0, 4.4), "camera_size": 30.0,
		"zones": [_zone("cages", "后墙货架区", Rect2(-8.0, -6.2, 16.0, 3.4)),
			_zone("aisle", "中央通道", Rect2(-8.0, -2.4, 16.0, 3.2)),
			_zone("pallet", "托盘堆放区", Rect2(-8.0, 1.6, 16.0, 4.4))]}

# ---------------------------------------------------------------- 后厨冷藏间

static func _coldstore(g) -> Dictionary:
	var size := Vector2(13.0, 10.0)
	_shell(g, size, Color("78878f"), Color("9dabb3"), Color("e6f7ff"))
	var b = g._builder(g.shell)
	# 不锈钢作业台前沿 + 冷库门口的出风带
	b.box(Vector3(11.6, .02, 1.5), Vector3(0, .05, -1.4), Color("9aa8ae"))
	b.box(Vector3(11.6, .015, .3), Vector3(0, .06, 3.2), Color("bfe3ee"))
	# 正对入口的双门冷藏柜（这台是主角，尺寸也最大）
	_container(g, "restaurant_tall_fridge", Vector3(-1.0, 0, -3.9), 0)
	_container(g, "bottle_storage_cabinet", Vector3(2.4, 0, -3.9), 0)
	# 左墙：低温柜与冷链柜并排
	_container(g, "laboratory_specimen_freezer", Vector3(-5.4, 0, -1.9), 90)
	_container(g, "cold_chain_medical_cabinet", Vector3(-5.4, 0, -.3), 90)
	# 作业台下方两件抽屉式容器
	_container(g, "undercounter_service_drawer", Vector3(-3.4, 0, -1.4), 0)
	_container(g, "searchable_file_cabinet", Vector3(3.9, 0, -1.4), 0)
	# 右墙：保险柜与投币存款柜（营业款）
	_container(g, "office_armored_safe", Vector3(5.6, 0, 1.6), -90)
	_container(g, "restaurant_cash_drop_safe", Vector3(5.6, 0, 2.9), -90)
	# 地上：配料箱与海鲜保温箱
	_container(g, "pantry_ingredient_bin", Vector3(-4.0, 0, 2.9), 0)
	_container(g, "insulated_seafood_chest", Vector3(1.9, 0, 2.9), 0)
	_pack(g, "stainless_prep_table", Vector3(-1.6, 0, .1), 0)
	_pack(g, "kitchen_sink_station", Vector3(3.2, 0, .1), 0)
	_pack(g, "supply_service_trolley", Vector3(-2.8, 0, 4.2), 4)
	# 冷藏间陈设（interior_pack 144 件）。约束：13×10 的矩形本身很满 ——
	# 后墙一排、左墙一排、右墙一排都已有容器，所以只填**空出来的四角与前带**。
	InteriorProps.place(g, "logistics_01", Vector3(-4.6, 0, -4.2), 0)   # 三层重型仓储架（后墙左段）
	InteriorProps.place(g, "logistics_02", Vector3(4.6, 0, -4.2), 0)    # 木质货物托盘（后墙右段）
	InteriorProps.place(g, "storage_11", Vector3(-6.1, 0, -3.0), 90)    # 壁挂储物柜（左墙里端）
	InteriorProps.place(g, "storage_02", Vector3(-6.1, 0, 1.0), 90)     # 分格开放书架（左墙中段）
	InteriorProps.place(g, "logistics_06", Vector3(-6.1, 0, 4.3), 180)  # 落地灭火器（左后角）
	InteriorProps.place(g, "utility_03", Vector3(4.4, 0, 3.9), 180)     # 镜面洗手台（右后角）
	InteriorProps.place(g, "utility_10", Vector3(5.4, 0, 4.3), 180)     # 脚踏分类垃圾桶
	InteriorProps.place(g, "lounge_02", Vector3(0.1, 0, 4.4), 180)      # 三席等候椅（前带）
	_sign(g, "后厨冷藏间 · 按 E 开合容器", Vector3(0, 2.8, -4.8), 32, Color("e8f4f8"))
	return {"bounds": size, "spawn": Vector3(0, 0, 3.0), "exit": Vector3(0, 0, 4.6), "camera_size": 24.0,
		"zones": [_zone("cold", "冷藏柜列", Rect2(-6.2, -4.6, 12.4, 3.0)),
			_zone("bench", "作业台区", Rect2(-6.2, -1.0, 12.4, 2.4)),
			_zone("receive", "收货与存货区", Rect2(-6.2, 1.8, 12.4, 3.0))]}

# ---------------------------------------------------------------- 异形房间
## 矩形列表 → 一个「异形」房间。
##
## 为什么需要它：原来每个房间都只吃一个 Vector2，所以**必然是方盒子**。
## 方盒子的问题是进门一眼看穿 —— 没有「转过一个弯才看到」的空间，
## 也没有中庭、没有长短翼，所有房间的走路体验都一模一样。
##
## 这里改成吃一串矩形，然后：
##   · 每块矩形各铺一块底板 + 一块地板面
##   · **只在「没有被其它矩形接住」的边上砌墙** —— 用区间相减算出来，
##     所以 L 形、T 形、U 形、带中庭的回字形都能自动得到正确墙线，
##     拐角处不会漏出一条能走出去的缝，共边的位置也不会多出一堵挡路的墙
##   · 墙高按朝向决定：朝 -z（背面）整面高，朝 ±x 半高，朝 +z（镜头这侧）矮墙，
##     沿用工程里其它房间的剖面读法
##
## 手写坐标时，相邻矩形的贴边要写**完全相同的数**（比如都用 -1.5），
## 否则浮点差会让共边判定失败，多砌一堵墙把通路堵死。
## 异形房间的「外围围栏」。与 neighborhood._bounds(size) 同形，
## 但围栏摆在**真实包围盒**的边上，而不是「以原点为中心的 ±size/2」。
##
## 为什么必须这样：_bounds(size) 只有房间居中时才正确。海关查验厅的包围盒是
## x −10..10、z −10..4（**z 中心在 −3**），照 ±7 摆就把一道 20.6 米宽的墙
## 砌进了房间内部（z=−7），把 T 形支廊的末端整段切掉 —— 实测那里两个货笼
## 玩家根本走不到（2 米内连一个可站格都没有）。气象站的包围盒 z −6..10
## （中心 2）同理，围栏会落在 z=+8 切掉观测段。
static func _bounds_at(g, lo: Vector2, hi: Vector2) -> void:
	var mid := (lo + hi) * 0.5
	var size := hi - lo
	for spec in [[Vector3(size.x + .5, 2, .2), Vector3(mid.x, 1, lo.y)],
			[Vector3(size.x + .5, 2, .2), Vector3(mid.x, 1, hi.y)],
			[Vector3(.2, 2, size.y), Vector3(lo.x, 1, mid.y)],
			[Vector3(.2, 2, size.y), Vector3(hi.x, 1, mid.y)]]:
		g._collision(g.shell, spec[0], spec[1])
static func _shell_shaped(g, rects: Array, base: Color, floor_tint: Color, light_tint: Color) -> Vector2:
	var b = g._builder(g.shell)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for r in rects:
		lo.x = minf(lo.x, r.position.x)
		lo.y = minf(lo.y, r.position.y)
		hi.x = maxf(hi.x, r.end.x)
		hi.y = maxf(hi.y, r.end.y)
	var size := hi - lo
	var mat = preload("res://modern_materials.gd").floor_material("slate_panels").duplicate()
	mat.set_shader_parameter("tile_color", floor_tint.srgb_to_linear())
	mat.set_shader_parameter("tile_size", 1.1)
	for r in rects:
		var c := Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.5)
		b.box(Vector3(r.size.x, .28, r.size.y), Vector3(c.x, -.15, c.y), base)
		b.box(Vector3(r.size.x, .045, r.size.y), Vector3(c.x, .002, c.y), floor_tint)
		var floor := PlaneMesh.new()
		floor.size = r.size
		var mesh := MeshInstance3D.new()
		mesh.mesh = floor
		mesh.position = Vector3(c.x, .034, c.y)
		mesh.material_override = mat
		g.shell.add_child(mesh)
	_bounds_at(g, lo, hi)
	for r in rects:
		# 沿 x 的两条边（z 固定）
		_wall_run(g, b, rects, r, r.position.x, r.end.x, r.position.y, false, base, 2.6)
		_wall_run(g, b, rects, r, r.position.x, r.end.x, r.end.y, false, base, 0.85)
		# 沿 z 的两条边（x 固定）
		_wall_run(g, b, rects, r, r.position.y, r.end.y, r.position.x, true, base, 1.15)
		_wall_run(g, b, rects, r, r.position.y, r.end.y, r.end.x, true, base, 1.15)
	# 灯：按包围盒铺，异形房间也够亮
	var cols := maxi(2, int(size.x / 4.5))
	var rows := maxi(2, int(size.y / 4.5))
	for ix in cols:
		for iz in rows:
			var p := Vector3(lo.x + size.x * (float(ix) + .5) / float(cols), 2.7,
				lo.y + size.y * (float(iz) + .5) / float(rows))
			var lamp := OmniLight3D.new()
			lamp.position = p
			lamp.light_color = light_tint
			lamp.light_energy = .70
			lamp.omni_range = 9.5
			g.shell.add_child(lamp)
	return size

## 沿某条边砌墙，跳过被别的矩形接住的段。
static func _wall_run(g, b, rects: Array, self_rect: Rect2, lo: float, hi: float,
		fixed: float, vertical: bool, base: Color, height: float) -> void:
	for seg in _open_spans(rects, self_rect, lo, hi, fixed, vertical):
		var length: float = seg.y - seg.x
		if length <= 0.02:
			continue
		var mid: float = (seg.x + seg.y) * 0.5
		var span := Vector3(.22, height, length) if vertical else Vector3(length, height, .22)
		var center := Vector3(fixed, height * 0.5, mid) if vertical else Vector3(mid, height * 0.5, fixed)
		b.box(span, center, base.lightened(.10) if height > 2.0 else base.lightened(.04))
		g._collision(g.shell, span, center)

## 在一段区间里挖掉门洞，返回剩下的段。`gap_at` 是门洞中心（沿这条线的坐标）。
static func _gap_spans(lo: float, hi: float, gap_at: float, gap_w: float) -> Array:
	var out: Array = []
	var g0: float = gap_at - gap_w * 0.5
	var g1: float = gap_at + gap_w * 0.5
	if g0 > lo + 0.02:
		out.append(Vector2(lo, minf(g0, hi)))
	if g1 < hi - 0.02:
		out.append(Vector2(maxf(g1, lo), hi))
	return out

## 室内隔断：沿一条**轴对齐**的线砌墙，中间留一个门洞。
##
## 前面所有房间（包括我做的 L / T / Z / 回字形）都还是「一整块空地」——
## 站门口就能把整个空间看穿，只是看穿的形状不同而已。
## 隔断改变的是**另一种东西**：把一个大空间切成「走廊 + 若干房间」，
## 必须走进门洞才知道后面是什么。轮廓形状给不了这个。
## `a` 与 `b` 必须共享一个坐标（都同 x 或都同 z），否则按水平处理。
static func _partition(g, a: Vector2, b: Vector2, height: float,
		gap_at: float, gap_w: float, base: Color) -> void:
	var bld = g._builder(g.shell)
	if absf(a.y - b.y) < 0.01:
		var lo: float = minf(a.x, b.x)
		var hi: float = maxf(a.x, b.x)
		for seg in _gap_spans(lo, hi, gap_at, gap_w):
			var span := Vector3(seg.y - seg.x, height, .18)
			var center := Vector3((seg.x + seg.y) * 0.5, height * 0.5, a.y)
			bld.box(span, center, base)
			g._collision(g.shell, span, center)
	else:
		var lo2: float = minf(a.y, b.y)
		var hi2: float = maxf(a.y, b.y)
		for seg in _gap_spans(lo2, hi2, gap_at, gap_w):
			var span2 := Vector3(.18, height, seg.y - seg.x)
			var center2 := Vector3(a.x, height * 0.5, (seg.x + seg.y) * 0.5)
			bld.box(span2, center2, base)
			g._collision(g.shell, span2, center2)

## 这条边上「没有别的矩形接住」的区间有哪些 —— 只有这些段需要砌墙。
## 做区间相减：先收集被占住的区间，再取出剩下的部分。
static func _open_spans(rects: Array, self_rect: Rect2, lo: float, hi: float,
		fixed: float, vertical: bool) -> Array:
	var covered: Array = []
	for r in rects:
		if r is Rect2 and r == self_rect:
			continue
		var touches: bool
		var rlo: float
		var rhi: float
		if vertical:
			touches = is_equal_approx(r.position.x, fixed) or is_equal_approx(r.end.x, fixed)
			rlo = r.position.y
			rhi = r.end.y
		else:
			touches = is_equal_approx(r.position.y, fixed) or is_equal_approx(r.end.y, fixed)
			rlo = r.position.x
			rhi = r.end.x
		if not touches:
			continue
		var a: float = maxf(lo, rlo)
		var b2: float = minf(hi, rhi)
		if b2 - a > 0.01:
			covered.append(Vector2(a, b2))
	if covered.is_empty():
		return [Vector2(lo, hi)]
	covered.sort_custom(func(p, q): return p.x < q.x)
	var out: Array = []
	var cursor := lo
	for c in covered:
		if c.x > cursor + 0.01:
			out.append(Vector2(cursor, minf(c.x, hi)))
		cursor = maxf(cursor, c.y)
	if cursor < hi - 0.01:
		out.append(Vector2(cursor, hi))
	return out

# ---------------------------------------------------------------- 零件

static func _shell(g, size: Vector2, base: Color, floor_tint: Color, light_tint: Color) -> void:
	var b = g._builder(g.shell)
	# 底板 + 面层（照抄 LifePlaces 的写法，保持一致的地面读法）
	b.box(Vector3(size.x, .28, size.y), Vector3(0, -.15, 0), base)
	b.box(Vector3(size.x - .3, .045, size.y - .3), Vector3(0, .002, 0), floor_tint)
	var floor := PlaneMesh.new()
	floor.size = Vector2(size.x - .3, size.y - .3)
	var mesh := MeshInstance3D.new()
	mesh.mesh = floor
	mesh.position.y = .034
	var mat = preload("res://modern_materials.gd").floor_material("slate_panels").duplicate()
	mat.set_shader_parameter("tile_color", floor_tint.srgb_to_linear())
	mat.set_shader_parameter("tile_size", 1.1)
	mesh.material_override = mat
	g.shell.add_child(mesh)
	g._bounds(size)
	# 后墙整面 + 两侧低墙：沿用工程里「剖面观察」的房间结构
	var half_w := size.x / 2
	var half_d := size.y / 2
	b.box(Vector3(size.x, 3.1, .22), Vector3(0, 1.55, -half_d), base.lightened(.10))
	g._collision(g.shell, Vector3(size.x, 3.1, .22), Vector3(0, 1.55, -half_d))
	for side in [-1.0, 1.0]:
		b.box(Vector3(.22, 1.15, size.y), Vector3(side * half_w, .575, 0), base.lightened(.05))
		g._collision(g.shell, Vector3(.22, 1.15, size.y), Vector3(side * half_w, .575, 0))
	# 顶部灯带：工业/后厨都是「亮而冷」，和住宅的暖光拉开。
	# 灯要够亮：第一版 energy 只给了 .30，配合偏深的地面颜色，
	# 整个房间在白天看起来像没开灯 —— 那是「暗」不是「工业感」。
	for i in 4:
		var t := float(i) / 3.0
		var x: float = lerpf(-half_w * .62, half_w * .62, t)
		b.box(Vector3(1.8, .07, .24), Vector3(x, 2.88, -.8), Color("f4fcff"))
		b.box(Vector3(1.8, .07, .24), Vector3(x, 2.88, 1.6), Color("f4fcff"))
		for z in [-.8, 1.6]:
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(x, 2.66, z)
			lamp.light_color = light_tint
			lamp.light_energy = .85
			lamp.omni_range = 10.0
			g.shell.add_child(lamp)

## 摆一个「真的能开、而且里面有东西」的容器。
## 建的是适配层节点（district/loot_container.gd），它内部再挂 container_runtime ——
## 因为素材包的接口（set_open_state）和工程的战利品接口（set_open/display_name）不一样。
static func _container(g, cid: String, pos: Vector3, angle: float = 0.0):
	var packed: PackedScene = load(RUNTIME)
	if packed == null:
		push_warning("ContainerRooms: 缺少 " + RUNTIME)
		return null
	var spec := _spec_of(cid)
	_container_seq += 1
	# 唯一 id：房间 + 类型 + 序号。见 loot_container.gd 对「共用库存」的说明。
	var unique := "%s__%s__%d" % [str(g.location_id), cid, _container_seq]
	return load("res://district/loot_container.gd").spawn(
		g.world, cid, unique, str(spec.get("label", cid)), pos, angle,
		str(ROOM_NOTES.get(str(g.location_id), "")))

## 读 container_specs.json 里某个类型的规格（label 要显示给玩家看）
static func _spec_of(cid: String) -> Dictionary:
	if _specs.is_empty():
		var arr: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://container_specs.json"))
		if arr is Array:
			for entry in arr:
				_specs[str(entry.get("id", ""))] = entry
	return _specs.get(cid, {})

## 摆一个**素材包**里的静态道具（`res://models/props/`）。
##
## 这里有两套同名概念，很容易搞混（我就混过一次，13 个模型静默缺件）：
##   · `_prop(g, id, …)`  → 素材包的 models/props/（planter / palm / rocks / table_round …）
##   · `g._prop(id, …)`   → **工程自己**的 scenes/modules_3d/（带 v18_ 前缀的全在这里）
## 放错目录不会中断，只会刷 "Failed loading resource"，
## 然后那个摆件就悄悄消失了 —— 从画面上看不出是缺件还是本来就没摆。
static func _prop(g, id: String, pos: Vector3, angle: float = 0.0):
	return _pack_in(g, PROP_DIR, id, pos, angle)

static func _sign(g, text: String, pos: Vector3, font_size: int, color: Color) -> void:
	var label = g._sign(text, pos, font_size, color)
	if label != null:
		label.outline_size = 5
		label.outline_modulate = Color("2b3d47")

static func _zone(id: String, name: String, rect: Rect2) -> Dictionary:
	var c := rect.get_center()
	return {"id": id, "name": name, "rect": rect, "center": Vector3(c.x, 0, c.y)}

# ---------------------------------------------------------------- 容器里装什么
## 物品 id **全部取自 loot_controller.gd 的 INITIAL_STOCK** —— 那是工程已有的物品表，
## 有图标、有说明、能进背包。这里不新造 id：造了背包 UI 也认不出来。
## 按容器用途分组，让「医疗柜里有急救包、货笼里是海边捡的东西」符合直觉。
const STOCK := {
	# 医疗 / 实验
	"field_medical_chest":{"first_aid":2,"sea_biscuit":2},
	"cold_chain_medical_cabinet":{"first_aid":2,"soft_linen":2},
	"laboratory_specimen_freezer":{"first_aid":2,"retry_tea":2},
	"sample_transport_case":{"first_aid":1,"sea_shell":3},
	"wall_emergency_supply_cabinet":{"first_aid":3,"stopped_pillow":1},
	# 物流 / 货运
	"harbor_cargo_cage":{"sea_shell":4,"paper_boat":2,"ivory_shell":1},
	"rolling_logistics_case":{"sea_glass":2,"butter_bread":2,"paper_boat":1},
	"reinforced_flight_case":{"whale_compass":1,"instant_camera":1},
	"field_supply_crate":{"sea_biscuit":3,"lemon_water":2},
	"long_equipment_case":{"harbor_key":1,"fish_badge":1},
	# 海事 / 潜水
	"marine_waterproof_case":{"sea_glass":3,"ivory_shell":2},
	"diver_equipment_case":{"sea_shell":3,"sea_glass":2,"tide_compass":1},
	"maritime_signal_locker":{"harbor_ticket":1,"whale_compass":1},
	"lifesaving_deck_box":{"soft_linen":2,"paper_boat":1},
	# 设备 / 电力
	"server_service_cabinet":{"thinking_lamp":1,"cache_book":1},
	"encrypted_electronics_case":{"prompt_pen":1,"cache_book":1},
	"battery_module_crate":{"thinking_lamp":1,"retry_tea":1},
	"secure_equipment_locker":{"soft_linen":3,"whale_soap":2},
	# 金库 / 单证
	"office_armored_safe":{"whale_music_box":1,"harbor_key":1},
	"wall_data_safe":{"context_note":1,"branch_bookmark":1},
	"restaurant_cash_drop_safe":{"token_cracker":4},
	"currency_transport_case":{"token_cracker":3,"harbor_ticket":1},
	"searchable_file_cabinet":{"context_note":1,"branch_bookmark":2,"paper_boat":1},
	"port_manifest_drawer":{"harbor_ticket":1,"branch_bookmark":1},
	# 餐饮 / 后厨
	"restaurant_tall_fridge":{"lemon_water":3,"sea_soup":2},
	"bottle_storage_cabinet":{"lemon_water":2,"blue_teapot":1},
	"pantry_ingredient_bin":{"butter_bread":3,"sea_biscuit":2},
	"undercounter_service_drawer":{"sea_biscuit":2,"whale_soap":1},
	"insulated_seafood_chest":{"sea_soup":3},
	"industrial_tool_chest":{"sewing_kit":1,"prompt_pen":1},
}
const STOCK_DEFAULT := {"sea_shell":1}

## 搜刮界面上那句「这是哪儿」的说明
const ROOM_NOTES := {
	"depot":"港湾补给仓 · 靠港的货不一定都能领走。",
	"coldstore":"后厨冷藏间 · 别把明天的份也拿光。",
	"vault":"港湾保险库 · 记在册上的东西，拿走会留痕。",
	"lab":"地下实验区 · 样本离开冷链就开始变质。",
	"archive":"潮汐档案馆 · 借阅登记在门口那本册子上。",
	"customs":"港口海关查验厅 · 未申报的东西请放回原处。",
	"weather":"山地气象站 · 山上补给不易，省着用。",
	"hub":"中央枢纽站 · 失物招领处无人认领的物品。",
	"quarantine":"分区检疫所 · 处理过的物资才可带出。",
	"spares":"备件长库 · 按编号领取，别凭手感。",
	"tidal_high":"潮间带 · 涨潮时留在滩上的东西，会跟水一起走。",
	"tidal_low":"潮间带 · 落潮露出来的，是海暂时不要的。",
}

static var _specs: Dictionary = {}
static var _container_seq := 0

## 把本房间里所有容器登记进战利品系统。
## loot_controller 是按 chests 数组 + stocks 字典工作的（契约见 meme_chest.gd），
## 所以这里不改它的取物逻辑，只是把我们的容器喂进去。
static func _wire_loot(g) -> void:
	if g.loot == null:
		return
	_container_seq = 0
	g.loot.chests.clear()
	for node in g.world.get_children():
		if not (node is Node3D) or not node.has_method("toggle_open"):
			continue
		var unique := str(node.container_id)
		if unique == "":
			continue
		var type_id := str(node.get_meta("container_type", ""))
		# A saved empty dictionary is also an initialized container: never refill it.
		if not g.loot.stocks.has(unique):
			g.loot.stocks[unique] = (STOCK.get(type_id, STOCK_DEFAULT) as Dictionary).duplicate()
		g.loot.chests.append(node)

# ---------------------------------------------------------------- 交互

## 找玩家附近最近的**可交互对象**（默认 2.4 米内），没有就返回 null。
##
## 两类都算：
##   · 容器 —— district/loot_container.gd，有 toggle_open() / display_name
##   · 带活动部件的室内物品 —— interior_pack 的 item_3d.gd，有 has_action() / interact()
##     （44 件：保险柜门、冷藏柜门、抽屉、培养箱、售货机、取件柜、闸机、自动门…）
##
## container_runtime 只负责模型开合，不提供「谁在附近」——
## 素材包说明里明确写了交互要自己接。
static func nearest(g, radius: float = 2.4):
	var best = null
	var best_d := radius
	for node in g.world.get_children():
		if not (node is Node3D):
			continue
		var usable: bool = node.has_method("toggle_open")
		if not usable and node.has_method("has_action"):
			usable = bool(node.call("has_action"))
		if not usable:
			continue
		var d: float = g.player.global_position.distance_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best

## 给提示文字用：身边这个东西叫什么
static func describe(node) -> String:
	if node == null:
		return ""
	if node.has_method("toggle_open"):
		return str(node.display_name)
	if node.has_method("has_action"):
		return InteriorProps.label(str(node.asset_id))
	return ""

## 按 E 时先让身边的东西拿一次机会。返回 true 表示这次输入已经被用掉了。
static func try_toggle(g) -> bool:
	var node = nearest(g)
	if node == null:
		return false
	if g.loot.chests.has(node):
		if not g.loot._in_range(node):return false
		g.loot.nearby=node
		g.loot.open_chest()
		return g.loot.mode=="loot"
	var was_open := bool(node.get("opened"))
	if node.has_method("toggle_open"):
		node.toggle_open()
	elif node.has_method("interact"):
		# interior_pack 的物品：item_3d.interact() 会翻转开合（可逆 Tween）
		node.call("interact")
	else:
		return false
	# 开的时候要有声音。工程里旧箱子走 loot_controller.open_chest()，那里播了 chest_open；
	# 新地点的容器和这些室内物品都走这条路径，不补一句就是静音的（我第一版就漏了）。
	# 只在「开」的时候响，和旧箱子一致 —— 关的时候不响。
	if not was_open:
		SfxDirector.play("chest_open", -3.0)
	return true
