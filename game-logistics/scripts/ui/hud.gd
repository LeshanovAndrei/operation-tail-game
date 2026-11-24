class_name TacticalHUD
extends CanvasLayer

signal speed_selected(speed_multiplier: float)
signal route_aim_toggled(origin_id: String)
signal dispatch_options_changed()
signal stop_loop_requested(convoy_id: String)
signal cycle_convoy_cargo_requested(convoy_id: String)
signal convoy_night_toggled(convoy_id: String)
signal convoy_evac_toggled(convoy_id: String)
signal camouflage_toggled(node_id: String)
signal train_target_selected(node_id: String)
signal train_slot_cycled(slot_idx: int)
signal train_truck_cycled()
signal radiogram_jump_requested(node_id: String)
signal radiogram_dismissed(rad_id: String)
signal event_clicked(event_index: int)
signal restart_requested()
signal layer_toggled(layer_name: String, enabled: bool)
signal zoom_in_requested()
signal zoom_out_requested()
signal inspector_closed()
signal pause_resume_requested()
signal pause_settings_requested()
signal pause_restart_requested()
signal pause_hub_requested()
signal pause_main_menu_requested()
signal debrief_continue_requested()
signal debrief_restart_requested()
signal debrief_main_menu_requested()
signal deploy_depot_requested(node_id: String)
signal pack_depot_requested(node_id: String)
signal train_equipment_toggled()

const TOP_BAR_H: float = 44.0
const SUMMARY_W: float = 246.0
const INSPECTOR_W: float = 298.0
const PX_PER_KM: float = 6.59

var _root: Control = null
var _title_label: Label = null
var _phase_label: Label = null
var _time_label: Label = null
var _day_night_icon: TextureRect = null
var _day_night_label: Label = null
var _weather_icon: TextureRect = null
var _weather_label: Label = null
var _recon_label: Label = null
var _train_timer_label: Label = null
var _front_fuel_label: Label = null
var _front_ammo_label: Label = null
var _front_prov_label: Label = null
var _front_parts_label: Label = null
var _free_convoys_label: Label = null
var _speed_entries: Array[Dictionary] = []

var _summary_body: VBoxContainer = null
var _summary_toggle_btn: Button = null
var _log_expand_btn: Button = null
var _log_expanded: bool = false
var _summary_sig_label: Label = null
var _summary_arty_label: Label = null
var _summary_obj_label: Label = null
var _summary_mod_label: Label = null
var _summary_wounded_label: Label = null
var _log_rtl: RichTextLabel = null
var _last_logged_count: int = 0

var _radio_panel: PanelContainer = null
var _radio_sender_lbl: Label = null
var _radio_text_lbl: Label = null
var _active_rad_id: String = ""
var _active_rad_node_id: String = ""

var _scale_bar_ctrl: Control = null
var _camera_zoom: float = 0.78
var _legend_panel: PanelContainer = null

var _tooltip_panel: PanelContainer = null
var _tooltip_title: Label = null
var _tooltip_sub: Label = null
var _tooltip_body: Label = null
var _tooltip_warn: Label = null

var _inspector_panel: PanelContainer = null
var _node_title_label: Label = null
var _node_type_label: Label = null
var _stock_section: VBoxContainer = null
var _res_labels: Dictionary[int, Label] = {}
var _res_bars: Dictionary[int, ProgressBar] = {}
var _res_cells: Dictionary[int, VBoxContainer] = {}

var _depot_section: VBoxContainer = null
var _sig_label: Label = null
var _sig_bar: ProgressBar = null
var _sig_breakdown_label: Label = null
var _camo_button: Button = null
var _slots_label: Label = null
var _strike_warn_label: Label = null

var _field_depot_section: VBoxContainer = null
var _field_depot_info_lbl: Label = null
var _field_depot_bar: ProgressBar = null
var _field_depot_btn: Button = null

var _junction_section: VBoxContainer = null
var _junction_info_label: Label = null

var _front_section: VBoxContainer = null
var _integrity_label: Label = null
var _integrity_bar: ProgressBar = null
var _intensity_label: Label = null
var _wounded_label: Label = null

var _reequip_section: VBoxContainer = null
var _reequip_label: Label = null
var _reequip_bar: ProgressBar = null

var _arty_section: VBoxContainer = null
var _arty_status_label: Label = null

var _bridge_section: VBoxContainer = null
var _bridge_status_label: Label = null

var _objective_section: VBoxContainer = null
var _objective_label: Label = null
var _objective_bar: ProgressBar = null

var _train_section: VBoxContainer = null
var _train_header_label: Label = null
var _train_target_row: HBoxContainer = null
var _train_target_buttons: Dictionary[String, Button] = {}
var _train_grid: GridContainer = null
var _train_slot_buttons: Array[Button] = []
var _train_truck_btn: Button = null
var _train_equip_btn: Button = null

var _dispatch_section: VBoxContainer = null
var _idle_at_node_label: Label = null
var _type_option: OptionButton = null
var _mode_option: OptionButton = null
var _cargo_option: OptionButton = null
var _evac_checkbox: CheckBox = null
var _night_checkbox: CheckBox = null
var _dispatch_hint_label: Label = null
var _aim_button: Button = null
var _active_convoy_vbox: VBoxContainer = null

var _autopause_banner: PanelContainer = null
var _autopause_label: Label = null

var _pause_backdrop: ColorRect = null
var _pause_modal: PanelContainer = null
var _pause_hub_btn: Button = null

var _debrief_backdrop: ColorRect = null
var _debrief_modal: PanelContainer = null
var _debrief_title_label: Label = null
var _debrief_reason_label: Label = null
var _debrief_stats_label: Label = null
var _debrief_obj_vbox: VBoxContainer = null
var _debrief_cp_label: Label = null
var _debrief_hub_btn: Button = null

var _current_node_id: String = ""
var _is_aiming: bool = false


func _ready() -> void:
	_build_ui()


func refresh(engine: SimEngine, selected_node_id: String, speed_multiplier: float, aiming: bool) -> void:
	if engine == null or engine.graph == null:
		return
	_is_aiming = aiming
	_refresh_top_bar(engine, speed_multiplier)
	_refresh_summary(engine)
	_refresh_radiogram(engine)
	_refresh_inspector(engine, selected_node_id)


func show_autopause_notice(reason: String) -> void:
	if _autopause_banner == null or _autopause_label == null:
		return
	_autopause_label.text = "АВТОПАУЗА: %s  (Space — продолжить)" % reason
	_autopause_banner.visible = true


func clear_autopause_notice() -> void:
	if _autopause_banner != null:
		_autopause_banner.visible = false


func set_pause_menu_visible(vis: bool, in_campaign: bool) -> void:
	if _pause_backdrop != null:
		_pause_backdrop.visible = vis
	if _pause_modal != null:
		_pause_modal.visible = vis
	if _pause_hub_btn != null:
		_pause_hub_btn.visible = in_campaign


func show_debriefing(
	engine: SimEngine,
	stats: SimTypes.SimStats,
	secondary_results: Array[Dictionary],
	reward_info: Dictionary,
	in_campaign: bool
) -> void:
	if _debrief_modal == null:
		return
	_debrief_backdrop.visible = true
	_debrief_modal.visible = true

	var is_win: bool = (engine.result == SimTypes.GameResult.VICTORY)
	_debrief_title_label.text = "ОПЕРАЦИЯ ЗАВЕРШЕНА: ПОБЕДА" if is_win else "ОПЕРАЦИЯ ПРОВАЛЕНА: ПОРАЖЕНИЕ"
	_debrief_title_label.modulate = TacticalTheme.COL_OK if is_win else TacticalTheme.COL_CRITICAL
	_debrief_reason_label.text = engine.result_reason

	var f_tons: float = stats.delivered_by_resource.get(SimTypes.ResourceType.FUEL, 0.0)
	var a_tons: float = stats.delivered_by_resource.get(SimTypes.ResourceType.AMMO, 0.0)
	var p_tons: float = stats.delivered_by_resource.get(SimTypes.ResourceType.PROVISIONS, 0.0)
	var z_tons: float = stats.delivered_by_resource.get(SimTypes.ResourceType.PARTS, 0.0)
	var e_tons: float = stats.delivered_by_resource.get(SimTypes.ResourceType.EQUIPMENT, 0.0)
	var evac_pct: int = int(round(stats.wounded_evac_ratio * 100.0))

	_debrief_stats_label.text = (
		"Время операции: %.1f ч | Эшелоны: %d | Развёрнуто полевых складов: %d\n"
		+ "Доставлено всего: %.0f т (ГСМ %.0f • БК %.0f • Пров %.0f • Запч %.0f • Перевоор %.0fт)\n"
		+ "Раненые: вывезено %.0f, осталось %.0f (%d%%) | Перевооружено (Ур.II): %d\n"
		+ "Удары по складам: %d | Выбыло колонн: %d | Мосты: %d | Разминир.: %d | Мин. целостн.: %.0f%%"
	) % [
		stats.elapsed_hours,
		stats.trains_arrived,
		stats.field_depots_deployed,
		stats.total_delivered_tons,
		f_tons,
		a_tons,
		p_tons,
		z_tons,
		e_tons,
		stats.wounded_evacuated,
		stats.wounded_remaining,
		evac_pct,
		stats.units_modernized,
		stats.depot_strikes,
		stats.convoys_disabled_count,
		stats.bridges_repaired,
		stats.roads_demined,
		stats.min_sector_integrity,
	]

	for child: Node in _debrief_obj_vbox.get_children():
		child.queue_free()

	var prim_ok: bool = is_win
	var prim_lbl: Label = _make_label(
		"%s Основная задача выполнена (%s)" % ["[✓]" if prim_ok else "[✗]", "зачтена" if prim_ok else "провалена"],
		14,
		TacticalTheme.COL_OK if prim_ok else TacticalTheme.COL_CRITICAL,
		true
	)
	_debrief_obj_vbox.add_child(prim_lbl)

	for sec: Dictionary in secondary_results:
		var done: bool = bool(sec.get("completed", false))
		var mark: String = "[✓]" if done else "[✗]"
		var col: Color = TacticalTheme.COL_OK if done else TacticalTheme.COL_MUTED
		var line: String = "%s %s — %s (%s | +%d ОК)" % [
			mark,
			str(sec.get("title", "")),
			str(sec.get("description", "")),
			str(sec.get("progress_text", "")),
			int(sec.get("bonus_cp", 0)),
		]
		var slbl: Label = _make_label(line, 13, col)
		slbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_debrief_obj_vbox.add_child(slbl)

	if in_campaign:
		var p_cp: int = int(reward_info.get("primary_cp_earned", 0))
		var s_cp: int = int(reward_info.get("secondary_cp_earned", 0))
		var tot_earned: int = int(reward_info.get("total_cp_earned", 0))
		var cur_cp: int = int(reward_info.get("total_command_points", 0))
		var note: String = " (основная награда уже получена ранее)" if bool(reward_info.get("already_awarded_primary", false)) else ""
		_debrief_cp_label.text = "Начислено очков командования: +%d ОК (осн. +%d, побочн. +%d)%s • В резерве штаба: %d ОК" % [
			tot_earned,
			p_cp,
			s_cp,
			note,
			cur_cp,
		]
		_debrief_cp_label.modulate = TacticalTheme.COL_ACCENT
	else:
		_debrief_cp_label.text = "Режим быстрой операции — прогресс кампании не изменялся."
		_debrief_cp_label.modulate = TacticalTheme.COL_MUTED

	_debrief_hub_btn.visible = in_campaign


func hide_debriefing() -> void:
	if _debrief_backdrop != null:
		_debrief_backdrop.visible = false
	if _debrief_modal != null:
		_debrief_modal.visible = false


func update_hover_tooltip(data: Dictionary, mouse_screen_pos: Vector2) -> void:
	if _tooltip_panel == null:
		return
	if data.is_empty():
		_tooltip_panel.visible = false
		return

	_tooltip_panel.visible = true
	_tooltip_title.text = str(data.get("title", ""))
	_tooltip_sub.text = str(data.get("subtitle", ""))

	var lines_raw: Variant = data.get("lines", [])
	var body_lines: PackedStringArray = PackedStringArray()
	if typeof(lines_raw) == TYPE_ARRAY:
		for item: Variant in lines_raw:
			body_lines.append(str(item))
	_tooltip_body.text = "\n".join(body_lines)
	_tooltip_body.visible = not body_lines.is_empty()

	var warn_txt: String = str(data.get("warning", ""))
	_tooltip_warn.text = warn_txt
	_tooltip_warn.visible = not warn_txt.is_empty()

	var vp_size: Vector2 = _root.get_viewport_rect().size
	var tip_size: Vector2 = _tooltip_panel.size
	var pos: Vector2 = mouse_screen_pos + Vector2(16.0, 18.0)
	if pos.x + tip_size.x > vp_size.x - 10.0:
		pos.x = mouse_screen_pos.x - tip_size.x - 12.0
	if pos.y + tip_size.y > vp_size.y - 10.0:
		pos.y = mouse_screen_pos.y - tip_size.y - 12.0
	_tooltip_panel.position = Vector2(maxf(8.0, pos.x), maxf(TOP_BAR_H + 4.0, pos.y))


func get_selected_convoy_type() -> SimTypes.ConvoyType:
	if _type_option == null:
		return SimTypes.ConvoyType.CARGO
	match _type_option.selected:
		1:
			return SimTypes.ConvoyType.TANKER
		2:
			return SimTypes.ConvoyType.ENGINEER
		3:
			return SimTypes.ConvoyType.ARMORED
	return SimTypes.ConvoyType.CARGO


func get_selected_order_mode() -> SimTypes.OrderMode:
	if _mode_option == null:
		return SimTypes.OrderMode.LOOP
	match _mode_option.selected:
		0:
			return SimTypes.OrderMode.ONE_WAY_RETURN
		1:
			return SimTypes.OrderMode.REDEPLOY
		2:
			return SimTypes.OrderMode.LOOP
	return SimTypes.OrderMode.LOOP


func get_selected_cargo_pref() -> SimTypes.CargoPreference:
	if get_selected_order_mode() == SimTypes.OrderMode.REDEPLOY:
		return SimTypes.CargoPreference.EMPTY
	var ctype: SimTypes.ConvoyType = get_selected_convoy_type()
	if ctype == SimTypes.ConvoyType.TANKER:
		return SimTypes.CargoPreference.FUEL
	if ctype == SimTypes.ConvoyType.ENGINEER:
		if _cargo_option != null and _cargo_option.selected == 5:
			return SimTypes.CargoPreference.EQUIPMENT
		return SimTypes.CargoPreference.PARTS
	if _cargo_option == null:
		return SimTypes.CargoPreference.MIXED
	match _cargo_option.selected:
		1:
			return SimTypes.CargoPreference.FUEL
		2:
			return SimTypes.CargoPreference.AMMO
		3:
			return SimTypes.CargoPreference.PROVISIONS
		4:
			return SimTypes.CargoPreference.PARTS
		5:
			return SimTypes.CargoPreference.EQUIPMENT
	return SimTypes.CargoPreference.MIXED


func is_evac_checked() -> bool:
	return _evac_checkbox != null and _evac_checkbox.button_pressed


func is_night_only_checked() -> bool:
	return _night_checkbox != null and _night_checkbox.button_pressed


func set_scale_zoom(zoom_val: float) -> void:
	if not is_equal_approx(_camera_zoom, zoom_val):
		_camera_zoom = zoom_val
		if _scale_bar_ctrl != null:
			_scale_bar_ctrl.queue_redraw()


func reset_log() -> void:
	_last_logged_count = 0
	if _log_rtl != null:
		_log_rtl.clear()


func _refresh_top_bar(engine: SimEngine, speed_multiplier: float) -> void:
	if engine.config != null and _title_label != null:
		var short_t: String = engine.config.short_title if not engine.config.short_title.is_empty() else engine.config.scenario_name
		_title_label.text = short_t

	if engine.config != null and engine.config.mission_mode == SimTypes.MissionMode.DEFENSE:
		_phase_label.text = "ОБ:%.0f/%dч" % [floor(engine.get_elapsed_hours()), engine.config.duration_hours]
		_phase_label.modulate = TacticalTheme.COL_FRIENDLY
	elif engine.phase == SimTypes.OperationPhase.BUILDUP:
		var pct: int = int(round(engine.get_buildup_readiness_ratio() * 100.0))
		_phase_label.text = "Ф1:%d%%" % pct
		_phase_label.modulate = TacticalTheme.COL_OK if pct >= 85 else TacticalTheme.COL_ACCENT
	else:
		var obj_tot: int = engine.graph.get_nodes_by_type(SimTypes.NodeType.OBJECTIVE).size()
		_phase_label.text = "Ф2:%d/%d" % [engine.objectives_captured, maxi(1, obj_tot)]
		_phase_label.modulate = TacticalTheme.COL_FRIENDLY

	_time_label.text = "Д%d %02d:%02d" % [engine.get_day(), engine.get_hour(), engine.get_minute()]

	if engine.is_night():
		_day_night_label.text = "НОЧЬ"
		_day_night_label.modulate = Color("#8fb4dc")
		_day_night_icon.modulate = Color("#8fb4dc")
	else:
		_day_night_label.text = "ДЕНЬ"
		_day_night_label.modulate = TacticalTheme.COL_ACCENT
		_day_night_icon.modulate = TacticalTheme.COL_ACCENT

	var forecast: SimTypes.Weather = engine.get_weather_forecast_6h()
	var w_txt: String = SimTypes.weather_label(engine.weather)
	if forecast != engine.weather:
		w_txt += "→" + SimTypes.weather_label(forecast)
	_weather_label.text = w_txt
	match engine.weather:
		SimTypes.Weather.CLEAR:
			_weather_label.modulate = TacticalTheme.COL_TEXT
			_weather_icon.modulate = TacticalTheme.COL_MUTED
		SimTypes.Weather.RAIN:
			_weather_label.modulate = Color("#7db4d8")
			_weather_icon.modulate = Color("#7db4d8")
		SimTypes.Weather.MUD:
			_weather_label.modulate = TacticalTheme.COL_ACCENT
			_weather_icon.modulate = TacticalTheme.COL_ACCENT

	var recon_ticks: int = engine.get_ticks_until_next_recon()
	var recon_mins: int = recon_ticks * SimEngine.TICK_MINUTES
	_recon_label.text = "Разв.%02d:%02d" % [int(recon_mins / 60), recon_mins % 60]
	var max_sig: float = engine.get_max_vulnerable_signature()
	if recon_ticks <= SimEngine.TICKS_PER_HOUR and max_sig >= 65.0:
		_recon_label.modulate = TacticalTheme.COL_ACCENT
	elif max_sig >= 75.0:
		_recon_label.modulate = TacticalTheme.COL_CRITICAL
	else:
		_recon_label.modulate = TacticalTheme.COL_TEXT

	var train_mins: int = engine.get_ticks_until_next_train() * SimEngine.TICK_MINUTES
	_train_timer_label.text = "Эш.%02d:%02d%s" % [int(train_mins / 60), train_mins % 60, "🔒" if engine.is_inbound_train_locked() else ""]
	_train_timer_label.modulate = TacticalTheme.COL_ACCENT if engine.is_inbound_train_locked() else TacticalTheme.COL_TEXT

	_front_fuel_label.text = "%.0f" % engine.get_total_front_stock(SimTypes.ResourceType.FUEL)
	_front_ammo_label.text = "%.0f" % engine.get_total_front_stock(SimTypes.ResourceType.AMMO)
	_front_prov_label.text = "%.0f" % engine.get_total_front_stock(SimTypes.ResourceType.PROVISIONS)
	_front_parts_label.text = "%.0f" % engine.get_total_front_stock(SimTypes.ResourceType.PARTS)

	var idle_count: int = engine.get_all_idle_convoys().size()
	_free_convoys_label.text = "%d/%d" % [idle_count, engine.convoys.size()]

	for entry: Dictionary in _speed_entries:
		var sp: float = float(entry["speed"])
		var btn: Button = entry["button"]
		var active: bool = is_equal_approx(sp, speed_multiplier)
		btn.button_pressed = active
		btn.modulate = TacticalTheme.COL_ACCENT if active else TacticalTheme.COL_TEXT


func _refresh_summary(engine: SimEngine) -> void:
	var max_sig: float = 0.0
	var strike_soon: bool = false
	for node: SimTypes.MapNode in engine.graph.get_all_nodes():
		if not node.is_vulnerable:
			continue
		if node.signature > max_sig:
			max_sig = node.signature
		if node.pending_strike_ticks >= 0:
			strike_soon = true

	_summary_sig_label.text = "Сигнатура макс: %.0f%%%s" % [max_sig, " (УДАР!)" if strike_soon else ""]
	_summary_sig_label.modulate = TacticalTheme.COL_CRITICAL if (strike_soon or max_sig >= 75.0) else (TacticalTheme.COL_ACCENT if max_sig >= 65.0 else TacticalTheme.COL_TEXT)

	var arties: Array[SimTypes.MapNode] = engine.graph.get_nodes_by_type(SimTypes.NodeType.ARTILLERY)
	if arties.is_empty():
		_summary_arty_label.text = "АДН: нет"
		_summary_arty_label.modulate = TacticalTheme.COL_MUTED
	elif arties.size() == 1 and (arties[0].flank == "ALL" or arties[0].flank.is_empty()):
		var a_ok: bool = engine.arty_support_by_flank.get("ALL", false)
		_summary_arty_label.text = "АДН: %s" % ("ОГОНЬ" if a_ok else "ожидание")
		_summary_arty_label.modulate = TacticalTheme.COL_OK if a_ok else TacticalTheme.COL_MUTED
	else:
		var an: bool = engine.arty_support_by_flank.get("NORTH", false)
		var as_ok: bool = engine.arty_support_by_flank.get("SOUTH", false)
		_summary_arty_label.text = "АДН: С-%s | Ю-%s" % ["ОГОНЬ" if an else "ожид", "ОГОНЬ" if as_ok else "ожид"]
		_summary_arty_label.modulate = TacticalTheme.COL_OK if (an or as_ok) else TacticalTheme.COL_MUTED

	var objs: Array[SimTypes.MapNode] = engine.graph.get_nodes_by_type(SimTypes.NodeType.OBJECTIVE)
	if objs.is_empty():
		_summary_obj_label.text = "Удержание: %.1f / %d ч" % [engine.get_elapsed_hours(), engine.config.duration_hours]
	else:
		var obj_parts: PackedStringArray = PackedStringArray()
		for o: SimTypes.MapNode in objs:
			var clean_name: String = o.display_name.replace("Узел ", "").replace("«", "").replace("»", "")
			var short_code: String = clean_name.substr(0, 1) if not clean_name.is_empty() else "Ц"
			obj_parts.append("%s %d%%" % [short_code, int(round(o.capture_progress))])
		_summary_obj_label.text = "Цели: " + " • ".join(obj_parts)

	var total_w: int = int(round(engine.get_total_wounded()))
	var total_evac: int = int(round(engine.get_total_wounded_evacuated()))
	_summary_wounded_label.text = "Раненые: %d (эвак. %d)" % [total_w, total_evac]
	_summary_wounded_label.modulate = TacticalTheme.COL_ACCENT if total_w >= 40 else TacticalTheme.COL_TEXT

	var req_mod: int = engine.config.required_modernized_units if engine.config != null else 0
	if req_mod > 0 or engine.units_modernized > 0:
		_summary_mod_label.visible = true
		_summary_mod_label.text = "Модернизировано II: %d%s" % [
			engine.units_modernized,
			" / %d" % req_mod if req_mod > 0 else "",
		]
		_summary_mod_label.modulate = TacticalTheme.COL_OK if (req_mod > 0 and engine.units_modernized >= req_mod) else TacticalTheme.COL_ACCENT
	else:
		_summary_mod_label.visible = false

	if engine.event_log.size() < _last_logged_count:
		reset_log()
	while _last_logged_count < engine.event_log.size():
		var ev: SimTypes.SimEvent = engine.event_log[_last_logged_count]
		var col_hex: String = "#b8bfb0"
		match ev.severity:
			SimTypes.EventSeverity.INFO:
				col_hex = "#b8bfb0"
			SimTypes.EventSeverity.SUCCESS:
				col_hex = "#739e4c"
			SimTypes.EventSeverity.WARNING:
				col_hex = "#d9a441"
			SimTypes.EventSeverity.CRITICAL:
				col_hex = "#e06252"
		var line: String = ev.format_line()
		if not ev.node_id.is_empty() or ev.has_world_pos:
			_log_rtl.append_text("[url=%d][color=%s]%s[/color][/url]\n" % [_last_logged_count, col_hex, line])
		else:
			_log_rtl.append_text("[color=%s]%s[/color]\n" % [col_hex, line])
		_last_logged_count += 1


func _refresh_radiogram(engine: SimEngine) -> void:
	var rad: SimTypes.Radiogram = engine.get_latest_active_radiogram()
	if rad == null:
		_radio_panel.visible = false
		_active_rad_id = ""
		_active_rad_node_id = ""
		return

	_radio_panel.visible = true
	_active_rad_id = rad.id
	_active_rad_node_id = rad.node_id
	_radio_sender_lbl.text = "РАДИОГРАММА • %s" % rad.sender
	_radio_text_lbl.text = rad.text
	match rad.severity:
		SimTypes.EventSeverity.CRITICAL:
			_radio_sender_lbl.modulate = TacticalTheme.COL_CRITICAL
		SimTypes.EventSeverity.WARNING:
			_radio_sender_lbl.modulate = TacticalTheme.COL_ACCENT
		SimTypes.EventSeverity.SUCCESS:
			_radio_sender_lbl.modulate = TacticalTheme.COL_OK
		_:
			_radio_sender_lbl.modulate = TacticalTheme.COL_FRIENDLY


func _refresh_inspector(engine: SimEngine, selected_node_id: String) -> void:
	_current_node_id = selected_node_id
	var node: SimTypes.MapNode = engine.graph.get_node(selected_node_id)
	if node == null:
		_inspector_panel.visible = false
		return

	_inspector_panel.visible = true
	_node_title_label.text = node.display_name
	_node_type_label.text = SimTypes.node_type_label(node.node_type)

	_stock_section.visible = node.has_storage() and node.owner == SimTypes.Owner.FRIENDLY
	if _stock_section.visible:
		for res: SimTypes.ResourceType in SimTypes.all_resources():
			var cur: float = node.get_stock(res)
			var raw_cap: float = node.get_capacity(res)
			if res == SimTypes.ResourceType.EQUIPMENT and _res_cells.has(int(res)):
				_res_cells[int(res)].visible = (raw_cap > 0.0 or cur > 0.0)
			var cap: float = maxf(1.0, raw_cap)
			_res_labels[int(res)].text = "%s: %.0f/%.0f" % [SimTypes.resource_short_label(res), cur, cap]
			_res_bars[int(res)].max_value = cap
			_res_bars[int(res)].value = cur

	_depot_section.visible = node.is_vulnerable
	if node.is_vulnerable:
		_sig_label.text = "Сигнатура: %.0f / 100%%" % node.signature
		_sig_bar.max_value = 100.0
		_sig_bar.value = node.signature
		var bd: Dictionary = engine.get_signature_rate_breakdown(node.id)
		_sig_breakdown_label.text = "Зап:%+.1f | Траф:%+.1f | Оч:%+.1f | Прост:%+.1f | Ост:%+.1f → %+.1f/ч" % [
			float(bd.get("storage_per_h", 0.0)),
			float(bd.get("traffic_per_h", 0.0)),
			float(bd.get("queue_per_h", 0.0)),
			float(bd.get("idle_per_h", 0.0)),
			float(bd.get("decay_per_h", 0.0)),
			float(bd.get("net_per_h", 0.0)),
		]
		_camo_button.button_pressed = node.camouflaged
		_camo_button.text = "Маскировка: ВКЛ (-50% сигн., +40% погр.)" if node.camouflaged else "Включить маскировку (+40% погр., -50% сигн.)"
		_camo_button.modulate = TacticalTheme.COL_OK if node.camouflaged else TacticalTheme.COL_TEXT

		_slots_label.text = "Погрузочные места: %d / %d" % [node.active_loading_count, node.loading_slots]
		_slots_label.modulate = TacticalTheme.COL_ACCENT if node.active_loading_count >= node.loading_slots else TacticalTheme.COL_MUTED
		if node.pending_strike_ticks >= 0:
			_strike_warn_label.visible = true
			_strike_warn_label.text = "УГРОЗА УДАРА! ~%d мин" % (node.pending_strike_ticks * SimEngine.TICK_MINUTES)
		else:
			_strike_warn_label.visible = false

	_junction_section.visible = (node.node_type == SimTypes.NodeType.JUNCTION and not node.can_deploy_depot)

	var show_field_dep: bool = (
		(node.node_type == SimTypes.NodeType.JUNCTION and node.can_deploy_depot)
		or node.node_type == SimTypes.NodeType.FIELD_DEPOT
	)
	_field_depot_section.visible = show_field_dep
	if show_field_dep:
		if node.node_type == SimTypes.NodeType.JUNCTION:
			if node.deploy_build_ticks_remaining > 0:
				var b_pct: int = int(round((1.0 - float(node.deploy_build_ticks_remaining) / float(maxi(1, node.deploy_build_ticks_total))) * 100.0))
				_field_depot_info_lbl.text = "Строительство полевого склада: %d%% (осталось ~%d мин)" % [b_pct, node.deploy_build_ticks_remaining * SimEngine.TICK_MINUTES]
				_field_depot_bar.max_value = float(node.deploy_build_ticks_total)
				_field_depot_bar.value = float(node.deploy_build_ticks_total - node.deploy_build_ticks_remaining)
				_field_depot_btn.text = "Развёртывание в процессе..."
				_field_depot_btn.disabled = true
			else:
				_field_depot_info_lbl.text = "Площадка полевого склада: доставлено %.0f / %.0fт ЗП" % [node.deploy_progress_parts, node.deploy_cost_parts]
				_field_depot_bar.max_value = node.deploy_cost_parts
				_field_depot_bar.value = node.deploy_progress_parts
				_field_depot_btn.text = "Развернуть полевой склад (25т ЗП)" if not node.deploy_requested else "Повторно вызвать Инж. колонну"
				_field_depot_btn.disabled = false
				_field_depot_btn.modulate = TacticalTheme.COL_OK
		else:
			if node.pack_ticks_remaining > 0:
				var p_pct: int = int(round((1.0 - float(node.pack_ticks_remaining) / float(maxi(1, node.pack_ticks_total))) * 100.0))
				_field_depot_info_lbl.text = "Сворачивание склада: %d%% (осталось ~%d мин)" % [p_pct, node.pack_ticks_remaining * SimEngine.TICK_MINUTES]
				_field_depot_bar.max_value = float(node.pack_ticks_total)
				_field_depot_bar.value = float(node.pack_ticks_total - node.pack_ticks_remaining)
				_field_depot_btn.text = "Сворачивание в процессе..."
				_field_depot_btn.disabled = true
			else:
				var rem_stock: float = node.get_total_stock()
				_field_depot_info_lbl.text = "Полевой склад (-25%% сигн.). Остаток грузов: %.0fт" % rem_stock
				_field_depot_bar.max_value = 1.0
				_field_depot_bar.value = 1.0
				_field_depot_btn.text = "Свернуть склад (3 ч%s)" % (", потеря %.0fт!" % rem_stock if rem_stock > 5.0 else ", +10т ЗП")
				_field_depot_btn.disabled = false
				_field_depot_btn.modulate = TacticalTheme.COL_ACCENT

	_front_section.visible = (node.node_type == SimTypes.NodeType.FRONT_SECTOR)
	if node.node_type == SimTypes.NodeType.FRONT_SECTOR:
		_integrity_label.text = "Целостность: %.1f%%" % node.integrity
		_integrity_bar.max_value = 100.0
		_integrity_bar.value = node.integrity
		_intensity_label.text = "Бой: %s" % SimTypes.intensity_label(node.intensity)
		_wounded_label.text = "Раненые: %.0f / 24" % node.wounded
		_wounded_label.modulate = TacticalTheme.COL_CRITICAL if node.wounded >= 24.0 else TacticalTheme.COL_TEXT

	_arty_section.visible = (node.node_type == SimTypes.NodeType.ARTILLERY)
	if node.node_type == SimTypes.NodeType.ARTILLERY:
		var fl: String = node.flank if not node.flank.is_empty() else "NORTH"
		var active: bool = engine.arty_support_by_flank.get(fl, false)
		_arty_status_label.text = "Поддержка фланга (%s): %s" % [fl, "ВЕДЁТ ОГОНЬ" if active else "ОЖИДАНИЕ / НЕТ БК"]
		_arty_status_label.modulate = TacticalTheme.COL_OK if active else TacticalTheme.COL_MUTED

	var can_reequip: bool = (node.node_type == SimTypes.NodeType.FRONT_SECTOR or node.node_type == SimTypes.NodeType.ARTILLERY)
	_reequip_section.visible = can_reequip
	if can_reequip:
		if node.equipment_tier >= 2:
			_reequip_label.text = "Оснащение: Уровень II ★ (+35%% эфф., -20%% БК)"
			_reequip_label.modulate = Color("#f0c248")
			_reequip_bar.max_value = 1.0
			_reequip_bar.value = 1.0
		elif node.reequip_ticks_remaining > 0:
			_reequip_label.text = "Переформирование на Ур.II: осталось ~%d мин" % (node.reequip_ticks_remaining * SimEngine.TICK_MINUTES)
			_reequip_label.modulate = TacticalTheme.COL_ACCENT
			_reequip_bar.max_value = float(node.reequip_ticks_total)
			_reequip_bar.value = float(node.reequip_ticks_total - node.reequip_ticks_remaining)
		else:
			_reequip_label.text = "Оснащение: Уровень I • Перевооружение %.0f/%.0fт ПЕР" % [node.reequip_progress, node.reequip_cost]
			_reequip_label.modulate = TacticalTheme.COL_TEXT
			_reequip_bar.max_value = node.reequip_cost
			_reequip_bar.value = node.reequip_progress

	_bridge_section.visible = node.is_bridge
	if node.is_bridge:
		if node.damaged:
			_bridge_status_label.text = "ПОВРЕЖДЁН! Нужна Инж. (%.0f/%.0fт ЗП)" % [node.repair_progress_parts, node.repair_cost_parts]
			_bridge_status_label.modulate = TacticalTheme.COL_CRITICAL
		else:
			_bridge_status_label.text = "Переправа исправна (100% скор.)"
			_bridge_status_label.modulate = TacticalTheme.COL_OK

	_objective_section.visible = (node.node_type == SimTypes.NodeType.OBJECTIVE)
	if node.node_type == SimTypes.NodeType.OBJECTIVE:
		if node.owner == SimTypes.Owner.FRIENDLY:
			_objective_label.text = "КОНТРОЛЬ: 2-я ОГ (захвачен)"
			_objective_label.modulate = TacticalTheme.COL_OK
			_objective_bar.value = 100.0
		else:
			_objective_label.text = "Захват узла: %.1f%%" % node.capture_progress
			_objective_label.modulate = TacticalTheme.COL_ACCENT
			_objective_bar.value = node.capture_progress

	_train_section.visible = (node.node_type == SimTypes.NodeType.RAILHEAD)
	if node.node_type == SimTypes.NodeType.RAILHEAD:
		_refresh_train_ui(engine)

	_dispatch_section.visible = (node.owner == SimTypes.Owner.FRIENDLY)
	if _dispatch_section.visible:
		var counts: Dictionary[SimTypes.ConvoyType, int] = engine.get_idle_counts_by_type_at(node.id)
		var c_cnt: int = counts.get(SimTypes.ConvoyType.CARGO, 0)
		var t_cnt: int = counts.get(SimTypes.ConvoyType.TANKER, 0)
		var e_cnt: int = counts.get(SimTypes.ConvoyType.ENGINEER, 0)
		var a_cnt: int = counts.get(SimTypes.ConvoyType.ARMORED, 0)
		_idle_at_node_label.text = "Свободно: Борт %d • АТЗ %d • Инж %d • БТР %d" % [c_cnt, t_cnt, e_cnt, a_cnt]

		var sel_type: SimTypes.ConvoyType = get_selected_convoy_type()
		var sel_mode: SimTypes.OrderMode = get_selected_order_mode()
		_sync_cargo_option_ui(sel_type, sel_mode)
		_evac_checkbox.disabled = (sel_mode == SimTypes.OrderMode.REDEPLOY)

		var has_sel_type: bool = counts.get(sel_type, 0) > 0
		_aim_button.disabled = (not has_sel_type) and (not _is_aiming)
		if not has_sel_type and not _is_aiming:
			_dispatch_hint_label.text = "Нет свободных колонн типа «%s» в этом узле." % SimTypes.convoy_type_label(sel_type)
			_dispatch_hint_label.visible = true
		elif _is_aiming:
			_dispatch_hint_label.text = "Кликните по целевому узлу на карте (ЛКМ — отправить, ПКМ/Esc — отмена)."
			_dispatch_hint_label.visible = true
		else:
			_dispatch_hint_label.visible = false

		if _is_aiming:
			_aim_button.text = "Отменить прицеливание (Esc)"
			_aim_button.modulate = TacticalTheme.COL_ACCENT
		else:
			_aim_button.text = "Назначить маршрут (клик по карте)"
			_aim_button.modulate = TacticalTheme.COL_TEXT

	_rebuild_active_convoys(engine, node.id)


func _sync_cargo_option_ui(ctype: SimTypes.ConvoyType, mode: SimTypes.OrderMode) -> void:
	if mode == SimTypes.OrderMode.REDEPLOY:
		_cargo_option.disabled = true
		return
	if ctype == SimTypes.ConvoyType.TANKER:
		_cargo_option.select(1)
		_cargo_option.disabled = true
	elif ctype == SimTypes.ConvoyType.ENGINEER:
		if _cargo_option.selected != 4 and _cargo_option.selected != 5:
			_cargo_option.select(4)
		_cargo_option.disabled = false
	else:
		_cargo_option.disabled = false


func _refresh_train_ui(engine: SimEngine) -> void:
	var mins: int = engine.get_ticks_until_next_train() * SimEngine.TICK_MINUTES
	var locked: bool = engine.is_inbound_train_locked()
	if locked:
		_train_header_label.text = "Эшелон в пути (%02d:%02d). След.:" % [int(mins / 60), mins % 60]
		_train_header_label.modulate = TacticalTheme.COL_ACCENT
	else:
		_train_header_label.text = "Сборка эшелона (через %02d:%02d):" % [int(mins / 60), mins % 60]
		_train_header_label.modulate = TacticalTheme.COL_TEXT

	var railheads: Array[SimTypes.MapNode] = engine.graph.get_nodes_by_type(SimTypes.NodeType.RAILHEAD)
	_sync_railhead_target_buttons(railheads)
	var cur_target: String = engine.get_editable_train_target()
	_train_target_row.visible = (railheads.size() > 1)
	for rid: String in _train_target_buttons.keys():
		var rbtn: Button = _train_target_buttons[rid]
		var is_sel: bool = (cur_target == rid)
		rbtn.button_pressed = is_sel
		var rn: SimTypes.MapNode = engine.graph.get_node(rid)
		var is_vuln: bool = (rn != null and rn.is_vulnerable)
		rbtn.modulate = (TacticalTheme.COL_ACCENT if is_vuln else TacticalTheme.COL_OK) if is_sel else TacticalTheme.COL_TEXT

	var slots: Array[SimTypes.TrainSlotType] = engine.get_editable_train_slots()
	_ensure_train_slot_buttons(slots.size())
	for i: int in range(slots.size()):
		var btn: Button = _train_slot_buttons[i]
		var st: SimTypes.TrainSlotType = slots[i]
		btn.text = "%d: %s" % [i + 1, SimTypes.train_slot_short_label(st)]
		match st:
			SimTypes.TrainSlotType.FUEL:
				btn.modulate = TacticalTheme.COL_FUEL
			SimTypes.TrainSlotType.AMMO:
				btn.modulate = TacticalTheme.COL_AMMO
			SimTypes.TrainSlotType.PROVISIONS:
				btn.modulate = Color("#7ac4ac")
			SimTypes.TrainSlotType.PARTS:
				btn.modulate = Color("#9db0c4")
			SimTypes.TrainSlotType.EQUIPMENT_PLATFORM, SimTypes.TrainSlotType.EQUIPMENT_LOCKED:
				btn.modulate = Color("#f0c248")
			_:
				btn.modulate = TacticalTheme.COL_FRIENDLY

	var truck_lbl: String = engine.get_truck_order_in_slots(slots)
	if not truck_lbl.is_empty():
		_train_truck_btn.text = "Подкрепление: +%s (сменить/убрать)" % truck_lbl
		_train_truck_btn.disabled = false
	elif engine.truck_order_cooldown_ticks > 0:
		var cd_h: float = float(engine.truck_order_cooldown_ticks) / float(SimEngine.TICKS_PER_HOUR)
		_train_truck_btn.text = "+Колонна (кулдаун %.0f ч)" % ceil(cd_h)
		_train_truck_btn.disabled = true
	else:
		_train_truck_btn.text = "+Заказать колонну (2 слота)"
		_train_truck_btn.disabled = false

	var has_eq: bool = engine.has_equipment_platform_in_slots(slots)
	if has_eq:
		_train_equip_btn.text = "Перевооружение: 30т (в составе — убрать)"
		_train_equip_btn.modulate = Color("#f0c248")
	else:
		_train_equip_btn.text = "+Платформа перевооружения (30т, 2 слота)"
		_train_equip_btn.modulate = TacticalTheme.COL_TEXT


func _sync_railhead_target_buttons(railheads: Array[SimTypes.MapNode]) -> void:
	var needs_rebuild: bool = (_train_target_buttons.size() != railheads.size())
	if not needs_rebuild:
		for rh: SimTypes.MapNode in railheads:
			if not _train_target_buttons.has(rh.id):
				needs_rebuild = true
				break
	if not needs_rebuild:
		return

	for child: Node in _train_target_row.get_children():
		child.queue_free()
	_train_target_buttons.clear()

	for rh: SimTypes.MapNode in railheads:
		var rbtn: Button = Button.new()
		rbtn.text = "На " + rh.display_name
		rbtn.toggle_mode = true
		rbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rbtn.add_theme_font_size_override("font_size", 11)
		var rid: String = rh.id
		rbtn.pressed.connect(func() -> void: train_target_selected.emit(rid))
		_train_target_row.add_child(rbtn)
		_train_target_buttons[rid] = rbtn


func _ensure_train_slot_buttons(count: int) -> void:
	if _train_slot_buttons.size() == count:
		return
	for child: Node in _train_grid.get_children():
		child.queue_free()
	_train_slot_buttons.clear()
	for idx: int in range(count):
		var sbtn: Button = Button.new()
		sbtn.text = "%d: ГСМ" % (idx + 1)
		sbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sbtn.add_theme_font_size_override("font_size", 11)
		var slot_i: int = idx
		sbtn.pressed.connect(func() -> void: train_slot_cycled.emit(slot_i))
		_train_grid.add_child(sbtn)
		_train_slot_buttons.append(sbtn)


func _rebuild_active_convoys(engine: SimEngine, node_id: String) -> void:
	for child: Node in _active_convoy_vbox.get_children():
		child.queue_free()

	var active_list: Array[Convoy] = []
	for convoy: Convoy in engine.get_convoys_related_to_node(node_id):
		if convoy.state != SimTypes.ConvoyState.IDLE or convoy.is_disabled():
			active_list.append(convoy)

	if active_list.is_empty():
		_active_convoy_vbox.add_child(_make_label("Нет активных рейсов по узлу.", 12, TacticalTheme.COL_MUTED))
		return

	for convoy: Convoy in active_list:
		var row: PanelContainer = PanelContainer.new()
		row.add_theme_stylebox_override("panel", TacticalTheme.make_panel_box(Color("#1b1f18E6"), TacticalTheme.COL_BORDER, 2, 5))
		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 3)
		row.add_child(vbox)

		var orig_n: SimTypes.MapNode = engine.graph.get_node(convoy.origin_node_id)
		var dest_n: SimTypes.MapNode = engine.graph.get_node(convoy.destination_node_id)
		var o_name: String = orig_n.display_name if orig_n != null else convoy.origin_node_id
		var d_name: String = dest_n.display_name if dest_n != null else convoy.destination_node_id
		var arrow: String = "←" if convoy.is_returning else "→"
		var fuel_pct: int = int(round((convoy.fuel_tank / maxf(0.01, convoy.fuel_tank_capacity)) * 100.0))
		var state_txt: String = SimTypes.convoy_state_label(convoy.state)
		if convoy.is_disabled():
			var rem_h: float = float(convoy.disabled_ticks_remaining) / float(SimEngine.TICKS_PER_HOUR)
			state_txt = "КАПРЕМОНТ %.1fч" % rem_h
		elif convoy.is_waiting_night:
			state_txt = "ЖДЁТ НОЧИ"
		elif convoy.is_queued:
			state_txt = "ОЧЕРЕДЬ"
		var wound_txt: String = " | Ран:%.0f" % convoy.carried_wounded if convoy.carried_wounded >= 1.0 else ""
		var hp_txt: String = " | HP %d%%" % int(round(convoy.hp)) if convoy.hp < 99.5 else ""

		var top_lbl: Label = _make_label(
			"%s (%s) [%s] %s %s %s\n%s: %.0fт • Бак %d%%%s%s" % [
				convoy.callsign,
				SimTypes.convoy_type_label(convoy.convoy_type),
				state_txt,
				o_name,
				arrow,
				d_name,
				SimTypes.cargo_pref_label(convoy.cargo_preference),
				convoy.get_total_cargo(),
				fuel_pct,
				hp_txt,
				wound_txt,
			],
			11,
			TacticalTheme.COL_CRITICAL if convoy.is_disabled() else TacticalTheme.COL_TEXT
		)
		top_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(top_lbl)

		if convoy.is_disabled():
			_active_convoy_vbox.add_child(row)
			continue

		var btn_row: HBoxContainer = HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 4)
		vbox.add_child(btn_row)

		var cid: String = convoy.id
		if (convoy.convoy_type == SimTypes.ConvoyType.CARGO or convoy.convoy_type == SimTypes.ConvoyType.ARMORED) and convoy.order_mode != SimTypes.OrderMode.REDEPLOY:
			var cargo_btn: Button = Button.new()
			cargo_btn.text = "Груз"
			cargo_btn.tooltip_text = "Сменить тип груза"
			cargo_btn.add_theme_font_size_override("font_size", 11)
			cargo_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cargo_btn.pressed.connect(func() -> void: cycle_convoy_cargo_requested.emit(cid))
			btn_row.add_child(cargo_btn)

		var night_btn: Button = Button.new()
		night_btn.text = "Ночь"
		night_btn.toggle_mode = true
		night_btn.button_pressed = convoy.night_only
		night_btn.modulate = Color("#8fb4dc") if convoy.night_only else TacticalTheme.COL_TEXT
		night_btn.tooltip_text = "Ездить только ночью (20:00–06:00)"
		night_btn.add_theme_font_size_override("font_size", 11)
		night_btn.pressed.connect(func() -> void: convoy_night_toggled.emit(cid))
		btn_row.add_child(night_btn)

		if convoy.order_mode != SimTypes.OrderMode.REDEPLOY:
			var evac_btn: Button = Button.new()
			evac_btn.text = "Мед"
			evac_btn.toggle_mode = true
			evac_btn.button_pressed = convoy.evacuate_wounded
			evac_btn.modulate = TacticalTheme.COL_OK if convoy.evacuate_wounded else TacticalTheme.COL_TEXT
			evac_btn.tooltip_text = "Вывозить раненых обратным рейсом"
			evac_btn.add_theme_font_size_override("font_size", 11)
			evac_btn.pressed.connect(func() -> void: convoy_evac_toggled.emit(cid))
			btn_row.add_child(evac_btn)

		if convoy.loop:
			var stop_btn: Button = Button.new()
			stop_btn.text = "Стоп"
			stop_btn.add_theme_font_size_override("font_size", 11)
			stop_btn.pressed.connect(func() -> void: stop_loop_requested.emit(cid))
			btn_row.add_child(stop_btn)

		_active_convoy_vbox.add_child(row)


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = TacticalTheme.build_theme()
	add_child(_root)

	_build_top_bar()
	_build_autopause_banner()
	_build_summary_panel()
	_build_radiogram_banner()
	_build_bottom_left_controls()
	_build_legend_panel()
	_build_inspector()
	_build_hover_tooltip()
	_build_pause_modal()
	_build_debrief_modal()


func _build_top_bar() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_bottom = TOP_BAR_H
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", TacticalTheme.make_panel_box(TacticalTheme.COL_PANEL_DARK, TacticalTheme.COL_BORDER, 0, 4))
	_root.add_child(panel)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 5)
	panel.add_child(hbox)

	_title_label = _make_label("ОП.«РУБЕЖ»", 13, TacticalTheme.COL_ACCENT, true)
	hbox.add_child(_title_label)
	_phase_label = _make_mono_label("Ф1:0%", 11, TacticalTheme.COL_ACCENT)
	hbox.add_child(_phase_label)
	hbox.add_child(_make_vsep())

	_time_label = _make_mono_label("Д1 06:00", 11, TacticalTheme.COL_TEXT)
	hbox.add_child(_time_label)

	_day_night_icon = _make_icon("sunrise", 13)
	hbox.add_child(_day_night_icon)
	_day_night_label = _make_label("ДЕНЬ", 11, TacticalTheme.COL_ACCENT, true)
	hbox.add_child(_day_night_label)

	_weather_icon = _make_icon("heavy-rain", 13)
	hbox.add_child(_weather_icon)
	_weather_label = _make_label("ЯСНО", 11, TacticalTheme.COL_TEXT, true)
	hbox.add_child(_weather_label)

	hbox.add_child(_make_vsep())
	hbox.add_child(_make_icon("radar-sweep", 13, TacticalTheme.COL_ACCENT))
	_recon_label = _make_mono_label("Разв.08:00", 11, TacticalTheme.COL_TEXT)
	hbox.add_child(_recon_label)

	hbox.add_child(_make_icon("steam-locomotive", 13, TacticalTheme.COL_FRIENDLY))
	_train_timer_label = _make_mono_label("Эш.08:00", 11, TacticalTheme.COL_TEXT)
	hbox.add_child(_train_timer_label)

	hbox.add_child(_make_vsep())
	hbox.add_child(_make_icon("jerrycan", 12, TacticalTheme.COL_FUEL))
	_front_fuel_label = _make_mono_label("0", 11, TacticalTheme.COL_TEXT)
	hbox.add_child(_front_fuel_label)

	hbox.add_child(_make_icon("ammo-box", 12, TacticalTheme.COL_AMMO))
	_front_ammo_label = _make_mono_label("0", 11, TacticalTheme.COL_TEXT)
	hbox.add_child(_front_ammo_label)

	hbox.add_child(_make_icon("medicines", 12, Color("#7ac4ac")))
	_front_prov_label = _make_mono_label("0", 11, TacticalTheme.COL_TEXT)
	hbox.add_child(_front_prov_label)

	hbox.add_child(_make_icon("wrench", 12, Color("#9db0c4")))
	_front_parts_label = _make_mono_label("0", 11, TacticalTheme.COL_TEXT)
	hbox.add_child(_front_parts_label)

	hbox.add_child(_make_vsep())
	hbox.add_child(_make_icon("flatbed-covered", 13, TacticalTheme.COL_FRIENDLY))
	_free_convoys_label = _make_mono_label("14/14", 11, TacticalTheme.COL_TEXT)
	hbox.add_child(_free_convoys_label)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var sp_specs: Array = [
		[0.0, "Пауза", "pause-button"],
		[0.5, "0.5x", ""],
		[1.0, "1x", ""],
		[2.0, "2x", ""],
		[4.0, "4x", ""],
		[8.0, "8x", ""],
	]
	_speed_entries.clear()
	for spec_var: Variant in sp_specs:
		var spec: Array = spec_var
		var sp_val: float = float(spec[0])
		var sp_txt: String = str(spec[1])
		var sp_ico: String = str(spec[2])
		var btn: Button = Button.new()
		btn.text = sp_txt
		if not sp_ico.is_empty():
			btn.icon = TacticalTheme.load_icon(sp_ico)
			btn.expand_icon = true
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(38.0 if sp_ico.is_empty() else 52.0, 26.0)
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(func() -> void: speed_selected.emit(sp_val))
		hbox.add_child(btn)
		_speed_entries.append({"speed": sp_val, "button": btn})


func _build_summary_panel() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.offset_left = 10.0
	panel.offset_top = TOP_BAR_H + 8.0
	panel.offset_right = 10.0 + SUMMARY_W
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", TacticalTheme.make_panel_box(TacticalTheme.COL_PANEL, TacticalTheme.COL_BORDER, 2, 7))
	_root.add_child(panel)

	var outer_vbox: VBoxContainer = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 5)
	panel.add_child(outer_vbox)

	var hdr: HBoxContainer = HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 4)
	outer_vbox.add_child(hdr)
	var hdr_lbl: Label = _make_label("СВОДКА И ЖУРНАЛ", 13, TacticalTheme.COL_ACCENT, true)
	hdr_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(hdr_lbl)

	_log_expand_btn = Button.new()
	_log_expand_btn.text = "Шире"
	_log_expand_btn.custom_minimum_size = Vector2(42.0, 20.0)
	_log_expand_btn.add_theme_font_size_override("font_size", 10)
	_log_expand_btn.pressed.connect(_on_toggle_log_expand)
	hdr.add_child(_log_expand_btn)

	_summary_toggle_btn = Button.new()
	_summary_toggle_btn.text = "−"
	_summary_toggle_btn.custom_minimum_size = Vector2(24.0, 20.0)
	_summary_toggle_btn.pressed.connect(_on_toggle_summary)
	hdr.add_child(_summary_toggle_btn)

	_summary_body = VBoxContainer.new()
	_summary_body.add_theme_constant_override("separation", 3)
	outer_vbox.add_child(_summary_body)

	var sig_row: HBoxContainer = HBoxContainer.new()
	sig_row.add_theme_constant_override("separation", 5)
	_summary_body.add_child(sig_row)
	sig_row.add_child(_make_icon("radar-sweep", 13, TacticalTheme.COL_ACCENT))
	_summary_sig_label = _make_label("Сигнатура: 12%", 12, TacticalTheme.COL_TEXT)
	sig_row.add_child(_summary_sig_label)

	_summary_arty_label = _make_label("АДН: С-ожид | Ю-ожид", 12, TacticalTheme.COL_MUTED)
	_summary_body.add_child(_summary_arty_label)

	_summary_obj_label = _make_mono_label("Цели: К 0% • П 0% • Ю 0%", 11, TacticalTheme.COL_TEXT)
	_summary_body.add_child(_summary_obj_label)

	_summary_wounded_label = _make_label("Раненые: 0 (эвак. 0)", 12, TacticalTheme.COL_TEXT)
	_summary_body.add_child(_summary_wounded_label)

	_summary_mod_label = _make_label("Модернизировано II: 0 / 2", 12, Color("#f0c248"))
	_summary_mod_label.visible = false
	_summary_body.add_child(_summary_mod_label)

	_summary_body.add_child(HSeparator.new())

	_log_rtl = RichTextLabel.new()
	_log_rtl.bbcode_enabled = true
	_log_rtl.scroll_following = true
	_log_rtl.custom_minimum_size = Vector2(0.0, 110.0)
	_log_rtl.add_theme_font_size_override("normal_font_size", 11)
	_log_rtl.meta_clicked.connect(_on_log_meta_clicked)
	_summary_body.add_child(_log_rtl)


func _build_radiogram_banner() -> void:
	_radio_panel = PanelContainer.new()
	_radio_panel.anchor_left = 0.0
	_radio_panel.anchor_top = 0.0
	_radio_panel.offset_left = 266.0
	_radio_panel.offset_top = TOP_BAR_H + 8.0
	_radio_panel.offset_right = 710.0
	_radio_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_radio_panel.visible = false
	_radio_panel.add_theme_stylebox_override("panel", TacticalTheme.make_panel_box(Color("#20241cF0"), TacticalTheme.COL_ACCENT, 2, 7))
	_root.add_child(_radio_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_radio_panel.add_child(vbox)

	var hdr: HBoxContainer = HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 6)
	vbox.add_child(hdr)
	hdr.add_child(_make_icon("walkie-talkie", 15, TacticalTheme.COL_ACCENT))
	_radio_sender_lbl = _make_label("РАДИОГРАММА", 13, TacticalTheme.COL_ACCENT, true)
	_radio_sender_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(_radio_sender_lbl)

	var jump_btn: Button = Button.new()
	jump_btn.text = "К узлу"
	jump_btn.add_theme_font_size_override("font_size", 11)
	jump_btn.pressed.connect(func() -> void:
		if not _active_rad_node_id.is_empty():
			radiogram_jump_requested.emit(_active_rad_node_id)
	)
	hdr.add_child(jump_btn)

	var close_btn: Button = Button.new()
	close_btn.text = "×"
	close_btn.custom_minimum_size = Vector2(22.0, 20.0)
	close_btn.pressed.connect(func() -> void:
		if not _active_rad_id.is_empty():
			radiogram_dismissed.emit(_active_rad_id)
	)
	hdr.add_child(close_btn)

	_radio_text_lbl = _make_label("", 13, TacticalTheme.COL_TEXT)
	_radio_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_radio_text_lbl)


func _build_bottom_left_controls() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 10.0
	panel.offset_bottom = -10.0
	panel.offset_top = -78.0
	panel.offset_right = 412.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", TacticalTheme.make_panel_box(TacticalTheme.COL_PANEL, TacticalTheme.COL_BORDER, 2, 6))
	_root.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)

	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	vbox.add_child(top_row)

	_scale_bar_ctrl = Control.new()
	_scale_bar_ctrl.custom_minimum_size = Vector2(236.0, 24.0)
	_scale_bar_ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scale_bar_ctrl.draw.connect(_draw_scale_bar)
	top_row.add_child(_scale_bar_ctrl)

	var zoom_out_btn: Button = Button.new()
	zoom_out_btn.text = "−"
	zoom_out_btn.custom_minimum_size = Vector2(26.0, 22.0)
	zoom_out_btn.pressed.connect(func() -> void: zoom_out_requested.emit())
	top_row.add_child(zoom_out_btn)

	var zoom_in_btn: Button = Button.new()
	zoom_in_btn.text = "+"
	zoom_in_btn.custom_minimum_size = Vector2(26.0, 22.0)
	zoom_in_btn.pressed.connect(func() -> void: zoom_in_requested.emit())
	top_row.add_child(zoom_in_btn)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	vbox.add_child(btn_row)

	var layers: Array = [
		["distances", "Дистанции", false],
		["threats", "Угрозы", false],
		["routes", "Маршруты", true],
	]
	for item_var: Variant in layers:
		var item: Array = item_var
		var lname: String = str(item[0])
		var ltext: String = str(item[1])
		var ldef: bool = bool(item[2])
		var btn: Button = Button.new()
		btn.text = ltext
		btn.toggle_mode = true
		btn.button_pressed = ldef
		btn.add_theme_font_size_override("font_size", 12)
		btn.toggled.connect(func(on: bool) -> void: layer_toggled.emit(lname, on))
		btn_row.add_child(btn)

	var legend_btn: Button = Button.new()
	legend_btn.text = "? Легенда"
	legend_btn.toggle_mode = true
	legend_btn.add_theme_font_size_override("font_size", 12)
	legend_btn.toggled.connect(func(on: bool) -> void: _legend_panel.visible = on)
	btn_row.add_child(legend_btn)


func _build_legend_panel() -> void:
	_legend_panel = PanelContainer.new()
	_legend_panel.anchor_left = 0.0
	_legend_panel.anchor_top = 1.0
	_legend_panel.anchor_bottom = 1.0
	_legend_panel.offset_left = 10.0
	_legend_panel.offset_bottom = -86.0
	_legend_panel.offset_top = -376.0
	_legend_panel.offset_right = 412.0
	_legend_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_legend_panel.visible = false
	_legend_panel.add_theme_stylebox_override("panel", TacticalTheme.make_panel_box(TacticalTheme.COL_PANEL_DARK, TacticalTheme.COL_BORDER_HI, 2, 8))
	_root.add_child(_legend_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_legend_panel.add_child(vbox)
	vbox.add_child(_make_label("УСЛОВНЫЕ ОБОЗНАЧЕНИЯ КАРТЫ", 13, TacticalTheme.COL_ACCENT, true))

	var legend_rows: Array = [
		["flatbed-covered", TacticalTheme.COL_FRIENDLY, "Бортовая (30т) — БК, Пров, Запч; до 10т ГСМ"],
		["gas-pump", TacticalTheme.COL_FUEL, "АТЗ (40т) — только Топливо; вязнет в распутице"],
		["bulldozer", TacticalTheme.COL_AMMO, "Инженерная (26т) — мосты, разминирование, полевые склады"],
		["apc", Color("#7ec8e3"), "БТР (12т) — любые грузы, 90% защиты от обстрела, -60% сигн."],
		["barracks-tent", Color("#8fb868"), "Пунктирная площадка — место под полевой склад (25т ЗП + 4 ч)"],
		["allied-star", Color("#f0c248"), "Уровень II (30т ПЕР) — +35% к бою и прорыву, -20% расхода БК"],
		["hazard-sign", TacticalTheme.COL_FUEL, "Оранжевый знак / штрих — дорога разбита или под артобстрелом"],
		["teller-mine", TacticalTheme.COL_CRITICAL, "Мина — заминированный участок после прорыва"],
		["broken-wall", TacticalTheme.COL_CRITICAL, "Мост повреждён — скорость 15%, ремонт Инж. + 20т ЗП"],
		["radar-sweep", TacticalTheme.COL_CRITICAL, "Угроза удара — сигнатура склада >= 75% при разведке"],
		["convergence-target", TacticalTheme.COL_CRITICAL, "Целевой узел — захватить в Фазе 2 для прорыва"],
	]
	for item_var: Variant in legend_rows:
		var item: Array = item_var
		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)
		hbox.add_child(_make_icon(str(item[0]), 14, item[1]))
		var lbl: Label = _make_label(str(item[2]), 11, TacticalTheme.COL_TEXT)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl)
		vbox.add_child(hbox)


func _build_hover_tooltip() -> void:
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.visible = false
	_tooltip_panel.custom_minimum_size = Vector2(220.0, 0.0)
	_tooltip_panel.add_theme_stylebox_override("panel", TacticalTheme.make_panel_box(Color("#191d16F2"), TacticalTheme.COL_BORDER_HI, 2, 7))
	_root.add_child(_tooltip_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 3)
	_tooltip_panel.add_child(vbox)

	_tooltip_title = _make_label("", 13, TacticalTheme.COL_ACCENT, true)
	_tooltip_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_tooltip_title)

	_tooltip_sub = _make_label("", 11, TacticalTheme.COL_MUTED)
	_tooltip_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_tooltip_sub)

	_tooltip_body = _make_label("", 11, TacticalTheme.COL_TEXT)
	_tooltip_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_tooltip_body)

	_tooltip_warn = _make_label("", 11, TacticalTheme.COL_CRITICAL, true)
	_tooltip_warn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_tooltip_warn)


func _draw_scale_bar() -> void:
	var font_mono: Font = TacticalTheme.get_mono_font()
	if font_mono == null:
		font_mono = ThemeDB.fallback_font
	var km20_px: float = clampf(20.0 * PX_PER_KM * _camera_zoom, 42.0, 210.0)
	var half_px: float = km20_px * 0.5
	var origin: Vector2 = Vector2(4.0, 14.0)

	_scale_bar_ctrl.draw_rect(Rect2(origin, Vector2(half_px, 5.0)), TacticalTheme.COL_TEXT, true)
	_scale_bar_ctrl.draw_rect(Rect2(origin + Vector2(half_px, 0.0), Vector2(half_px, 5.0)), TacticalTheme.COL_MUTED, true)
	_scale_bar_ctrl.draw_rect(Rect2(origin, Vector2(km20_px, 5.0)), Color("#181b15"), false, 1.0)

	_scale_bar_ctrl.draw_string(font_mono, Vector2(origin.x, 11.0), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, TacticalTheme.COL_TEXT)
	_scale_bar_ctrl.draw_string(font_mono, Vector2(origin.x + half_px - 6.0, 11.0), "10", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, TacticalTheme.COL_TEXT)
	_scale_bar_ctrl.draw_string(font_mono, Vector2(origin.x + km20_px - 8.0, 11.0), "20 км", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, TacticalTheme.COL_ACCENT)


func _build_inspector() -> void:
	_inspector_panel = PanelContainer.new()
	_inspector_panel.anchor_left = 1.0
	_inspector_panel.anchor_right = 1.0
	_inspector_panel.anchor_top = 0.0
	_inspector_panel.anchor_bottom = 1.0
	_inspector_panel.offset_left = -(INSPECTOR_W + 10.0)
	_inspector_panel.offset_right = -10.0
	_inspector_panel.offset_top = TOP_BAR_H + 8.0
	_inspector_panel.offset_bottom = -10.0
	_inspector_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_inspector_panel.add_theme_stylebox_override("panel", TacticalTheme.make_panel_box(TacticalTheme.COL_PANEL, TacticalTheme.COL_BORDER, 2, 8))
	_root.add_child(_inspector_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_inspector_panel.add_child(vbox)

	var title_row: HBoxContainer = HBoxContainer.new()
	vbox.add_child(title_row)
	_node_title_label = _make_label("Узел", 15, TacticalTheme.COL_TEXT, true)
	_node_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_node_title_label)

	var close_btn: Button = Button.new()
	close_btn.text = "×"
	close_btn.custom_minimum_size = Vector2(24.0, 22.0)
	close_btn.pressed.connect(func() -> void: inspector_closed.emit())
	title_row.add_child(close_btn)

	_node_type_label = _make_label("", 12, TacticalTheme.COL_MUTED)
	vbox.add_child(_node_type_label)

	_stock_section = VBoxContainer.new()
	_stock_section.add_theme_constant_override("separation", 3)
	vbox.add_child(_stock_section)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 3)
	_stock_section.add_child(grid)

	var res_specs: Array = [
		[SimTypes.ResourceType.FUEL, "jerrycan", TacticalTheme.COL_FUEL],
		[SimTypes.ResourceType.AMMO, "ammo-box", TacticalTheme.COL_AMMO],
		[SimTypes.ResourceType.PROVISIONS, "medicines", Color("#7ac4ac")],
		[SimTypes.ResourceType.PARTS, "wrench", Color("#9db0c4")],
		[SimTypes.ResourceType.EQUIPMENT, "allied-star", Color("#f0c248")],
	]
	for spec_var: Variant in res_specs:
		var spec: Array = spec_var
		var rtype: SimTypes.ResourceType = spec[0]
		var ico: String = str(spec[1])
		var col: Color = spec[2]
		var cell: VBoxContainer = VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 1)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.add_child(_make_icon(ico, 12, col))
		var rlbl: Label = _make_mono_label("0/0", 11, TacticalTheme.COL_TEXT)
		row.add_child(rlbl)
		var rbar: ProgressBar = _make_bar(col)
		rbar.custom_minimum_size = Vector2(0.0, 7.0)
		cell.add_child(row)
		cell.add_child(rbar)
		grid.add_child(cell)
		_res_labels[int(rtype)] = rlbl
		_res_bars[int(rtype)] = rbar
		_res_cells[int(rtype)] = cell

	_depot_section = VBoxContainer.new()
	_depot_section.add_theme_constant_override("separation", 2)
	vbox.add_child(_depot_section)
	_sig_label = _make_label("Сигнатура:", 12, TacticalTheme.COL_TEXT)
	_depot_section.add_child(_sig_label)
	_sig_bar = _make_bar(TacticalTheme.COL_ACCENT)
	_depot_section.add_child(_sig_bar)
	_sig_breakdown_label = _make_mono_label("", 10, TacticalTheme.COL_MUTED)
	_sig_breakdown_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_depot_section.add_child(_sig_breakdown_label)
	_camo_button = Button.new()
	_camo_button.toggle_mode = true
	_camo_button.add_theme_font_size_override("font_size", 11)
	_camo_button.pressed.connect(func() -> void: camouflage_toggled.emit(_current_node_id))
	_depot_section.add_child(_camo_button)
	_slots_label = _make_label("Погрузочные места: 0/2", 11, TacticalTheme.COL_MUTED)
	_depot_section.add_child(_slots_label)
	_strike_warn_label = _make_label("", 12, TacticalTheme.COL_CRITICAL, true)
	_strike_warn_label.visible = false
	_depot_section.add_child(_strike_warn_label)

	_junction_section = VBoxContainer.new()
	_junction_section.visible = false
	vbox.add_child(_junction_section)
	_junction_info_label = _make_label(
		"Хранение грузов невозможно. Используйте для отстоя пустых колонн (Передислокация) или ремонта моста/дорог.",
		11,
		TacticalTheme.COL_MUTED
	)
	_junction_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_junction_section.add_child(_junction_info_label)

	_field_depot_section = VBoxContainer.new()
	_field_depot_section.visible = false
	_field_depot_section.add_theme_constant_override("separation", 3)
	vbox.add_child(_field_depot_section)
	_field_depot_info_lbl = _make_label("Площадка полевого склада", 11, TacticalTheme.COL_TEXT)
	_field_depot_info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_field_depot_section.add_child(_field_depot_info_lbl)
	_field_depot_bar = _make_bar(TacticalTheme.COL_OK)
	_field_depot_section.add_child(_field_depot_bar)
	_field_depot_btn = Button.new()
	_field_depot_btn.text = "Развернуть полевой склад"
	_field_depot_btn.add_theme_font_size_override("font_size", 11)
	_field_depot_btn.pressed.connect(func() -> void:
		if _field_depot_btn.text.begins_with("Свернуть"):
			pack_depot_requested.emit(_current_node_id)
		else:
			deploy_depot_requested.emit(_current_node_id)
	)
	_field_depot_section.add_child(_field_depot_btn)

	_front_section = VBoxContainer.new()
	_front_section.add_theme_constant_override("separation", 2)
	vbox.add_child(_front_section)
	_integrity_label = _make_label("Целостность:", 12, TacticalTheme.COL_TEXT)
	_front_section.add_child(_integrity_label)
	_integrity_bar = _make_bar(TacticalTheme.COL_OK)
	_front_section.add_child(_integrity_bar)
	var f_meta: HBoxContainer = HBoxContainer.new()
	f_meta.add_theme_constant_override("separation", 10)
	_front_section.add_child(f_meta)
	_intensity_label = _make_label("Бой:", 12, TacticalTheme.COL_MUTED)
	_wounded_label = _make_label("Раненые: 0", 12, TacticalTheme.COL_TEXT)
	f_meta.add_child(_intensity_label)
	f_meta.add_child(_wounded_label)

	_arty_section = VBoxContainer.new()
	_arty_section.visible = false
	vbox.add_child(_arty_section)
	_arty_status_label = _make_label("", 12, TacticalTheme.COL_OK, true)
	_arty_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_arty_section.add_child(_arty_status_label)

	_reequip_section = VBoxContainer.new()
	_reequip_section.visible = false
	_reequip_section.add_theme_constant_override("separation", 2)
	vbox.add_child(_reequip_section)
	_reequip_label = _make_label("Оснащение: Уровень I", 11, Color("#f0c248"))
	_reequip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reequip_section.add_child(_reequip_label)
	_reequip_bar = _make_bar(Color("#f0c248"))
	_reequip_section.add_child(_reequip_bar)

	_bridge_section = VBoxContainer.new()
	_bridge_section.visible = false
	vbox.add_child(_bridge_section)
	_bridge_status_label = _make_label("", 12, TacticalTheme.COL_TEXT, true)
	_bridge_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bridge_section.add_child(_bridge_status_label)

	_objective_section = VBoxContainer.new()
	_objective_section.visible = false
	_objective_section.add_theme_constant_override("separation", 2)
	vbox.add_child(_objective_section)
	_objective_label = _make_label("Захват:", 12, TacticalTheme.COL_ACCENT, true)
	_objective_section.add_child(_objective_label)
	_objective_bar = _make_bar(TacticalTheme.COL_ACCENT)
	_objective_bar.max_value = 100.0
	_objective_section.add_child(_objective_bar)

	_train_section = VBoxContainer.new()
	_train_section.visible = false
	_train_section.add_theme_constant_override("separation", 4)
	vbox.add_child(_train_section)
	_train_section.add_child(HSeparator.new())
	_train_header_label = _make_label("Сборка эшелона:", 12, TacticalTheme.COL_ACCENT, true)
	_train_header_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_train_section.add_child(_train_header_label)

	_train_target_row = HBoxContainer.new()
	_train_target_row.add_theme_constant_override("separation", 4)
	_train_section.add_child(_train_target_row)

	_train_grid = GridContainer.new()
	_train_grid.columns = 3
	_train_grid.add_theme_constant_override("h_separation", 4)
	_train_grid.add_theme_constant_override("v_separation", 4)
	_train_section.add_child(_train_grid)
	_ensure_train_slot_buttons(6)

	_train_truck_btn = Button.new()
	_train_truck_btn.text = "+Заказать колонну (2 слота)"
	_train_truck_btn.add_theme_font_size_override("font_size", 11)
	_train_truck_btn.pressed.connect(func() -> void: train_truck_cycled.emit())
	_train_section.add_child(_train_truck_btn)

	_train_equip_btn = Button.new()
	_train_equip_btn.text = "+Платформа перевооружения (30т, 2 слота)"
	_train_equip_btn.add_theme_font_size_override("font_size", 11)
	_train_equip_btn.pressed.connect(func() -> void: train_equipment_toggled.emit())
	_train_section.add_child(_train_equip_btn)

	_dispatch_section = VBoxContainer.new()
	_dispatch_section.add_theme_constant_override("separation", 3)
	vbox.add_child(_dispatch_section)
	_dispatch_section.add_child(HSeparator.new())

	_idle_at_node_label = _make_label("Свободно: Борт 0 • АТЗ 0 • Инж 0 • БТР 0", 12, TacticalTheme.COL_FRIENDLY, true)
	_dispatch_section.add_child(_idle_at_node_label)

	var opt_row: HBoxContainer = HBoxContainer.new()
	opt_row.add_theme_constant_override("separation", 4)
	_dispatch_section.add_child(opt_row)

	_type_option = OptionButton.new()
	_type_option.add_theme_font_size_override("font_size", 11)
	_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_type_option.add_item("Бортовая (30т)")
	_type_option.add_item("АТЗ Топл. (40т)")
	_type_option.add_item("Инженерн. (26т)")
	_type_option.add_item("БТР Бронеподвоз (12т)")
	_type_option.item_selected.connect(func(_i: int) -> void: dispatch_options_changed.emit())
	opt_row.add_child(_type_option)

	_mode_option = OptionButton.new()
	_mode_option.add_theme_font_size_override("font_size", 11)
	_mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode_option.add_item("Разовый + возврат")
	_mode_option.add_item("Передислокация")
	_mode_option.add_item("Циклический")
	_mode_option.select(2)
	_mode_option.item_selected.connect(func(_i: int) -> void: dispatch_options_changed.emit())
	opt_row.add_child(_mode_option)

	_cargo_option = OptionButton.new()
	_cargo_option.add_theme_font_size_override("font_size", 11)
	_cargo_option.add_item("Груз: Смешанный")
	_cargo_option.add_item("Груз: Топливо (ГСМ)")
	_cargo_option.add_item("Груз: Боеприпасы (БК)")
	_cargo_option.add_item("Груз: Провизия/Мед (ПР)")
	_cargo_option.add_item("Груз: Запчасти/Рем (ЗП)")
	_cargo_option.add_item("Груз: Перевооружение (ПЕР)")
	_cargo_option.item_selected.connect(func(_i: int) -> void: dispatch_options_changed.emit())
	_dispatch_section.add_child(_cargo_option)

	var chk_row: HBoxContainer = HBoxContainer.new()
	chk_row.add_theme_constant_override("separation", 6)
	_dispatch_section.add_child(chk_row)

	_evac_checkbox = CheckBox.new()
	_evac_checkbox.text = "Вывоз раненых"
	_evac_checkbox.button_pressed = true
	_evac_checkbox.add_theme_font_size_override("font_size", 11)
	chk_row.add_child(_evac_checkbox)

	_night_checkbox = CheckBox.new()
	_night_checkbox.text = "Только ночью"
	_night_checkbox.button_pressed = false
	_night_checkbox.add_theme_font_size_override("font_size", 11)
	chk_row.add_child(_night_checkbox)

	_dispatch_hint_label = _make_label("", 11, TacticalTheme.COL_ACCENT)
	_dispatch_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dispatch_hint_label.visible = false
	_dispatch_section.add_child(_dispatch_hint_label)

	_aim_button = Button.new()
	_aim_button.text = "Назначить маршрут (клик по карте)"
	_aim_button.icon = TacticalTheme.load_icon("crosshair")
	_aim_button.expand_icon = true
	_aim_button.custom_minimum_size = Vector2(0.0, 28.0)
	_aim_button.add_theme_font_size_override("font_size", 12)
	_aim_button.pressed.connect(func() -> void: route_aim_toggled.emit(_current_node_id))
	_dispatch_section.add_child(_aim_button)

	vbox.add_child(HSeparator.new())
	vbox.add_child(_make_label("Активные маршруты (или ПКМ по цели)", 11, TacticalTheme.COL_MUTED))

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_active_convoy_vbox = VBoxContainer.new()
	_active_convoy_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_active_convoy_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(_active_convoy_vbox)


func _on_toggle_summary() -> void:
	_summary_body.visible = not _summary_body.visible
	_summary_toggle_btn.text = "−" if _summary_body.visible else "+"


func _on_toggle_log_expand() -> void:
	_log_expanded = not _log_expanded
	_log_rtl.custom_minimum_size = Vector2(0.0, 260.0 if _log_expanded else 110.0)
	_log_expand_btn.text = "Сверн." if _log_expanded else "Шире"


func _on_log_meta_clicked(meta: Variant) -> void:
	var idx: int = int(str(meta))
	event_clicked.emit(idx)


func _build_autopause_banner() -> void:
	_autopause_banner = PanelContainer.new()
	_autopause_banner.anchor_left = 0.5
	_autopause_banner.anchor_right = 0.5
	_autopause_banner.anchor_top = 0.0
	_autopause_banner.offset_left = -245.0
	_autopause_banner.offset_right = 245.0
	_autopause_banner.offset_top = TOP_BAR_H + 8.0
	_autopause_banner.mouse_filter = Control.MOUSE_FILTER_STOP
	_autopause_banner.visible = false
	_autopause_banner.add_theme_stylebox_override("panel", TacticalTheme.make_panel_box(Color("#252218F5"), TacticalTheme.COL_ACCENT, 2, 7))
	_root.add_child(_autopause_banner)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	_autopause_banner.add_child(hbox)

	hbox.add_child(_make_icon("pause-button", 14, TacticalTheme.COL_ACCENT))
	_autopause_label = _make_label("АВТОПАУЗА", 13, TacticalTheme.COL_ACCENT, true)
	_autopause_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_autopause_label)

	var close_btn: Button = Button.new()
	close_btn.text = "×"
	close_btn.custom_minimum_size = Vector2(22.0, 20.0)
	close_btn.pressed.connect(clear_autopause_notice)
	hbox.add_child(close_btn)


func _build_pause_modal() -> void:
	_pause_backdrop = ColorRect.new()
	_pause_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_backdrop.color = Color(0.05, 0.06, 0.05, 0.65)
	_pause_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_backdrop.visible = false
	_root.add_child(_pause_backdrop)

	_pause_modal = PanelContainer.new()
	_pause_modal.set_anchors_preset(Control.PRESET_CENTER)
	_pause_modal.offset_left = -190.0
	_pause_modal.offset_right = 190.0
	_pause_modal.offset_top = -175.0
	_pause_modal.offset_bottom = 175.0
	_pause_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_modal.visible = false
	_pause_modal.add_theme_stylebox_override("panel", TacticalTheme.make_panel_box(TacticalTheme.COL_PANEL_DARK, TacticalTheme.COL_BORDER_HI, 3, 18))
	_root.add_child(_pause_modal)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_pause_modal.add_child(vbox)

	var ptitle: Label = _make_label("ПАУЗА ОПЕРАЦИИ", 20, TacticalTheme.COL_ACCENT, true)
	ptitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(ptitle)
	vbox.add_child(HSeparator.new())

	var btn_resume: Button = Button.new()
	btn_resume.text = "Продолжить"
	btn_resume.custom_minimum_size = Vector2(0.0, 38.0)
	btn_resume.add_theme_color_override("font_color", TacticalTheme.COL_OK)
	btn_resume.pressed.connect(func() -> void: pause_resume_requested.emit())
	vbox.add_child(btn_resume)

	var btn_settings: Button = Button.new()
	btn_settings.text = "Настройки"
	btn_settings.custom_minimum_size = Vector2(0.0, 38.0)
	btn_settings.pressed.connect(func() -> void: pause_settings_requested.emit())
	vbox.add_child(btn_settings)

	var btn_restart: Button = Button.new()
	btn_restart.text = "Перезапустить операцию"
	btn_restart.custom_minimum_size = Vector2(0.0, 38.0)
	btn_restart.add_theme_color_override("font_color", TacticalTheme.COL_ACCENT)
	btn_restart.pressed.connect(func() -> void: pause_restart_requested.emit())
	vbox.add_child(btn_restart)

	_pause_hub_btn = Button.new()
	_pause_hub_btn.text = "Вернуться в штаб кампании"
	_pause_hub_btn.custom_minimum_size = Vector2(0.0, 38.0)
	_pause_hub_btn.pressed.connect(func() -> void: pause_hub_requested.emit())
	vbox.add_child(_pause_hub_btn)

	var btn_menu: Button = Button.new()
	btn_menu.text = "Главное меню"
	btn_menu.custom_minimum_size = Vector2(0.0, 38.0)
	btn_menu.pressed.connect(func() -> void: pause_main_menu_requested.emit())
	vbox.add_child(btn_menu)


func _build_debrief_modal() -> void:
	_debrief_backdrop = ColorRect.new()
	_debrief_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_debrief_backdrop.color = Color(0.04, 0.05, 0.04, 0.72)
	_debrief_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_debrief_backdrop.visible = false
	_root.add_child(_debrief_backdrop)

	_debrief_modal = PanelContainer.new()
	_debrief_modal.set_anchors_preset(Control.PRESET_CENTER)
	_debrief_modal.offset_left = -350.0
	_debrief_modal.offset_right = 350.0
	_debrief_modal.offset_top = -275.0
	_debrief_modal.offset_bottom = 275.0
	_debrief_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_debrief_modal.visible = false
	_debrief_modal.add_theme_stylebox_override("panel", TacticalTheme.make_panel_box(TacticalTheme.COL_PANEL_DARK, TacticalTheme.COL_BORDER_HI, 3, 20))
	_root.add_child(_debrief_modal)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_debrief_modal.add_child(vbox)

	_debrief_title_label = _make_label("ИТОГ ОПЕРАЦИИ", 24, TacticalTheme.COL_TEXT, true)
	_debrief_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_debrief_title_label)

	_debrief_reason_label = _make_label("", 15, TacticalTheme.COL_ACCENT)
	_debrief_reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_debrief_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_debrief_reason_label)

	vbox.add_child(HSeparator.new())

	vbox.add_child(_make_label("СВОДНАЯ СТАТИСТИКА ПОДВОЗА", 14, TacticalTheme.COL_FRIENDLY, true))
	_debrief_stats_label = _make_mono_label("", 13, TacticalTheme.COL_TEXT)
	_debrief_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_debrief_stats_label)

	vbox.add_child(HSeparator.new())
	vbox.add_child(_make_label("ВЫПОЛНЕНИЕ ЗАДАЧ ОПЕРАЦИИ", 14, TacticalTheme.COL_ACCENT, true))

	_debrief_obj_vbox = VBoxContainer.new()
	_debrief_obj_vbox.add_theme_constant_override("separation", 5)
	vbox.add_child(_debrief_obj_vbox)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	vbox.add_child(HSeparator.new())
	_debrief_cp_label = _make_label("", 14, TacticalTheme.COL_ACCENT, true)
	_debrief_cp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_debrief_cp_label)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	_debrief_hub_btn = Button.new()
	_debrief_hub_btn.text = "В штаб кампании"
	_debrief_hub_btn.custom_minimum_size = Vector2(200.0, 40.0)
	_debrief_hub_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_debrief_hub_btn.add_theme_color_override("font_color", TacticalTheme.COL_OK)
	_debrief_hub_btn.pressed.connect(func() -> void: debrief_continue_requested.emit())
	btn_row.add_child(_debrief_hub_btn)

	var retry_btn: Button = Button.new()
	retry_btn.text = "Переиграть"
	retry_btn.custom_minimum_size = Vector2(160.0, 40.0)
	retry_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retry_btn.pressed.connect(func() -> void: debrief_restart_requested.emit())
	btn_row.add_child(retry_btn)

	var menu_btn: Button = Button.new()
	menu_btn.text = "В главное меню"
	menu_btn.custom_minimum_size = Vector2(170.0, 40.0)
	menu_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_btn.pressed.connect(func() -> void: debrief_main_menu_requested.emit())
	btn_row.add_child(menu_btn)


func _make_label(text: String, font_size: int, col: Color, bold: bool = false) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", col)
	if bold:
		var bf: Font = TacticalTheme.get_bold_font()
		if bf != null:
			lbl.add_theme_font_override("font", bf)
	return lbl


func _make_mono_label(text: String, font_size: int, col: Color) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", col)
	var mf: Font = TacticalTheme.get_mono_medium_font()
	if mf != null:
		lbl.add_theme_font_override("font", mf)
	return lbl


func _make_icon(icon_name: String, sz: int, tint: Color = TacticalTheme.COL_TEXT) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.texture = TacticalTheme.load_icon(icon_name)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(float(sz), float(sz))
	rect.modulate = tint
	return rect


func _make_vsep() -> VSeparator:
	var sep: VSeparator = VSeparator.new()
	sep.modulate = TacticalTheme.COL_BORDER
	return sep


func _make_bar(fill_col: Color) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(0.0, 10.0)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", TacticalTheme.make_bar_bg())
	bar.add_theme_stylebox_override("fill", TacticalTheme.make_bar_fill(fill_col))
	return bar
