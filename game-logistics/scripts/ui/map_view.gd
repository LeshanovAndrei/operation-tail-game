class_name MapView
extends Node2D

signal node_selected(node_id: String)
signal route_target_confirmed(origin_id: String, dest_id: String)
signal route_target_cancelled()
signal quick_route_requested(origin_id: String, dest_id: String)

const NODE_CLICK_RADIUS: float = 34.0
const EDGE_HOVER_RADIUS: float = 13.0
const GRID_SPACING: float = 128.0
const RMB_CLICK_MAX_DIST: float = 6.0

const COL_INK: Color = Color("#22261e")
const COL_PLATE_BG: Color = Color("#22261eCC")
const COL_PLATE_BORDER: Color = Color("#4c5442")
const COL_TEXT_LIGHT: Color = Color("#e6e2d3")
const COL_TEXT_MUTED: Color = Color("#9fa694")
const COL_FRIENDLY: Color = Color("#4a86c8")
const COL_ENEMY: Color = Color("#b53a2d")
const COL_ENEMY_FILL: Color = Color(0.710, 0.227, 0.176, 0.28)
const COL_RIVER: Color = Color("#6c92a6")
const COL_RIVER_BANK: Color = Color("#496878")
const COL_RIVER_SHEEN: Color = Color("#8fb3c4")
const COL_FUEL: Color = Color("#d9a441")
const COL_AMMO: Color = Color("#739e4c")
const COL_CRITICAL: Color = Color("#c94a38")

var engine: SimEngine = null
var selected_node_id: String = ""
var tick_alpha: float = 1.0

var show_distances: bool = false
var show_threat_layer: bool = false
var show_routes: bool = true

var _targeting_origin_id: String = ""
var _preview_convoy_type: SimTypes.ConvoyType = SimTypes.ConvoyType.CARGO
var _preview_order_mode: SimTypes.OrderMode = SimTypes.OrderMode.LOOP
var _preview_cargo_pref: SimTypes.CargoPreference = SimTypes.CargoPreference.MIXED
var _hovered_node_id: String = ""
var _hovered_edge_id: String = ""
var _rmb_down_pos: Vector2 = Vector2.ZERO
var _rmb_pressed: bool = false
var _anim_time: float = 0.0

var _prev_convoy_state: Dictionary[String, Dictionary] = {}

var _edge_curves: Dictionary[String, Curve2D] = {}
var _edge_baked: Dictionary[String, PackedVector2Array] = {}
var _river_curves: Array[Dictionary] = []
var _rail_pts: PackedVector2Array = PackedVector2Array()
var _front_bands: Array[Dictionary] = []
var _band_shift: Dictionary[String, float] = {}
var _front_line_pts: PackedVector2Array = PackedVector2Array()
var _enemy_polygon: PackedVector2Array = PackedVector2Array()
var _enemy_units: Array[Dictionary] = []
var _front_units: Dictionary[String, Dictionary] = {}
var _bridge_nodes: Dictionary[String, bool] = {}

var _font_reg: Font = null
var _font_bold: Font = null
var _font_mono: Font = null

var _ico_rail: Texture2D = null
var _ico_depot: Texture2D = null
var _ico_crossroad: Texture2D = null
var _ico_truck: Texture2D = null
var _ico_tanker: Texture2D = null
var _ico_engineer: Texture2D = null
var _ico_hazard: Texture2D = null
var _ico_radar: Texture2D = null
var _ico_mortar: Texture2D = null
var _ico_broken: Texture2D = null
var _ico_medevac: Texture2D = null
var _ico_mine: Texture2D = null
var _ico_target: Texture2D = null
var _ico_flag: Texture2D = null
var _ico_apc: Texture2D = null
var _ico_tent: Texture2D = null
var _ico_star: Texture2D = null


func _ready() -> void:
	_font_reg = TacticalTheme.get_regular_font()
	_font_bold = TacticalTheme.get_bold_font()
	_font_mono = TacticalTheme.get_mono_font()

	_ico_rail = TacticalTheme.load_icon("steam-locomotive")
	_ico_depot = TacticalTheme.load_icon("warehouse")
	_ico_crossroad = TacticalTheme.load_icon("crossroad")
	_ico_truck = TacticalTheme.load_icon("flatbed-covered")
	_ico_tanker = TacticalTheme.load_icon("gas-pump")
	_ico_engineer = TacticalTheme.load_icon("bulldozer")
	_ico_hazard = TacticalTheme.load_icon("hazard-sign")
	_ico_radar = TacticalTheme.load_icon("radar-sweep")
	_ico_mortar = TacticalTheme.load_icon("mortar")
	_ico_broken = TacticalTheme.load_icon("broken-wall")
	_ico_medevac = TacticalTheme.load_icon("military-ambulance")
	_ico_mine = TacticalTheme.load_icon("teller-mine")
	_ico_target = TacticalTheme.load_icon("convergence-target")
	_ico_flag = TacticalTheme.load_icon("tower-flag")
	_ico_apc = TacticalTheme.load_icon("apc")
	_ico_tent = TacticalTheme.load_icon("barracks-tent")
	_ico_star = TacticalTheme.load_icon("allied-star")


func _process(delta: float) -> void:
	_anim_time += delta
	_update_dynamic_frontline(delta)
	_update_hover_state()
	queue_redraw()


func set_engine(sim_engine: SimEngine, scenario_path: String = "res://data/scenario_offensive.json") -> void:
	engine = sim_engine
	_band_shift.clear()
	_prev_convoy_state.clear()
	_load_visual_metadata(scenario_path)
	_build_edge_curves()
	_rebuild_frontline_geometry()
	_targeting_origin_id = ""
	tick_alpha = 1.0
	queue_redraw()


func snapshot_before_tick() -> void:
	_prev_convoy_state.clear()
	if engine == null or engine.graph == null:
		return
	for convoy: Convoy in engine.convoys:
		var raw: Dictionary = _sample_edge_point_raw(convoy)
		raw["state"] = convoy.state
		_prev_convoy_state[convoy.id] = raw


func set_selected_node(node_id: String) -> void:
	selected_node_id = node_id
	queue_redraw()


func set_targeting_options(
	ctype: SimTypes.ConvoyType,
	mode: SimTypes.OrderMode,
	pref: SimTypes.CargoPreference = SimTypes.CargoPreference.MIXED
) -> void:
	_preview_convoy_type = ctype
	_preview_order_mode = mode
	_preview_cargo_pref = pref


func start_route_targeting(
	origin_id: String,
	ctype: SimTypes.ConvoyType,
	mode: SimTypes.OrderMode,
	pref: SimTypes.CargoPreference = SimTypes.CargoPreference.MIXED
) -> void:
	_targeting_origin_id = origin_id
	_preview_convoy_type = ctype
	_preview_order_mode = mode
	_preview_cargo_pref = pref
	queue_redraw()


func cancel_route_targeting() -> void:
	if not _targeting_origin_id.is_empty():
		_targeting_origin_id = ""
		queue_redraw()


func is_targeting() -> bool:
	return not _targeting_origin_id.is_empty()


func set_layer_flag(layer_name: String, enabled: bool) -> void:
	match layer_name:
		"distances":
			show_distances = enabled
		"threats":
			show_threat_layer = enabled
		"routes":
			show_routes = enabled
	queue_redraw()


func get_hover_tooltip_data() -> Dictionary:
	if engine == null or engine.graph == null or is_targeting():
		return {}
	var vp: Viewport = get_viewport()
	if vp != null and vp.gui_get_hovered_control() != null:
		return {}

	if not _hovered_node_id.is_empty():
		return _build_node_tooltip(_hovered_node_id)
	if not _hovered_edge_id.is_empty():
		return _build_edge_tooltip(_hovered_edge_id)
	return {}


func _build_node_tooltip(node_id: String) -> Dictionary:
	var node: SimTypes.MapNode = engine.graph.get_node(node_id)
	if node == null:
		return {}
	var lines: Array[String] = []
	var warn: String = ""

	match node.node_type:
		SimTypes.NodeType.RAILHEAD:
			if node.is_vulnerable:
				lines.append("Прифронтовая станция • Сигнатура: %.0f%%" % node.signature)
			else:
				lines.append("Тыловая ж/д база • Неуязвима для ударов")
			lines.append("ГСМ %.0fт • БК %.0fт • ПР %.0fт • ЗП %.0fт" % [
				node.get_stock(SimTypes.ResourceType.FUEL),
				node.get_stock(SimTypes.ResourceType.AMMO),
				node.get_stock(SimTypes.ResourceType.PROVISIONS),
				node.get_stock(SimTypes.ResourceType.PARTS),
			])
		SimTypes.NodeType.DEPOT, SimTypes.NodeType.FIELD_DEPOT:
			lines.append("Сигнатура: %.0f%% | Слотов погрузки: %d/%d" % [node.signature, node.active_loading_count, node.loading_slots])
			lines.append("ГСМ %.0fт • БК %.0fт • ПР %.0fт • ЗП %.0fт" % [
				node.get_stock(SimTypes.ResourceType.FUEL),
				node.get_stock(SimTypes.ResourceType.AMMO),
				node.get_stock(SimTypes.ResourceType.PROVISIONS),
				node.get_stock(SimTypes.ResourceType.PARTS),
			])
			if node.node_type == SimTypes.NodeType.FIELD_DEPOT:
				lines.append("Развёрнутый полевой склад (-25% базовой сигнатуры)")
			if node.pack_ticks_remaining > 0:
				lines.append("Сворачивание: осталось ~%d мин" % (node.pack_ticks_remaining * SimEngine.TICK_MINUTES))
			if node.camouflaged:
				lines.append("Маскировка ВКЛ (-50% сигнатуры)")
			if node.signature >= 75.0:
				warn = "КРИТИЧНО: высокий риск удара разведки!"
		SimTypes.NodeType.JUNCTION:
			if node.can_deploy_depot:
				lines.append("Площадка полевого склада (нужно %.0f/%.0fт ЗП + Инж.)" % [node.deploy_progress_parts, node.deploy_cost_parts])
				if node.deploy_build_ticks_remaining > 0:
					lines.append("Строительство: осталось ~%d мин" % (node.deploy_build_ticks_remaining * SimEngine.TICK_MINUTES))
			else:
				lines.append("Хранение грузов невозможно.")
				lines.append("Отстой порожних колонн (Передислокация) или ремонт моста/дорог.")
			if node.damaged:
				warn = "МОСТ ПОВРЕЖДЁН! Отправьте Инженерную колонну (%.0f/%.0fт ЗП)." % [node.repair_progress_parts, node.repair_cost_parts]
		SimTypes.NodeType.ARTILLERY:
			var fl: String = node.flank if not node.flank.is_empty() else "NORTH"
			var active: bool = engine.arty_support_by_flank.get(fl, false)
			lines.append("Уровень оснащения: %s | (%s): %s" % ["II (Модерн.)" if node.equipment_tier >= 2 else "I", fl, "ОГОНЬ" if active else "ОЖИДАНИЕ"])
			lines.append("БК %.0f/%.0fт • ГСМ %.0fт" % [
				node.get_stock(SimTypes.ResourceType.AMMO),
				node.get_capacity(SimTypes.ResourceType.AMMO),
				node.get_stock(SimTypes.ResourceType.FUEL),
			])
		SimTypes.NodeType.FRONT_SECTOR:
			lines.append("Ур. оснащения: %s | Целостность: %.0f%% | Бой: %s" % [
				"II ★" if node.equipment_tier >= 2 else "I",
				node.integrity,
				SimTypes.intensity_label(node.intensity),
			])
			lines.append("ГСМ %.0fт • БК %.0fт • ПР %.0fт • ЗП %.0fт | Ран: %.0f" % [
				node.get_stock(SimTypes.ResourceType.FUEL),
				node.get_stock(SimTypes.ResourceType.AMMO),
				node.get_stock(SimTypes.ResourceType.PROVISIONS),
				node.get_stock(SimTypes.ResourceType.PARTS),
				node.wounded,
			])
			if node.equipment_tier < 2 and node.reequip_progress > 0.1:
				lines.append("Перевооружение: %.0f / %.0fт ПЕР" % [node.reequip_progress, node.reequip_cost])
		SimTypes.NodeType.OBJECTIVE:
			if node.owner == SimTypes.Owner.FRIENDLY:
				lines.append("Захвачен • Передовая база снабжения")
			else:
				lines.append("Под контролем противника • Захват: %.0f%%" % node.capture_progress)
				warn = "Дороги заблокированы до прорыва линии фронта."

	return {
		"title": node.display_name,
		"subtitle": SimTypes.node_type_label(node.node_type),
		"lines": lines,
		"warning": warn,
	}


func _build_edge_tooltip(edge_id: String) -> Dictionary:
	var target_edge: SimTypes.RoadEdge = null
	for edge: SimTypes.RoadEdge in engine.graph.edges:
		if edge.id == edge_id:
			target_edge = edge
			break
	if target_edge == null:
		return {}

	var na: SimTypes.MapNode = engine.graph.get_node(target_edge.from_id)
	var nb: SimTypes.MapNode = engine.graph.get_node(target_edge.to_id)
	var n1: String = na.display_name if na != null else target_edge.from_id
	var n2: String = nb.display_name if nb != null else target_edge.to_id
	var base_spd: float = target_edge.get_base_speed_kmh()
	var cur_spd: float = engine.graph.get_edge_effective_speed_kmh(target_edge, engine.weather, _preview_convoy_type)
	var wear_pct: int = int(round(target_edge.wear * 100.0))

	var w_note: String = "Без штрафов"
	if engine.weather == SimTypes.Weather.RAIN:
		w_note = "Дождь (грунт -35%, износ x2)"
	elif engine.weather == SimTypes.Weather.MUD:
		w_note = "Распутица (грунт -55%, износ x2.2)"

	var lines: Array[String] = [
		"Скорость: %.0f / %.0f км/ч (%s)" % [cur_spd, base_spd, SimTypes.convoy_type_label(_preview_convoy_type)],
		"Износ: %d%% | Погода: %s" % [wear_pct, w_note],
	]

	var warn: String = ""
	if not engine.graph.is_edge_passable(target_edge):
		warn = "Участок за линией фронта — проезд откроется после захвата узла."
	elif target_edge.mined:
		warn = "Заминировано после прорыва! Отправьте Инженерную колонну для расчистки (скорость 15%)."
	elif engine.graph.is_edge_bridge_damaged(target_edge):
		warn = "Прилегающий мост повреждён! Скорость 15% — отправьте Инж. колонну с Запчастями."
	elif target_edge.wear >= 0.35:
		warn = "Дорога разбита (оранжевый знак): отправьте Инженерную колонну с Запчастями для ремонта."
	if target_edge.frontline_danger and engine.graph.is_edge_passable(target_edge):
		var danger_msg: String = "ОПАСНАЯ ЗОНА «последней мили»: простреливается артиллерией! Безопаснее ехать БТР или ночью (-70% риска)."
		warn = danger_msg if warn.is_empty() else (warn + "\n" + danger_msg)

	return {
		"title": "%s — %s" % [n1, n2],
		"subtitle": "%s • %.0f км" % [SimTypes.road_type_label(target_edge.road_type), target_edge.distance_km],
		"lines": lines,
		"warning": warn,
	}


func _unhandled_input(event: InputEvent) -> void:
	if engine == null or engine.graph == null:
		return
	var vp: Viewport = get_viewport()
	if vp != null and vp.gui_get_hovered_control() != null:
		return

	if event is InputEventKey:
		var kev: InputEventKey = event
		if kev.pressed and not kev.echo and kev.keycode == KEY_ESCAPE and is_targeting():
			_targeting_origin_id = ""
			route_target_cancelled.emit()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var hit_id: String = _hit_test_node(get_global_mouse_position())
			if is_targeting():
				if not hit_id.is_empty() and hit_id != _targeting_origin_id:
					var val: Dictionary = engine.validate_dispatch(
						_targeting_origin_id, hit_id, _preview_convoy_type, _preview_cargo_pref, _preview_order_mode
					)
					if bool(val.get("ok", false)):
						var orig: String = _targeting_origin_id
						_targeting_origin_id = ""
						route_target_confirmed.emit(orig, hit_id)
					return
				elif hit_id.is_empty():
					_targeting_origin_id = ""
					route_target_cancelled.emit()
					return
			if not hit_id.is_empty():
				selected_node_id = hit_id
				node_selected.emit(hit_id)
				queue_redraw()

		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_rmb_pressed = true
				_rmb_down_pos = mb.position
			elif _rmb_pressed:
				_rmb_pressed = false
				if mb.position.distance_to(_rmb_down_pos) < RMB_CLICK_MAX_DIST:
					if is_targeting():
						_targeting_origin_id = ""
						route_target_cancelled.emit()
					else:
						var hit_id: String = _hit_test_node(get_global_mouse_position())
						if not hit_id.is_empty() and not selected_node_id.is_empty() and hit_id != selected_node_id:
							quick_route_requested.emit(selected_node_id, hit_id)


func _draw() -> void:
	_draw_grid_labels()
	_draw_rivers()
	_draw_enemy_zone_and_frontline()

	if engine == null or engine.graph == null:
		return

	_draw_rail_line()
	_draw_edges()
	_draw_active_routes()
	_draw_artillery_arcs()
	_draw_targeting_preview()
	_draw_threat_overlay()
	_draw_nodes()
	_draw_convoys()


func _draw_grid_labels() -> void:
	var font: Font = _font_mono if _font_mono != null else ThemeDB.fallback_font
	var cols: int = 18
	var rows: int = 10
	var letters: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	var label_col: Color = Color(0.24, 0.25, 0.20, 0.48)
	for c: int in range(cols):
		for r: int in range(rows):
			if c % 2 == 0 and r % 2 == 0:
				var gx: float = float(c) * GRID_SPACING + 6.0
				var gy: float = float(r) * GRID_SPACING + 16.0
				var code: String = "%s%d" % [letters[c % letters.length()], r + 1]
				draw_string(font, Vector2(gx, gy), code, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, label_col)


func _draw_rivers() -> void:
	var font: Font = _font_reg if _font_reg != null else ThemeDB.fallback_font
	for river_info: Dictionary in _river_curves:
		var pts: PackedVector2Array = river_info.get("baked", PackedVector2Array())
		var width: float = float(river_info.get("width", 10.0))
		var rname: String = str(river_info.get("name", ""))
		if pts.size() < 2:
			continue

		draw_polyline(pts, COL_RIVER_BANK, width + 3.2, true)
		draw_polyline(pts, COL_RIVER, width, true)
		draw_polyline(pts, COL_RIVER_SHEEN, maxf(1.5, width * 0.28), true)

		if not rname.is_empty():
			var mid_pt: Vector2 = pts[int(pts.size() * 0.48)]
			draw_string(font, mid_pt + Vector2(12.0, 0.0), rname, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#2c4a59"))


func _draw_enemy_zone_and_frontline() -> void:
	if _enemy_polygon.size() >= 3:
		draw_colored_polygon(_enemy_polygon, COL_ENEMY_FILL)
		var hatch_col: Color = Color(0.71, 0.23, 0.18, 0.11)
		var y_cursor: float = -320.0
		while y_cursor < 1700.0:
			draw_line(Vector2(1660.0, y_cursor), Vector2(2650.0, y_cursor - 520.0), hatch_col, 1.5, true)
			y_cursor += 42.0

	if _front_line_pts.size() >= 2:
		var blue_pts: PackedVector2Array = PackedVector2Array()
		var red_pts: PackedVector2Array = PackedVector2Array()
		for pt: Vector2 in _front_line_pts:
			blue_pts.append(pt + Vector2(-4.5, 0.0))
			red_pts.append(pt + Vector2(4.5, 0.0))

		draw_polyline(blue_pts, COL_FRIENDLY, 2.8, true)
		draw_polyline(red_pts, COL_ENEMY, 2.8, true)

		var tooth_acc: float = 0.0
		for i: int in range(red_pts.size() - 1):
			var a: Vector2 = red_pts[i]
			var b: Vector2 = red_pts[i + 1]
			var seg_len: float = a.distance_to(b)
			var dir: Vector2 = (b - a).normalized()
			var east_normal: Vector2 = Vector2(dir.y, -dir.x)
			if east_normal.x < 0.0:
				east_normal = -east_normal
			var pos_along: float = 16.0 - tooth_acc
			while pos_along < seg_len:
				var base_p: Vector2 = a + dir * pos_along
				var tip_p: Vector2 = base_p + east_normal * 8.0
				draw_line(base_p - dir * 4.0, tip_p, COL_ENEMY, 1.8, true)
				draw_line(base_p + dir * 4.0, tip_p, COL_ENEMY, 1.8, true)
				pos_along += 28.0
			tooth_acc = fmod(tooth_acc + seg_len, 28.0)

	var font_b: Font = _font_bold if _font_bold != null else ThemeDB.fallback_font
	for eu_idx: int in range(_enemy_units.size()):
		var eu: Dictionary = _enemy_units[eu_idx]
		var obj_id: String = str(eu.get("obj_id", ""))
		if engine != null and engine.graph != null and not obj_id.is_empty():
			var obj_node: SimTypes.MapNode = engine.graph.get_node(obj_id)
			if obj_node != null and obj_node.owner == SimTypes.Owner.FRIENDLY:
				continue

		var pos: Vector2 = Vector2(float(eu.get("x", 1780.0)), float(eu.get("y", 400.0)))
		var sec_id: String = str(eu.get("sector_id", ""))
		var sec_intensity: SimTypes.Intensity = SimTypes.Intensity.LOW
		var sec_pos: Vector2 = pos - Vector2(180.0, 0.0)
		if engine != null and engine.graph != null:
			var sec_node: SimTypes.MapNode = engine.graph.get_node(sec_id)
			if sec_node != null:
				sec_intensity = sec_node.intensity
				sec_pos = sec_node.position

		if sec_intensity != SimTypes.Intensity.LOW:
			_draw_combat_flashes(sec_pos, pos, sec_intensity, eu_idx)

		var pulse: float = 1.0
		if sec_intensity == SimTypes.Intensity.HIGH:
			pulse = 1.0 + 0.12 * sin(_anim_time * 5.0)
			var aura_alpha: float = 0.20 + 0.18 * (0.5 + 0.5 * sin(_anim_time * 5.0))
			draw_circle(pos, 24.0 * pulse, Color(0.79, 0.29, 0.22, aura_alpha))

		var r: float = 16.0 * pulse
		var diamond: PackedVector2Array = PackedVector2Array([
			pos + Vector2(0.0, -r),
			pos + Vector2(r * 1.18, 0.0),
			pos + Vector2(0.0, r),
			pos + Vector2(-r * 1.18, 0.0),
		])
		draw_colored_polygon(diamond, Color("#992d22E0"))
		for i: int in range(4):
			draw_line(diamond[i], diamond[(i + 1) % 4], Color("#2b0d0a"), 2.0, true)

		var sym: String = str(eu.get("symbol", "INFANTRY"))
		if sym == "ARMOR":
			_draw_ellipse_outline(pos, 8.5, 4.8, Color("#f5e6e4"), 1.6)
		else:
			draw_line(pos + Vector2(-6.5, -4.5), pos + Vector2(6.5, 4.5), Color("#f5e6e4"), 1.6, true)
			draw_line(pos + Vector2(6.5, -4.5), pos + Vector2(-6.5, 4.5), Color("#f5e6e4"), 1.6, true)

		var echelon: String = str(eu.get("echelon", "III"))
		_draw_centered_text(font_b, pos + Vector2(0.0, -r - 4.0), echelon, 11, Color("#6b1710"))
		_draw_plate_label(font_b, pos + Vector2(0.0, r + 13.0), str(eu.get("code", "")), 11, Color("#f7d9d5"), Color("#3b1512CC"), Color("#b53a2d"))


func _draw_combat_flashes(sec_pos: Vector2, enemy_pos: Vector2, intensity: SimTypes.Intensity, seed_idx: int) -> void:
	var line_mid: Vector2 = sec_pos.lerp(enemy_pos, 0.56)
	var freq: float = 3.2 if intensity == SimTypes.Intensity.HIGH else 1.8
	var burst_count: int = 3 if intensity == SimTypes.Intensity.HIGH else 2
	for b: int in range(burst_count):
		var phase: float = fmod(_anim_time * freq + float(b) * 0.37 + float(seed_idx) * 0.53, 1.0)
		var spread_y: float = sin(float(b * 17 + seed_idx * 31) + floor(_anim_time * freq) * 2.1) * 24.0
		var spread_x: float = cos(float(b * 11 + seed_idx * 19)) * 10.0
		var burst_pos: Vector2 = line_mid + Vector2(spread_x, spread_y)
		var ring_r: float = 4.0 + phase * (17.0 if intensity == SimTypes.Intensity.HIGH else 11.0)
		var alpha: float = (1.0 - phase) * 0.72
		draw_arc(burst_pos, ring_r, 0.0, TAU, 16, Color(0.95, 0.62, 0.22, alpha), 2.0, true)
		if phase < 0.35:
			draw_circle(burst_pos, 4.0 * (1.0 - phase * 2.0), Color(1.0, 0.88, 0.55, alpha))


func _draw_artillery_arcs() -> void:
	for arty: SimTypes.MapNode in engine.graph.get_nodes_by_type(SimTypes.NodeType.ARTILLERY):
		var fl: String = arty.flank if not arty.flank.is_empty() else "NORTH"
		if not engine.arty_support_by_flank.get(fl, false):
			continue
		for sector: SimTypes.MapNode in engine.graph.get_nodes_by_type(SimTypes.NodeType.FRONT_SECTOR):
			if (fl != "ALL" and sector.flank != fl) or sector.intensity == SimTypes.Intensity.LOW:
				continue
			var target_pos: Vector2 = sector.position + Vector2(110.0, 0.0)
			var mid: Vector2 = (arty.position + target_pos) * 0.5 + Vector2(0.0, -34.0)
			var prev_p: Vector2 = arty.position
			var pulse_alpha: float = 0.20 + 0.16 * (0.5 + 0.5 * sin(_anim_time * 4.5))
			var arc_col: Color = Color(0.85, 0.64, 0.25, pulse_alpha)
			for step_i: int in range(1, 13):
				var t: float = float(step_i) / 12.0
				var p: Vector2 = arty.position.lerp(mid, t).lerp(mid.lerp(target_pos, t), t)
				if step_i % 2 == 1:
					draw_line(prev_p, p, arc_col, 1.8, true)
				prev_p = p


func _draw_rail_line() -> void:
	if _rail_pts.size() < 2:
		return
	draw_polyline(_rail_pts, Color("#242621"), 6.0, true)
	for i: int in range(_rail_pts.size() - 1):
		var a: Vector2 = _rail_pts[i]
		var b: Vector2 = _rail_pts[i + 1]
		draw_dashed_line(a, b, Color("#dcd7c4"), 3.2, 10.0)
		var dir: Vector2 = (b - a).normalized()
		var perp: Vector2 = Vector2(-dir.y, dir.x) * 5.0
		var seg_len: float = a.distance_to(b)
		var d: float = 10.0
		while d < seg_len:
			var p: Vector2 = a + dir * d
			draw_line(p - perp, p + perp, Color("#242621"), 2.0, true)
			d += 14.0


func _draw_edges() -> void:
	var font_mono: Font = _font_mono if _font_mono != null else ThemeDB.fallback_font
	for edge: SimTypes.RoadEdge in engine.graph.edges:
		var pts: PackedVector2Array = _edge_baked.get(edge.id, PackedVector2Array())
		if pts.size() < 2:
			continue

		var passable: bool = engine.graph.is_edge_passable(edge)
		var wear_t: float = clampf(edge.wear, 0.0, 1.0)
		var is_hovered: bool = (edge.id == _hovered_edge_id)
		var bridge_broken: bool = engine.graph.is_edge_bridge_damaged(edge)

		if not passable:
			for i: int in range(pts.size() - 1):
				draw_dashed_line(pts[i], pts[i + 1], Color(0.32, 0.25, 0.22, 0.48), 2.5, 8.0)
			continue

		if edge.frontline_danger:
			_draw_edge_danger_hatching(pts)

		match edge.road_type:
			SimTypes.RoadType.HIGHWAY:
				var casing_w: float = 10.0 if is_hovered else 8.4
				var core_w: float = 5.2 if is_hovered else 4.6
				var core_col: Color = Color("#e3d8b8").lerp(Color("#b55e2e"), wear_t)
				if bridge_broken:
					core_col = Color("#944135")
				draw_polyline(pts, Color("#332f26"), casing_w, true)
				draw_polyline(pts, core_col, core_w, true)
				draw_polyline(pts, Color("#857b63"), 1.0, true)
			SimTypes.RoadType.SECONDARY:
				var casing_w2: float = 7.4 if is_hovered else 6.0
				var core_w2: float = 3.8 if is_hovered else 3.2
				var core_col2: Color = Color("#c8bda0").lerp(Color("#a84d2c"), wear_t)
				if bridge_broken:
					core_col2 = Color("#8c3c31")
				draw_polyline(pts, Color("#3f3a30"), casing_w2, true)
				draw_polyline(pts, core_col2, core_w2, true)
			SimTypes.RoadType.DIRT:
				var dirt_col: Color = Color("#634b34").lerp(Color("#9e3322"), wear_t)
				draw_polyline(pts, Color(0.84, 0.79, 0.65, 0.55), 3.6, true)
				for i: int in range(pts.size() - 1):
					draw_dashed_line(pts[i], pts[i + 1], dirt_col, 2.6, 7.0)

		var mid_pt: Vector2 = pts[int(pts.size() / 2)]
		if edge.mined and _ico_mine != null:
			draw_circle(mid_pt, 10.0, Color("#3b1512F0"))
			draw_arc(mid_pt, 10.0, 0.0, TAU, 16, COL_CRITICAL, 1.6, true)
			draw_texture_rect(_ico_mine, Rect2(mid_pt - Vector2(7.0, 7.0), Vector2(14.0, 14.0)), false, COL_FUEL)
		elif edge.wear >= 0.35 and _ico_hazard != null:
			draw_circle(mid_pt, 8.5, Color("#232720E6"))
			draw_arc(mid_pt, 8.5, 0.0, TAU, 16, COL_FUEL, 1.4, true)
			draw_texture_rect(_ico_hazard, Rect2(mid_pt - Vector2(6.0, 6.0), Vector2(12.0, 12.0)), false, COL_FUEL)

		if show_distances and not is_targeting():
			var speed_kmh: float = engine.graph.get_edge_effective_speed_kmh(edge, engine.weather, _preview_convoy_type)
			var txt: String = "%.0f км • %.0f км/ч" % [edge.distance_km, speed_kmh]
			var offset_y: float = -16.0 if (edge.wear >= 0.35 or edge.mined) else -8.0
			_draw_plate_label(font_mono, mid_pt + Vector2(0.0, offset_y), txt, 11, COL_TEXT_LIGHT, COL_PLATE_BG, COL_PLATE_BORDER)


func _draw_active_routes() -> void:
	for convoy: Convoy in engine.convoys:
		if convoy.state != SimTypes.ConvoyState.MOVING or convoy.route_nodes.size() < 2:
			continue
		var is_related: bool = (
			convoy.origin_node_id == selected_node_id
			or convoy.destination_node_id == selected_node_id
		)
		if not show_routes and not is_related:
			continue

		var route_col: Color = Color(0.18, 0.45, 0.76, 0.78 if is_related else 0.38)
		if convoy.order_mode == SimTypes.OrderMode.REDEPLOY:
			route_col = Color(0.62, 0.65, 0.58, 0.65)
		var route_w: float = 3.0 if is_related else 2.0
		for i: int in range(convoy.route_segment_index, convoy.route_nodes.size() - 1):
			var u: String = convoy.route_nodes[i]
			var v: String = convoy.route_nodes[i + 1]
			var edge: SimTypes.RoadEdge = engine.graph.get_edge_between(u, v)
			if edge == null:
				continue
			var pts: PackedVector2Array = _edge_baked.get(edge.id, PackedVector2Array())
			if pts.size() >= 2:
				for p_idx: int in range(pts.size() - 1):
					draw_dashed_line(pts[p_idx], pts[p_idx + 1], route_col, route_w, 8.0)


func _draw_targeting_preview() -> void:
	if not is_targeting():
		return
	var orig_node: SimTypes.MapNode = engine.graph.get_node(_targeting_origin_id)
	if orig_node == null:
		return

	var pulse_r: float = 34.0 + 4.0 * sin(_anim_time * 6.0)
	draw_arc(orig_node.position, pulse_r, 0.0, TAU, 32, COL_FUEL, 2.5, true)

	if _hovered_node_id.is_empty() or _hovered_node_id == _targeting_origin_id:
		return

	var dest_node: SimTypes.MapNode = engine.graph.get_node(_hovered_node_id)
	if dest_node == null or dest_node.owner != SimTypes.Owner.FRIENDLY:
		return

	var font_mono: Font = _font_mono if _font_mono != null else ThemeDB.fallback_font
	var val: Dictionary = engine.validate_dispatch(
		_targeting_origin_id, _hovered_node_id, _preview_convoy_type, _preview_cargo_pref, _preview_order_mode
	)
	var is_ok: bool = bool(val.get("ok", false))
	var tip_pos: Vector2 = dest_node.position + Vector2(0.0, -44.0)

	if not is_ok:
		draw_arc(dest_node.position, 32.0, 0.0, TAU, 32, COL_CRITICAL, 2.5, true)
		_draw_plate_label(font_mono, tip_pos, str(val.get("reason", "Недопустимо")), 11, COL_CRITICAL, Color("#3b1512F0"), COL_CRITICAL)
		return

	var path: Array[String] = engine.graph.find_path(_targeting_origin_id, _hovered_node_id, engine.weather, _preview_convoy_type)
	if path.size() < 2:
		return

	for i: int in range(path.size() - 1):
		var edge: SimTypes.RoadEdge = engine.graph.get_edge_between(path[i], path[i + 1])
		if edge == null:
			continue
		var pts: PackedVector2Array = _edge_baked.get(edge.id, PackedVector2Array())
		if pts.size() >= 2:
			draw_polyline(pts, Color(0.15, 0.17, 0.13, 0.75), 9.0, true)
			draw_polyline(pts, COL_FUEL, 4.5, true)

	draw_arc(dest_node.position, 32.0, 0.0, TAU, 32, COL_FUEL, 2.5, true)

	var dist_km: float = engine.graph.compute_path_distance_km(path)
	var eta_h: float = engine.graph.compute_path_time_hours(path, engine.weather, _preview_convoy_type)
	var fuel_cost: float = dist_km * engine.config.convoy_fuel_burn_per_km
	if _preview_order_mode == SimTypes.OrderMode.REDEPLOY:
		eta_h /= 1.25
		fuel_cost *= 0.5

	var warn_info: Dictionary = engine.graph.path_has_warnings(path, engine.weather)
	var mode_tag: String = " (Передисл.)" if _preview_order_mode == SimTypes.OrderMode.REDEPLOY else ""
	var line1: String = "%.0f км • ETA %.1f ч • Бак -%.2fт%s" % [dist_km, eta_h, fuel_cost, mode_tag]
	_draw_plate_label(font_mono, tip_pos, line1, 11, COL_TEXT_LIGHT, Color("#1b1f18F0"), COL_FUEL)

	if dest_node.is_bridge and dest_node.damaged:
		_draw_plate_label(font_mono, tip_pos + Vector2(0.0, -18.0), "Ремонт моста (Инж. + ЗП)!", 11, COL_FUEL, Color("#2b1e12F0"), COL_FUEL)
	elif bool(warn_info.get("has_mined_road", false)):
		var msg_m: String = "Разминирование по пути (Инж.)!" if _preview_convoy_type == SimTypes.ConvoyType.ENGINEER else "ЗАМИНИРОВАНО! Нужна Инж. колонна!"
		_draw_plate_label(font_mono, tip_pos + Vector2(0.0, -18.0), msg_m, 11, COL_CRITICAL, Color("#3b1512F0"), COL_CRITICAL)
	elif bool(warn_info.get("has_damaged_bridge", false)):
		_draw_plate_label(font_mono, tip_pos + Vector2(0.0, -18.0), "ВНИМАНИЕ: поврежд. мост!", 11, COL_CRITICAL, Color("#3b1512F0"), COL_CRITICAL)
	elif bool(warn_info.get("has_bad_dirt", false)):
		_draw_plate_label(font_mono, tip_pos + Vector2(0.0, -18.0), "Грязь / распутица!", 11, COL_FUEL, Color("#2b1e12F0"), COL_FUEL)
	elif bool(warn_info.get("has_frontline_danger", false)) and _preview_convoy_type != SimTypes.ConvoyType.ARMORED:
		_draw_plate_label(font_mono, tip_pos + Vector2(0.0, -18.0), "ВНИМАНИЕ: обстрел дороги! (лучше БТР/ночь)", 11, COL_FUEL, Color("#3b1a12F0"), COL_CRITICAL)


func _draw_threat_overlay() -> void:
	var font_mono: Font = _font_mono if _font_mono != null else ThemeDB.fallback_font
	for node: SimTypes.MapNode in engine.graph.get_all_nodes():
		if not node.is_vulnerable:
			continue
		var high_risk: bool = node.signature >= 60.0 or node.pending_strike_ticks >= 0
		if not show_threat_layer and not high_risk:
			continue
		var pulse_r: float = 34.0 + 10.0 * (0.5 + 0.5 * sin(_anim_time * 3.5))
		var ring_col: Color = COL_CRITICAL if node.signature >= 75.0 or node.pending_strike_ticks >= 0 else COL_FUEL
		draw_arc(node.position, pulse_r, 0.0, TAU, 32, Color(ring_col.r, ring_col.g, ring_col.b, 0.55), 1.8, true)
		if show_threat_layer:
			_draw_plate_label(font_mono, node.position + Vector2(0.0, -32.0), "СИГН %.0f%%" % node.signature, 11, ring_col, COL_PLATE_BG, ring_col)


func _draw_nodes() -> void:
	var font_b: Font = _font_bold if _font_bold != null else ThemeDB.fallback_font
	var font_mono: Font = _font_mono if _font_mono != null else ThemeDB.fallback_font

	for node: SimTypes.MapNode in engine.graph.get_all_nodes():
		var p: Vector2 = node.position
		var is_selected: bool = (node.id == selected_node_id)

		if is_selected:
			draw_arc(p, 30.0, 0.0, TAU, 36, COL_FUEL, 2.5, true)
			draw_arc(p, 34.0, 0.0, TAU, 36, Color(COL_INK.r, COL_INK.g, COL_INK.b, 0.65), 1.4, true)

		var plate_y: float = p.y + 30.0
		var display_title: String = node.display_name

		match node.node_type:
			SimTypes.NodeType.RAILHEAD:
				_draw_railhead_marker(p, node)
				plate_y = p.y + 31.0
			SimTypes.NodeType.DEPOT, SimTypes.NodeType.FIELD_DEPOT:
				_draw_depot_marker(p, node, font_mono)
				plate_y = p.y + 31.0
			SimTypes.NodeType.JUNCTION:
				_draw_junction_marker(p, node, font_mono)
				plate_y = p.y + 26.0
			SimTypes.NodeType.ARTILLERY:
				_draw_artillery_marker(p, node, font_b, font_mono)
				plate_y = p.y + 30.0
			SimTypes.NodeType.FRONT_SECTOR:
				_draw_front_marker(p, node, font_b, font_mono)
				var fu: Dictionary = _front_units.get(node.id, {})
				var unit_code: String = str(fu.get("code", ""))
				if not unit_code.is_empty():
					display_title = "%s • %s" % [unit_code, node.display_name.get_slice("(", 1).rstrip(")")]
				plate_y = p.y + 30.0
			SimTypes.NodeType.OBJECTIVE:
				_draw_objective_marker(p, node, font_mono)
				plate_y = p.y + 31.0

		var idle_here: int = engine.get_idle_convoys_at(node.id).size()
		if idle_here > 0:
			var badge_pos: Vector2 = p + Vector2(20.0, -20.0)
			draw_circle(badge_pos, 10.5, Color("#232720"))
			draw_arc(badge_pos, 10.5, 0.0, TAU, 18, COL_FRIENDLY, 1.8, true)
			_draw_centered_text(font_mono, badge_pos + Vector2(0.0, 4.0), "%d" % idle_here, 12, COL_TEXT_LIGHT)

		if node.camouflaged:
			_draw_plate_label(font_mono, p + Vector2(0.0, -26.0), "МАСК", 9, COL_AMMO, Color("#182115E6"), COL_AMMO)
		elif (node.node_type == SimTypes.NodeType.DEPOT or node.node_type == SimTypes.NodeType.FIELD_DEPOT) and node.active_loading_count >= node.loading_slots:
			_draw_plate_label(font_mono, p + Vector2(-24.0, -24.0), "ОЧЕР", 9, COL_FUEL, Color("#2b1e12E6"), COL_FUEL)

		var waiting_night_here: int = 0
		for c: Convoy in engine.convoys:
			if c.current_node_id == node.id and c.is_waiting_night:
				waiting_night_here += 1
		if waiting_night_here > 0:
			var moon_pos: Vector2 = p + Vector2(-20.0, 18.0)
			draw_circle(moon_pos, 8.5, Color("#1b2230E6"))
			draw_arc(moon_pos, 8.5, 0.0, TAU, 16, Color("#8fb4dc"), 1.3, true)
			_draw_centered_text(font_mono, moon_pos + Vector2(0.0, 3.5), "☾", 10, Color("#8fb4dc"))

		_draw_plate_label(font_b, Vector2(p.x, plate_y), display_title, 12, COL_TEXT_LIGHT, COL_PLATE_BG, COL_PLATE_BORDER)
		if node.owner == SimTypes.Owner.FRIENDLY:
			_draw_node_bars(node, Vector2(p.x - 27.0, plate_y + 10.0))


func _draw_railhead_marker(p: Vector2, node: SimTypes.MapNode) -> void:
	var rim: Color = COL_FRIENDLY
	if node.is_vulnerable and node.signature >= 60.0:
		rim = COL_FUEL
	if node.pending_strike_ticks >= 0:
		rim = COL_CRITICAL
	draw_circle(p, 19.0, Color("#232720"))
	draw_arc(p, 19.0, 0.0, TAU, 28, rim, 2.5, true)
	draw_arc(p, 15.5, 0.0, TAU, 24, Color("#607285"), 1.0, true)
	if node.is_vulnerable and node.signature > 1.0:
		draw_arc(p, 23.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(node.signature / 100.0, 0.0, 1.0), 28, COL_FUEL if node.signature < 75.0 else COL_CRITICAL, 2.5, true)
	if _ico_rail != null:
		draw_texture_rect(_ico_rail, Rect2(p - Vector2(10.0, 10.0), Vector2(20.0, 20.0)), false, COL_TEXT_LIGHT)


func _draw_edge_danger_hatching(pts: PackedVector2Array) -> void:
	var danger_col: Color = Color(0.84, 0.34, 0.22, 0.58)
	var acc: float = 0.0
	for i: int in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var seg_len: float = a.distance_to(b)
		if seg_len < 1.0:
			continue
		var dir: Vector2 = (b - a) / seg_len
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		var d: float = 10.0 - acc
		while d < seg_len:
			var p: Vector2 = a + dir * d
			draw_line(p + perp * 6.0, p + perp * 11.0 + dir * 3.0, danger_col, 1.5, true)
			draw_line(p - perp * 6.0, p - perp * 11.0 + dir * 3.0, danger_col, 1.5, true)
			d += 18.0
		acc = fmod(acc + seg_len, 18.0)


func _draw_depot_marker(p: Vector2, node: SimTypes.MapNode, font_mono: Font) -> void:
	var is_field: bool = (node.node_type == SimTypes.NodeType.FIELD_DEPOT)
	var rim_col: Color = Color("#8fb868") if is_field else COL_AMMO
	if node.pending_strike_ticks >= 0:
		rim_col = COL_CRITICAL
	elif node.signature >= 60.0:
		rim_col = COL_FUEL

	draw_circle(p, 17.0, Color("#232720"))
	if is_field:
		_draw_dashed_circle(p, 17.0, rim_col, 2.0, 14)
	else:
		draw_arc(p, 17.0, 0.0, TAU, 28, rim_col, 2.2, true)
	var ico: Texture2D = _ico_tent if is_field else _ico_depot
	if ico != null:
		draw_texture_rect(ico, Rect2(p - Vector2(9.0, 9.0), Vector2(18.0, 18.0)), false, COL_TEXT_LIGHT)

	var sig_ratio: float = clampf(node.signature / 100.0, 0.0, 1.0)
	if sig_ratio > 0.01:
		var sig_col: Color = COL_FUEL if node.signature < 75.0 else COL_CRITICAL
		draw_arc(p, 22.0, -PI * 0.5, -PI * 0.5 + TAU * sig_ratio, 32, sig_col, 2.8, true)

	if node.pack_ticks_remaining > 0:
		var pack_ratio: float = 1.0 - clampf(float(node.pack_ticks_remaining) / float(maxi(1, node.pack_ticks_total)), 0.0, 1.0)
		_draw_mini_bar(p + Vector2(-20.0, -28.0), 40.0, 4.0, pack_ratio, COL_FUEL)
		_draw_plate_label(font_mono, p + Vector2(0.0, -34.0), "СВОРАЧ.", 9, COL_FUEL, Color("#232720E6"), COL_FUEL)
	elif node.signature >= 75.0 or node.pending_strike_ticks >= 0:
		var badge_p: Vector2 = p + Vector2(-18.0, -18.0)
		draw_circle(badge_p, 9.5, Color("#3b1512"))
		draw_arc(badge_p, 9.5, 0.0, TAU, 16, COL_CRITICAL, 1.5, true)
		if _ico_radar != null:
			draw_texture_rect(_ico_radar, Rect2(badge_p - Vector2(6.5, 6.5), Vector2(13.0, 13.0)), false, COL_CRITICAL)


func _draw_dashed_circle(center: Vector2, radius: float, col: Color, width: float, segs: int = 12) -> void:
	for i: int in range(segs):
		if i % 2 == 1:
			continue
		var a0: float = (float(i) / float(segs)) * TAU
		var a1: float = (float(i + 1) / float(segs)) * TAU
		draw_arc(center, radius, a0, a1, 4, col, width, true)


func _draw_junction_marker(p: Vector2, node: SimTypes.MapNode, font_mono: Font) -> void:
	var is_bridge: bool = node.is_bridge or _bridge_nodes.get(node.id, false)
	var rim: Color = Color("#d9c89e") if is_bridge else Color("#8f9482")
	var bg_col: Color = Color("#282c23")
	if node.damaged:
		rim = COL_CRITICAL
		bg_col = Color("#3b1512")
	elif node.can_deploy_depot:
		rim = COL_FUEL if (node.deploy_requested or node.deploy_build_ticks_remaining > 0) else Color("#9ab878")

	if node.can_deploy_depot and not node.damaged:
		_draw_dashed_circle(p, 19.0, Color(rim.r, rim.g, rim.b, 0.85), 1.6, 14)

	draw_circle(p, 12.0, bg_col)
	draw_arc(p, 12.0, 0.0, TAU, 20, rim, 2.0, true)

	if node.damaged:
		var pulse: float = 17.0 + 4.0 * (0.5 + 0.5 * sin(_anim_time * 5.0))
		draw_arc(p, pulse, 0.0, TAU, 24, Color(COL_CRITICAL.r, COL_CRITICAL.g, COL_CRITICAL.b, 0.7), 1.8, true)
		if _ico_broken != null:
			draw_texture_rect(_ico_broken, Rect2(p - Vector2(7.5, 7.5), Vector2(15.0, 15.0)), false, COL_CRITICAL)
		_draw_plate_label(font_mono, p + Vector2(0.0, -21.0), "МОСТ %.0f/%.0fт" % [node.repair_progress_parts, node.repair_cost_parts], 10, COL_CRITICAL, Color("#2b1210E6"), COL_CRITICAL)
	elif is_bridge:
		draw_line(p + Vector2(-9.0, -5.0), p + Vector2(9.0, -5.0), rim, 2.0, true)
		draw_line(p + Vector2(-9.0, 5.0), p + Vector2(9.0, 5.0), rim, 2.0, true)
	elif node.can_deploy_depot and _ico_tent != null:
		draw_texture_rect(_ico_tent, Rect2(p - Vector2(7.0, 7.0), Vector2(14.0, 14.0)), false, rim)
	elif _ico_crossroad != null:
		draw_texture_rect(_ico_crossroad, Rect2(p - Vector2(6.5, 6.5), Vector2(13.0, 13.0)), false, COL_TEXT_LIGHT)

	if node.can_deploy_depot and not node.damaged:
		if node.deploy_build_ticks_remaining > 0:
			var b_ratio: float = 1.0 - clampf(float(node.deploy_build_ticks_remaining) / float(maxi(1, node.deploy_build_ticks_total)), 0.0, 1.0)
			_draw_mini_bar(p + Vector2(-20.0, -28.0), 40.0, 4.0, b_ratio, COL_AMMO)
			_draw_plate_label(font_mono, p + Vector2(0.0, -34.0), "СТРОЙКА %d%%" % int(round(b_ratio * 100.0)), 9, COL_AMMO, Color("#1b2218E6"), COL_AMMO)
		elif node.deploy_progress_parts > 0.1 or node.deploy_requested:
			_draw_plate_label(font_mono, p + Vector2(0.0, -25.0), "СКЛАД %.0f/%.0fт" % [node.deploy_progress_parts, node.deploy_cost_parts], 9, COL_FUEL, Color("#232720E6"), COL_FUEL)


func _draw_artillery_marker(p: Vector2, node: SimTypes.MapNode, font_b: Font, font_mono: Font) -> void:
	var fl: String = node.flank if not node.flank.is_empty() else "NORTH"
	var active: bool = engine.arty_support_by_flank.get(fl, false)
	if active:
		var glow_a: float = 0.22 + 0.14 * sin(_anim_time * 5.0)
		draw_circle(p, 26.0, Color(0.85, 0.64, 0.25, glow_a))

	var rect: Rect2 = Rect2(p - Vector2(19.0, 13.0), Vector2(38.0, 26.0))
	draw_rect(rect, COL_FRIENDLY, true)
	var border_col: Color = Color("#f0c248") if node.equipment_tier >= 2 else (COL_FUEL if active else Color("#1a2b40"))
	draw_rect(rect, border_col, false, 2.5 if node.equipment_tier >= 2 else 2.2)
	if _ico_mortar != null:
		draw_texture_rect(_ico_mortar, Rect2(p - Vector2(9.0, 9.0), Vector2(18.0, 18.0)), false, COL_TEXT_LIGHT)
	_draw_centered_text(font_b, p + Vector2(0.0, -16.0), "II", 12, COL_INK)
	_draw_unit_tier_badge(p, node, font_mono)


func _draw_front_marker(p: Vector2, node: SimTypes.MapNode, font_b: Font, font_mono: Font) -> void:
	var border_col: Color = Color("#1a2b40")
	if node.integrity < 35.0:
		border_col = COL_CRITICAL
	elif node.integrity < 70.0:
		border_col = COL_FUEL
	elif node.equipment_tier >= 2:
		border_col = Color("#f0c248")

	var rect: Rect2 = Rect2(p - Vector2(21.0, 14.0), Vector2(42.0, 28.0))
	draw_rect(rect, COL_FRIENDLY, true)
	draw_rect(rect, border_col, false, 2.6 if node.equipment_tier >= 2 else 2.2)

	var fu: Dictionary = _front_units.get(node.id, {})
	var sym: String = str(fu.get("symbol", "INFANTRY"))
	if sym == "ARMOR":
		_draw_ellipse_outline(p, 11.0, 6.0, COL_TEXT_LIGHT, 1.8)
	else:
		draw_line(rect.position + Vector2(2.0, 2.0), rect.end - Vector2(2.0, 2.0), COL_TEXT_LIGHT, 1.7, true)
		draw_line(Vector2(rect.end.x - 2.0, rect.position.y + 2.0), Vector2(rect.position.x + 2.0, rect.end.y - 2.0), COL_TEXT_LIGHT, 1.7, true)

	_draw_centered_text(font_b, p + Vector2(0.0, -17.0), "II", 12, COL_INK)
	_draw_unit_tier_badge(p, node, font_mono)

	var inten_col: Color = COL_AMMO
	var inten_txt: String = "Н"
	match node.intensity:
		SimTypes.Intensity.MEDIUM:
			inten_col = COL_FUEL
			inten_txt = "С"
		SimTypes.Intensity.HIGH:
			inten_col = COL_CRITICAL
			inten_txt = "В"
	var ipos: Vector2 = p + Vector2(-24.0, -14.0)
	draw_circle(ipos, 8.5, Color("#232720"))
	draw_arc(ipos, 8.5, 0.0, TAU, 16, inten_col, 1.5, true)
	_draw_centered_text(font_b, ipos + Vector2(0.0, 4.0), inten_txt, 11, inten_col)

	if node.wounded >= 4.0:
		var w_pos: Vector2 = p + Vector2(-24.0, 10.0)
		var w_col: Color = COL_CRITICAL if node.wounded >= 24.0 else COL_FUEL
		draw_circle(w_pos, 9.0, Color("#232720E6"))
		draw_arc(w_pos, 9.0, 0.0, TAU, 16, w_col, 1.4, true)
		if _ico_medevac != null:
			draw_texture_rect(_ico_medevac, Rect2(w_pos - Vector2(6.0, 6.0), Vector2(12.0, 12.0)), false, w_col)
		_draw_centered_text(font_mono, w_pos + Vector2(-14.0, 4.0), "%d" % int(round(node.wounded)), 10, w_col)


func _draw_unit_tier_badge(p: Vector2, node: SimTypes.MapNode, font_mono: Font) -> void:
	if node.equipment_tier >= 2:
		var badge_p: Vector2 = p + Vector2(23.0, 11.0)
		draw_circle(badge_p, 8.5, Color("#242014F2"))
		draw_arc(badge_p, 8.5, 0.0, TAU, 16, Color("#f0c248"), 1.6, true)
		if _ico_star != null:
			draw_texture_rect(_ico_star, Rect2(badge_p - Vector2(5.5, 5.5), Vector2(11.0, 11.0)), false, Color("#f0c248"))
		_draw_plate_label(font_mono, p + Vector2(23.0, -2.0), "II", 9, Color("#f0c248"), Color("#242014E6"), Color("#f0c248"))
	elif node.reequip_ticks_remaining > 0:
		_draw_plate_label(font_mono, p + Vector2(0.0, -28.0), "МОДЕРН...", 9, Color("#f0c248"), Color("#242014E6"), Color("#f0c248"))
	elif node.reequip_progress > 0.1:
		_draw_plate_label(font_mono, p + Vector2(0.0, -28.0), "ПЕР %.0f/30т" % node.reequip_progress, 9, Color("#f0c248"), Color("#232720E6"), Color("#f0c248"))


func _draw_objective_marker(p: Vector2, node: SimTypes.MapNode, font_mono: Font) -> void:
	if node.owner == SimTypes.Owner.FRIENDLY:
		draw_circle(p, 19.0, Color("#1f2e3d"))
		draw_arc(p, 19.0, 0.0, TAU, 28, COL_FRIENDLY, 2.5, true)
		if _ico_flag != null:
			draw_texture_rect(_ico_flag, Rect2(p - Vector2(10.0, 10.0), Vector2(20.0, 20.0)), false, COL_TEXT_LIGHT)
	else:
		draw_circle(p, 19.0, Color("#3b1512E6"))
		draw_arc(p, 19.0, 0.0, TAU, 28, COL_ENEMY, 2.2, true)
		if node.capture_progress > 0.1:
			draw_arc(p, 24.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(node.capture_progress / 100.0, 0.0, 1.0), 32, COL_FUEL, 3.2, true)
			_draw_plate_label(font_mono, p + Vector2(0.0, -28.0), "%d%%" % int(round(node.capture_progress)), 10, COL_FUEL, Color("#232720E6"), COL_FUEL)
		if _ico_target != null:
			draw_texture_rect(_ico_target, Rect2(p - Vector2(10.0, 10.0), Vector2(20.0, 20.0)), false, Color("#f7d9d5"))


func _draw_node_bars(node: SimTypes.MapNode, origin: Vector2) -> void:
	var bar_w: float = 54.0
	var bar_h: float = 3.5
	var y_off: float = 0.0

	if node.node_type == SimTypes.NodeType.FRONT_SECTOR:
		var int_ratio: float = clampf(node.integrity / 100.0, 0.0, 1.0)
		var int_col: Color = COL_AMMO if int_ratio >= 0.7 else (COL_FUEL if int_ratio >= 0.35 else COL_CRITICAL)
		_draw_mini_bar(origin + Vector2(0.0, y_off), bar_w, bar_h + 1.0, int_ratio, int_col)
		y_off += 6.5

	if node.has_storage():
		var fuel_ratio: float = clampf(node.get_stock(SimTypes.ResourceType.FUEL) / maxf(1.0, node.get_capacity(SimTypes.ResourceType.FUEL)), 0.0, 1.0)
		var ammo_ratio: float = clampf(node.get_stock(SimTypes.ResourceType.AMMO) / maxf(1.0, node.get_capacity(SimTypes.ResourceType.AMMO)), 0.0, 1.0)
		_draw_mini_bar(origin + Vector2(0.0, y_off), bar_w, bar_h, fuel_ratio, COL_FUEL)
		y_off += 5.0
		_draw_mini_bar(origin + Vector2(0.0, y_off), bar_w, bar_h, ammo_ratio, COL_AMMO)
		if node.node_type == SimTypes.NodeType.FRONT_SECTOR:
			y_off += 5.0
			var prov_ratio: float = clampf(node.get_stock(SimTypes.ResourceType.PROVISIONS) / maxf(1.0, node.get_capacity(SimTypes.ResourceType.PROVISIONS)), 0.0, 1.0)
			_draw_mini_bar(origin + Vector2(0.0, y_off), bar_w, bar_h, prov_ratio, Color("#6ab09a"))


func _draw_mini_bar(pos: Vector2, w: float, h: float, ratio: float, fill_col: Color) -> void:
	draw_rect(Rect2(pos - Vector2(1.0, 1.0), Vector2(w + 2.0, h + 2.0)), Color("#1a1e18CC"), true)
	if ratio > 0.001:
		draw_rect(Rect2(pos, Vector2(w * ratio, h)), fill_col, true)


func _draw_convoys() -> void:
	var font_mono: Font = _font_mono if _font_mono != null else ThemeDB.fallback_font
	for convoy: Convoy in engine.convoys:
		if convoy.state != SimTypes.ConvoyState.MOVING:
			continue

		var sample: Dictionary = _sample_convoy_transform(convoy)
		var pos: Vector2 = sample["pos"]
		var tangent: Vector2 = sample["tangent"]
		var angle: float = tangent.angle()
		if absf(angle) > PI * 0.5:
			angle += PI

		var type_ico: Texture2D = _ico_truck
		var rim_col: Color = COL_FRIENDLY
		match convoy.convoy_type:
			SimTypes.ConvoyType.TANKER:
				type_ico = _ico_tanker
				rim_col = COL_FUEL
			SimTypes.ConvoyType.ENGINEER:
				type_ico = _ico_engineer
				rim_col = COL_AMMO
			SimTypes.ConvoyType.ARMORED:
				type_ico = _ico_apc
				rim_col = Color("#7ec8e3")

		if convoy.order_mode == SimTypes.OrderMode.REDEPLOY:
			rim_col = Color("#9fa694")
		if convoy.carried_wounded >= 1.0:
			rim_col = COL_CRITICAL

		var truck_col: Color = COL_TEXT_LIGHT
		if convoy.fuel_tank <= 0.01:
			truck_col = COL_CRITICAL
			rim_col = COL_CRITICAL
		elif convoy.fuel_tank < convoy.fuel_tank_capacity * 0.25:
			truck_col = COL_FUEL

		draw_set_transform(pos, angle, Vector2.ONE)
		var badge_rect: Rect2 = Rect2(Vector2(-12.0, -9.0), Vector2(24.0, 18.0))
		draw_rect(badge_rect, Color("#1f231cf0"), true)
		draw_rect(badge_rect, rim_col, false, 1.8 if convoy.convoy_type == SimTypes.ConvoyType.ARMORED else 1.6)
		if type_ico != null:
			draw_texture_rect(type_ico, Rect2(Vector2(-8.0, -7.0), Vector2(16.0, 14.0)), false, truck_col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		var cargo_ratio: float = clampf(convoy.get_total_cargo() / maxf(1.0, convoy.cargo_capacity), 0.0, 1.0)
		var bar_origin: Vector2 = pos + Vector2(-11.0, 11.0)
		draw_rect(Rect2(bar_origin, Vector2(22.0, 3.0)), Color("#151812"), true)
		if cargo_ratio > 0.01:
			draw_rect(Rect2(bar_origin, Vector2(22.0 * cargo_ratio, 3.0)), COL_AMMO, true)

		if convoy.hp < 99.5:
			var hp_ratio: float = clampf(convoy.hp / maxf(1.0, convoy.max_hp), 0.0, 1.0)
			var hp_origin: Vector2 = pos + Vector2(-11.0, 15.0)
			var hp_col: Color = COL_CRITICAL if hp_ratio < 0.45 else COL_FUEL
			draw_rect(Rect2(hp_origin, Vector2(22.0, 3.0)), Color("#151812"), true)
			if hp_ratio > 0.01:
				draw_rect(Rect2(hp_origin, Vector2(22.0 * hp_ratio, 3.0)), hp_col, true)

		var tag: String = "%s%s" % [convoy.callsign, "∅" if convoy.order_mode == SimTypes.OrderMode.REDEPLOY else ""]
		_draw_plate_label(font_mono, pos + Vector2(0.0, -14.0), tag, 10, COL_TEXT_LIGHT, Color("#1f231cd9"), rim_col)


func _sample_edge_point_raw(convoy: Convoy) -> Dictionary:
	var fallback_pos: Vector2 = convoy.get_world_position(engine.graph)
	var fallback_tan: Vector2 = convoy.get_heading_vector(engine.graph)
	if convoy.state != SimTypes.ConvoyState.MOVING or convoy.route_segment_index < 0 or convoy.route_segment_index >= convoy.route_nodes.size() - 1:
		return {
			"edge_id": "",
			"forward": true,
			"progress_t": 0.0,
			"pos": fallback_pos,
			"tangent": fallback_tan,
		}

	var u: String = convoy.route_nodes[convoy.route_segment_index]
	var v: String = convoy.route_nodes[convoy.route_segment_index + 1]
	var edge: SimTypes.RoadEdge = engine.graph.get_edge_between(u, v)
	if edge == null or not _edge_curves.has(edge.id):
		return {
			"edge_id": "",
			"forward": true,
			"progress_t": 0.0,
			"pos": fallback_pos,
			"tangent": fallback_tan,
		}

	var curve: Curve2D = _edge_curves[edge.id]
	var baked_len: float = curve.get_baked_length()
	if baked_len <= 0.01:
		return {
			"edge_id": edge.id,
			"forward": true,
			"progress_t": 0.0,
			"pos": fallback_pos,
			"tangent": fallback_tan,
		}

	var t: float = clampf(convoy.segment_progress_km / maxf(0.01, edge.distance_km), 0.0, 1.0)
	var forward: bool = (u == edge.from_id)
	var dist_along: float = t * baked_len if forward else (1.0 - t) * baked_len
	var pos: Vector2 = curve.sample_baked(dist_along)
	var tangent: Vector2 = _sample_curve_tangent(curve, dist_along, baked_len, forward, fallback_tan)

	return {
		"edge_id": edge.id,
		"forward": forward,
		"progress_t": t,
		"pos": pos,
		"tangent": tangent,
	}


func _sample_curve_tangent(curve: Curve2D, dist_along: float, baked_len: float, forward: bool, fallback_tan: Vector2) -> Vector2:
	var d0: float = clampf(dist_along - 4.0, 0.0, baked_len)
	var d1: float = clampf(dist_along + 4.0, 0.0, baked_len)
	var p0: Vector2 = curve.sample_baked(d0)
	var p1: Vector2 = curve.sample_baked(d1)
	var tangent: Vector2 = (p1 - p0) if forward else (p0 - p1)
	if tangent.length_squared() < 0.001:
		return fallback_tan
	return tangent.normalized()


func _sample_convoy_transform(convoy: Convoy) -> Dictionary:
	var cur: Dictionary = _sample_edge_point_raw(convoy)
	var alpha: float = clampf(tick_alpha, 0.0, 1.0)
	if alpha >= 0.999 or not _prev_convoy_state.has(convoy.id):
		return {"pos": cur["pos"], "tangent": cur["tangent"]}

	var prev: Dictionary = _prev_convoy_state[convoy.id]
	var cur_edge_id: String = str(cur["edge_id"])
	var prev_edge_id: String = str(prev["edge_id"])

	if prev["state"] == SimTypes.ConvoyState.MOVING and not cur_edge_id.is_empty() and cur_edge_id == prev_edge_id and bool(prev["forward"]) == bool(cur["forward"]):
		var curve: Curve2D = _edge_curves[cur_edge_id]
		var baked_len: float = curve.get_baked_length()
		var t_interp: float = lerpf(float(prev["progress_t"]), float(cur["progress_t"]), alpha)
		var forward: bool = bool(cur["forward"])
		var dist_along: float = t_interp * baked_len if forward else (1.0 - t_interp) * baked_len
		var pos: Vector2 = curve.sample_baked(dist_along)
		var tan: Vector2 = _sample_curve_tangent(curve, dist_along, baked_len, forward, cur["tangent"])
		return {"pos": pos, "tangent": tan}

	var prev_pos: Vector2 = prev["pos"]
	var cur_pos: Vector2 = cur["pos"]
	var prev_tan: Vector2 = prev["tangent"]
	var cur_tan: Vector2 = cur["tangent"]
	var blended_tan: Vector2 = prev_tan.lerp(cur_tan, alpha)
	if blended_tan.length_squared() < 0.001:
		blended_tan = cur_tan
	else:
		blended_tan = blended_tan.normalized()
	return {
		"pos": prev_pos.lerp(cur_pos, alpha),
		"tangent": blended_tan,
	}


func _build_edge_curves() -> void:
	_edge_curves.clear()
	_edge_baked.clear()
	if engine == null or engine.graph == null:
		return

	for edge: SimTypes.RoadEdge in engine.graph.edges:
		var node_a: SimTypes.MapNode = engine.graph.get_node(edge.from_id)
		var node_b: SimTypes.MapNode = engine.graph.get_node(edge.to_id)
		if node_a == null or node_b == null:
			continue

		var p0: Vector2 = node_a.position
		var p1: Vector2 = node_b.position
		var chord: Vector2 = p1 - p0
		var chord_len: float = chord.length()
		var normal: Vector2 = Vector2(-chord.y, chord.x).normalized() if chord_len > 1.0 else Vector2.UP

		var h: int = edge.id.hash()
		var sign_val: float = 1.0 if (h & 1) == 0 else -1.0
		var amp_ratio: float = 0.07 + float(absi(h) % 6) * 0.013
		if edge.road_type == SimTypes.RoadType.DIRT:
			amp_ratio += 0.05
		var offset1: Vector2 = normal * (chord_len * amp_ratio * sign_val)
		var offset2: Vector2 = normal * (chord_len * (amp_ratio * 0.65) * sign_val)
		if (h & 2) != 0:
			offset2 = -offset2

		var ctrl1: Vector2 = p0.lerp(p1, 0.33) + offset1
		var ctrl2: Vector2 = p0.lerp(p1, 0.67) + offset2

		var curve: Curve2D = Curve2D.new()
		curve.bake_interval = 8.0
		curve.add_point(p0, Vector2.ZERO, ctrl1 - p0)
		curve.add_point(p1, ctrl2 - p1, Vector2.ZERO)

		_edge_curves[edge.id] = curve
		_edge_baked[edge.id] = curve.get_baked_points()


func _update_dynamic_frontline(delta: float) -> void:
	if engine == null or engine.graph == null or _front_bands.is_empty():
		return
	var changed: bool = false
	for obj: SimTypes.MapNode in engine.graph.get_nodes_by_type(SimTypes.NodeType.OBJECTIVE):
		var target_val: float = 1.0 if obj.owner == SimTypes.Owner.FRIENDLY else 0.0
		var cur_val: float = _band_shift.get(obj.id, 0.0)
		if not is_equal_approx(cur_val, target_val):
			_band_shift[obj.id] = move_toward(cur_val, target_val, delta * 0.7)
			changed = true
	if changed:
		_rebuild_frontline_geometry()


func _rebuild_frontline_geometry() -> void:
	if _front_bands.is_empty():
		return
	var ctrl_pts: PackedVector2Array = PackedVector2Array()
	for band: Dictionary in _front_bands:
		var y_val: float = float(band.get("y", 0.0))
		var bx: float = float(band.get("base_x", 1690.0))
		var cx: float = float(band.get("captured_x", bx))
		var oid: String = str(band.get("obj_id", ""))
		var t: float = _band_shift.get(oid, 0.0) if not oid.is_empty() else 0.0
		ctrl_pts.append(Vector2(lerpf(bx, cx, t), y_val))

	_front_line_pts = _smooth_polyline(ctrl_pts)
	_enemy_polygon.clear()
	if _front_line_pts.size() >= 2:
		for pt: Vector2 in _front_line_pts:
			_enemy_polygon.append(pt)
		var right_x: float = 2700.0
		if engine != null and engine.config != null:
			right_x = maxf(2700.0, engine.config.map_bounds.end.x + 600.0)
		_enemy_polygon.append(Vector2(right_x, 1700.0))
		_enemy_polygon.append(Vector2(right_x, -500.0))


func _load_visual_metadata(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	var vis_raw: Variant = data.get("visual", {})
	if typeof(vis_raw) != TYPE_DICTIONARY:
		return
	var vis: Dictionary = vis_raw

	_front_units.clear()
	var fu_raw: Variant = vis.get("front_units", {})
	if typeof(fu_raw) == TYPE_DICTIONARY:
		var fu_dict: Dictionary = fu_raw
		for k: Variant in fu_dict.keys():
			if typeof(fu_dict[k]) == TYPE_DICTIONARY:
				_front_units[str(k)] = fu_dict[k]

	_bridge_nodes.clear()
	var bn_raw: Variant = vis.get("bridge_nodes", [])
	if typeof(bn_raw) == TYPE_ARRAY:
		for item: Variant in bn_raw:
			_bridge_nodes[str(item)] = true

	_rail_pts = _smooth_polyline(_parse_point_array(vis.get("rail_line", [])))

	_river_curves.clear()
	var rivers_raw: Variant = vis.get("rivers", [])
	if typeof(rivers_raw) == TYPE_ARRAY:
		for r_var: Variant in rivers_raw:
			if typeof(r_var) != TYPE_DICTIONARY:
				continue
			var rd: Dictionary = r_var
			var pts: PackedVector2Array = _parse_point_array(rd.get("points", []))
			var baked: PackedVector2Array = _smooth_polyline(pts)
			_river_curves.append({
				"name": str(rd.get("name", "")),
				"width": float(rd.get("width", 10.0)),
				"baked": baked,
			})

	_front_bands.clear()
	var fb_raw: Variant = vis.get("front_bands", [])
	if typeof(fb_raw) == TYPE_ARRAY:
		for item: Variant in fb_raw:
			if typeof(item) == TYPE_DICTIONARY:
				_front_bands.append(item)

	_enemy_units.clear()
	var eu_raw: Variant = vis.get("enemy_units", [])
	if typeof(eu_raw) == TYPE_ARRAY:
		for eu_var: Variant in eu_raw:
			if typeof(eu_var) == TYPE_DICTIONARY:
				_enemy_units.append(eu_var)


func _parse_point_array(raw: Variant) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	if typeof(raw) != TYPE_ARRAY:
		return out
	var arr: Array = raw
	for item: Variant in arr:
		if typeof(item) == TYPE_ARRAY:
			var pair: Array = item
			if pair.size() >= 2:
				out.append(Vector2(float(pair[0]), float(pair[1])))
	return out


func _smooth_polyline(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var curve: Curve2D = Curve2D.new()
	curve.bake_interval = 10.0
	for i: int in range(pts.size()):
		var prev_p: Vector2 = pts[maxi(0, i - 1)]
		var next_p: Vector2 = pts[mini(pts.size() - 1, i + 1)]
		var tangent: Vector2 = (next_p - prev_p) * 0.25
		curve.add_point(pts[i], -tangent, tangent)
	return curve.get_baked_points()


func _hit_test_node(world_pos: Vector2) -> String:
	var best_id: String = ""
	var best_dist: float = NODE_CLICK_RADIUS
	for node: SimTypes.MapNode in engine.graph.get_all_nodes():
		var d: float = node.position.distance_to(world_pos)
		if d <= best_dist:
			best_dist = d
			best_id = node.id
	return best_id


func _update_hover_state() -> void:
	_hovered_node_id = ""
	_hovered_edge_id = ""
	if engine == null or engine.graph == null:
		return
	var vp: Viewport = get_viewport()
	if vp != null and vp.gui_get_hovered_control() != null:
		return

	var mouse_world: Vector2 = get_global_mouse_position()
	_hovered_node_id = _hit_test_node(mouse_world)
	if not _hovered_node_id.is_empty():
		return

	var best_d: float = EDGE_HOVER_RADIUS
	for edge: SimTypes.RoadEdge in engine.graph.edges:
		var pts: PackedVector2Array = _edge_baked.get(edge.id, PackedVector2Array())
		for i: int in range(pts.size() - 1):
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(mouse_world, pts[i], pts[i + 1])
			var d: float = mouse_world.distance_to(closest)
			if d < best_d:
				best_d = d
				_hovered_edge_id = edge.id


func _draw_centered_text(font: Font, center_pos: Vector2, text: String, size: int, col: Color) -> void:
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	draw_string(font, center_pos - Vector2(text_size.x * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_plate_label(font: Font, center_pos: Vector2, text: String, size: int, text_col: Color, bg_col: Color, border_col: Color) -> void:
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var pad_x: float = 5.0
	var box_w: float = text_size.x + pad_x * 2.0
	var box_h: float = float(size) + 4.0
	var rect: Rect2 = Rect2(Vector2(center_pos.x - box_w * 0.5, center_pos.y - box_h * 0.72), Vector2(box_w, box_h))
	draw_rect(rect, bg_col, true)
	draw_rect(rect, border_col, false, 1.0)
	draw_string(font, Vector2(rect.position.x + pad_x, rect.position.y + box_h - 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, text_col)


func _draw_ellipse_outline(center: Vector2, rx: float, ry: float, col: Color, width: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	var segs: int = 20
	for i: int in range(segs + 1):
		var a: float = (float(i) / float(segs)) * TAU
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, col, width, true)
