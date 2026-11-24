extends Control

var _campaign_id: String = ""
var _selected_op_id: String = ""

var _hdr_title_lbl: Label = null
var _hdr_cp_lbl: Label = null
var _ops_vbox: VBoxContainer = null
var _brief_title_lbl: Label = null
var _brief_status_lbl: Label = null
var _brief_text_lbl: Label = null
var _brief_primary_lbl: Label = null
var _brief_sec_vbox: VBoxContainer = null
var _launch_btn: Button = null
var _fleet_lbl: Label = null
var _upgrades_vbox: VBoxContainer = null


func _ready() -> void:
	theme = TacticalTheme.build_theme()
	_campaign_id = AppState.active_campaign_id
	if _campaign_id.is_empty():
		var fallback: String = AppState.get_most_recent_campaign_id()
		if fallback.is_empty() and not AppState.campaigns.is_empty():
			fallback = str(AppState.campaigns[0].get("id", ""))
		_campaign_id = fallback
	if not _campaign_id.is_empty():
		AppState.ensure_campaign_loaded(_campaign_id)

	_pick_initial_operation()
	_build_ui()
	_refresh_all()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var kev: InputEventKey = event
		if kev.pressed and not kev.echo and kev.keycode == KEY_ESCAPE:
			AppState.goto_campaign_select()
			get_viewport().set_input_as_handled()


func _pick_initial_operation() -> void:
	var camp: Dictionary = AppState.get_campaign_by_id(_campaign_id)
	var ops_raw: Variant = camp.get("operations", [])
	if typeof(ops_raw) != TYPE_ARRAY:
		return
	var ops: Array = ops_raw
	if not AppState.active_operation_id.is_empty():
		_selected_op_id = AppState.active_operation_id
		return
	for op_var: Variant in ops:
		if typeof(op_var) != TYPE_DICTIONARY:
			continue
		var op: Dictionary = op_var
		var oid: String = str(op.get("id", ""))
		if AppState.is_operation_unlocked(op) and not AppState.is_operation_completed(oid):
			_selected_op_id = oid
			return
	if not ops.is_empty() and typeof(ops[0]) == TYPE_DICTIONARY:
		_selected_op_id = str((ops[0] as Dictionary).get("id", ""))


func _build_ui() -> void:
	add_child(MenuBackdrop.new())

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 14)
	margin.add_child(root_vbox)

	# Top Bar
	var top_panel: PanelContainer = PanelContainer.new()
	top_panel.add_theme_stylebox_override("panel", TacticalTheme.make_panel_box(TacticalTheme.COL_PANEL_DARK, TacticalTheme.COL_BORDER_HI, 2, 10))
	root_vbox.add_child(top_panel)

	var top_hbox: HBoxContainer = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 12)
	top_panel.add_child(top_hbox)

	var back_btn: Button = Button.new()
	back_btn.text = "← Кампании"
	back_btn.custom_minimum_size = Vector2(128.0, 32.0)
	back_btn.pressed.connect(func() -> void: AppState.goto_campaign_select())
	top_hbox.add_child(back_btn)

	_hdr_title_lbl = _make_label("ШТАБ КАМПАНИИ", 20, TacticalTheme.COL_ACCENT, true)
	_hdr_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(_hdr_title_lbl)

	_hdr_cp_lbl = _make_mono_label("ОК: 0", 16, TacticalTheme.COL_OK)
	top_hbox.add_child(_hdr_cp_lbl)

	var menu_btn: Button = Button.new()
	menu_btn.text = "Главное меню"
	menu_btn.custom_minimum_size = Vector2(130.0, 32.0)
	menu_btn.pressed.connect(func() -> void: AppState.goto_main_menu())
	top_hbox.add_child(menu_btn)

	# 3-Column Body (1232px width total inside margins)
	var cols: HBoxContainer = HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 14)
	root_vbox.add_child(cols)

	# Left Column: Operation Chain (~300px)
	var left_panel: PanelContainer = PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(305.0, 0.0)
	left_panel.add_theme_stylebox_override("panel", TacticalTheme.make_panel_box(TacticalTheme.COL_PANEL_DARK, TacticalTheme.COL_BORDER, 2, 12))
	cols.add_child(left_panel)

	var left_vbox: VBoxContainer = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 8)
	left_panel.add_child(left_vbox)
	left_vbox.add_child(_make_label("ЦЕПОЧКА ОПЕРАЦИЙ", 15, TacticalTheme.COL_ACCENT, true))
	left_vbox.add_child(HSeparator.new())

	var ops_scroll: ScrollContainer = ScrollContainer.new()
	ops_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(ops_scroll)

	_ops_vbox = VBoxContainer.new()
	_ops_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ops_vbox.add_theme_constant_override("separation", 8)
	ops_scroll.add_child(_ops_vbox)

	# Center Column: Briefing & Launch
	var center_panel: PanelContainer = PanelContainer.new()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.add_theme_stylebox_override("panel", TacticalTheme.make_panel_box(TacticalTheme.COL_PANEL_DARK, TacticalTheme.COL_BORDER_HI, 2, 16))
	cols.add_child(center_panel)

	var center_vbox: VBoxContainer = VBoxContainer.new()
	center_vbox.add_theme_constant_override("separation", 10)
	center_panel.add_child(center_vbox)

	_brief_status_lbl = _make_mono_label("СТАТУС ОПЕРАЦИИ", 12, TacticalTheme.COL_ACCENT)
	center_vbox.add_child(_brief_status_lbl)

	_brief_title_lbl = _make_label("Операция", 24, TacticalTheme.COL_TEXT, true)
	_brief_title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center_vbox.add_child(_brief_title_lbl)

	center_vbox.add_child(HSeparator.new())

	var brief_scroll: ScrollContainer = ScrollContainer.new()
	brief_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_vbox.add_child(brief_scroll)

	var brief_inner: VBoxContainer = VBoxContainer.new()
	brief_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brief_inner.add_theme_constant_override("separation", 10)
	brief_scroll.add_child(brief_inner)

	brief_inner.add_child(_make_label("ОПЕРАТИВНАЯ ОБСТАНОВКА", 14, TacticalTheme.COL_FRIENDLY, true))
	_brief_text_lbl = _make_label("", 15, TacticalTheme.COL_TEXT)
	_brief_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief_inner.add_child(_brief_text_lbl)

	brief_inner.add_child(HSeparator.new())
	brief_inner.add_child(_make_label("ОСНОВНАЯ ЗАДАЧА", 14, TacticalTheme.COL_ACCENT, true))
	_brief_primary_lbl = _make_label("", 15, TacticalTheme.COL_TEXT)
	_brief_primary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief_inner.add_child(_brief_primary_lbl)

	brief_inner.add_child(HSeparator.new())
	brief_inner.add_child(_make_label("ПОБОЧНЫЕ ЗАДАЧИ (БОНУС ОК)", 14, TacticalTheme.COL_OK, true))
	_brief_sec_vbox = VBoxContainer.new()
	_brief_sec_vbox.add_theme_constant_override("separation", 6)
	brief_inner.add_child(_brief_sec_vbox)

	center_vbox.add_child(HSeparator.new())

	_launch_btn = Button.new()
	_launch_btn.text = "Начать операцию"
	_launch_btn.icon = TacticalTheme.load_icon("play-button")
	_launch_btn.expand_icon = true
	_launch_btn.custom_minimum_size = Vector2(0.0, 44.0)
	_launch_btn.add_theme_font_size_override("font_size", 17)
	_launch_btn.add_theme_color_override("font_color", TacticalTheme.COL_OK)
	_launch_btn.pressed.connect(_on_launch_pressed)
	center_vbox.add_child(_launch_btn)

	# Right Column: Logistics HQ & Upgrades (~410px)
	var right_panel: PanelContainer = PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(415.0, 0.0)
	right_panel.add_theme_stylebox_override("panel", TacticalTheme.make_panel_box(TacticalTheme.COL_PANEL_DARK, TacticalTheme.COL_BORDER, 2, 12))
	cols.add_child(right_panel)

	var right_vbox: VBoxContainer = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 8)
	right_panel.add_child(right_vbox)

	right_vbox.add_child(_make_label("ШТАБ ТЫЛА И МОДЕРНИЗАЦИЯ", 15, TacticalTheme.COL_ACCENT, true))
	_fleet_lbl = _make_mono_label("Автопарк: Борт 5 • АТЗ 3 • Инж 1", 13, TacticalTheme.COL_FRIENDLY)
	_fleet_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_vbox.add_child(_fleet_lbl)
	right_vbox.add_child(HSeparator.new())

	var upg_scroll: ScrollContainer = ScrollContainer.new()
	upg_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(upg_scroll)

	_upgrades_vbox = VBoxContainer.new()
	_upgrades_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrades_vbox.add_theme_constant_override("separation", 8)
	upg_scroll.add_child(_upgrades_vbox)


func _refresh_all() -> void:
	var camp: Dictionary = AppState.get_campaign_by_id(_campaign_id)
	var prog: Dictionary = AppState.get_campaign_progress(_campaign_id)
	var cp: int = int(AppState.current_save.get("command_points", 0))
	_hdr_title_lbl.text = "%s (%d/%d)" % [str(camp.get("name", "Кампания")), int(prog.get("completed", 0)), int(prog.get("total", 0))]
	_hdr_cp_lbl.text = "Очки командования: %d ОК" % cp

	_rebuild_operation_list(camp)
	_refresh_briefing()
	_rebuild_upgrades(cp)


func _rebuild_operation_list(camp: Dictionary) -> void:
	for child: Node in _ops_vbox.get_children():
		child.queue_free()

	var ops_raw: Variant = camp.get("operations", [])
	if typeof(ops_raw) != TYPE_ARRAY:
		return
	var ops: Array = ops_raw
	for op_var: Variant in ops:
		if typeof(op_var) != TYPE_DICTIONARY:
			continue
		var op: Dictionary = op_var
		var oid: String = str(op.get("id", ""))
		var coming_soon: bool = bool(op.get("coming_soon", false))
		var completed: bool = AppState.is_operation_completed(oid)
		var unlocked: bool = AppState.is_operation_unlocked(op)
		var selected: bool = (oid == _selected_op_id)

		var status_txt: String = "СКОРО"
		var status_col: Color = TacticalTheme.COL_MUTED
		if coming_soon:
			status_txt = "В РАЗРАБОТКЕ / СКОРО"
			status_col = TacticalTheme.COL_MUTED
		elif completed:
			status_txt = "ПРОЙДЕНА"
			status_col = TacticalTheme.COL_OK
		elif unlocked:
			status_txt = "ДОСТУПНА"
			status_col = TacticalTheme.COL_ACCENT
		else:
			status_txt = "ЗАБЛОКИРОВАНА"
			status_col = TacticalTheme.COL_CRITICAL

		var card: PanelContainer = PanelContainer.new()
		var b_col: Color = TacticalTheme.COL_ACCENT if selected else TacticalTheme.COL_BORDER
		var bg_col: Color = Color("#2b3226F5") if selected else Color("#1c2019E8")
		card.add_theme_stylebox_override("panel", TacticalTheme.make_panel_box(bg_col, b_col, 2, 8))
		_ops_vbox.add_child(card)

		var cv: VBoxContainer = VBoxContainer.new()
		cv.add_theme_constant_override("separation", 4)
		card.add_child(cv)

		var st_lbl: Label = _make_mono_label("%s • %d ч" % [status_txt, int(op.get("duration_hours", 48))], 11, status_col)
		cv.add_child(st_lbl)

		var btn: Button = Button.new()
		btn.text = str(op.get("name", oid))
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 15)
		btn.pressed.connect(func() -> void:
			_selected_op_id = oid
			_refresh_all()
		)
		cv.add_child(btn)


func _refresh_briefing() -> void:
	var op: Dictionary = AppState.get_operation_by_id(_campaign_id, _selected_op_id)
	if op.is_empty():
		_brief_title_lbl.text = "Выберите операцию"
		_launch_btn.disabled = true
		return

	var oid: String = str(op.get("id", ""))
	var coming_soon: bool = bool(op.get("coming_soon", false))
	var completed: bool = AppState.is_operation_completed(oid)
	var unlocked: bool = AppState.is_operation_unlocked(op)
	var mode_str: String = "Оборона" if str(op.get("mode", "OFFENSIVE")) == "DEFENSE" else "Наступление"

	if coming_soon:
		_brief_status_lbl.text = "ГЛАВА В РАЗРАБОТКЕ • %s" % mode_str
		_brief_status_lbl.modulate = TacticalTheme.COL_MUTED
	elif completed:
		_brief_status_lbl.text = "ОПЕРАЦИЯ ПРОЙДЕНА • %s • %d ч" % [mode_str, int(op.get("duration_hours", 48))]
		_brief_status_lbl.modulate = TacticalTheme.COL_OK
	elif unlocked:
		_brief_status_lbl.text = "ДОСТУПНА К ВЫПОЛНЕНИЮ • %s • %d ч" % [mode_str, int(op.get("duration_hours", 48))]
		_brief_status_lbl.modulate = TacticalTheme.COL_ACCENT
	else:
		_brief_status_lbl.text = "ЗАБЛОКИРОВАНА • ТРЕБУЕТСЯ ПРОЙТИ ПРЕДЫДУЩУЮ ОПЕРАЦИЮ"
		_brief_status_lbl.modulate = TacticalTheme.COL_CRITICAL

	_brief_title_lbl.text = str(op.get("name", oid))
	_brief_text_lbl.text = str(op.get("briefing", ""))
	_brief_primary_lbl.text = "%s (Награда: +%d ОК)" % [str(op.get("primary_objective", "")), int(op.get("reward_cp", 100))]

	for child: Node in _brief_sec_vbox.get_children():
		child.queue_free()

	var awarded_sec: Array = AppState.current_save.get("awarded_secondaries", [])
	var secs_raw: Variant = op.get("secondary_objectives", [])
	if typeof(secs_raw) == TYPE_ARRAY and not (secs_raw as Array).is_empty():
		var secs: Array = secs_raw
		for s_var: Variant in secs:
			if typeof(s_var) != TYPE_DICTIONARY:
				continue
			var s: Dictionary = s_var
			var skey: String = "%s::%s" % [oid, str(s.get("id", ""))]
			var done: bool = awarded_sec.has(skey)
			var prefix: String = "[✓] " if done else "[ ] "
			var col: Color = TacticalTheme.COL_OK if done else TacticalTheme.COL_TEXT
			var lbl: Label = _make_label(
				"%s%s: %s (+%d ОК)" % [prefix, str(s.get("title", "")), str(s.get("description", "")), int(s.get("bonus_cp", 40))],
				14,
				col
			)
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_brief_sec_vbox.add_child(lbl)
	else:
		_brief_sec_vbox.add_child(_make_label("Дополнительные задачи будут добавлены в ближайшем обновлении.", 13, TacticalTheme.COL_MUTED))

	if coming_soon:
		_launch_btn.disabled = true
		_launch_btn.text = "В разработке / Скоро"
	elif not unlocked:
		_launch_btn.disabled = true
		_launch_btn.text = "Сначала завершите предыдущую операцию"
	else:
		_launch_btn.disabled = false
		_launch_btn.text = "Переиграть операцию" if completed else "Начать операцию"


func _rebuild_upgrades(cur_cp: int) -> void:
	var fleet_raw: Variant = AppState.current_save.get("fleet", {})
	var f_cargo: int = 5
	var f_tank: int = 3
	var f_eng: int = 1
	var f_arm: int = 0
	if typeof(fleet_raw) == TYPE_DICTIONARY:
		var f: Dictionary = fleet_raw
		f_cargo = int(f.get("CARGO", 5))
		f_tank = int(f.get("TANKER", 3))
		f_eng = int(f.get("ENGINEER", 1))
		f_arm = int(f.get("ARMORED", 0))
	var mods: SimTypes.CampaignModifiers = AppState.get_active_modifiers()
	var total_slots: int = 6 + mods.bonus_train_slots
	var mod_units: int = AppState.get_total_modernized_units()
	_fleet_lbl.text = "Постоянный парк: Борт %d • АТЗ %d • Инж %d • БТР %d | Вагонов: %d | Ур.II: %d" % [
		f_cargo, f_tank, f_eng, f_arm, total_slots, mod_units
	]

	for child: Node in _upgrades_vbox.get_children():
		child.queue_free()

	for u: Dictionary in AppState.upgrades_catalog:
		var uid: String = str(u.get("id", ""))
		var cost: int = int(u.get("cost_cp", 80))
		var owned: bool = AppState.is_upgrade_purchased(uid)

		var row_panel: PanelContainer = PanelContainer.new()
		var b_col: Color = TacticalTheme.COL_OK if owned else TacticalTheme.COL_BORDER
		row_panel.add_theme_stylebox_override("panel", TacticalTheme.make_panel_box(Color("#1b2018EB"), b_col, 2, 8))
		_upgrades_vbox.add_child(row_panel)

		var rv: VBoxContainer = VBoxContainer.new()
		rv.add_theme_constant_override("separation", 4)
		row_panel.add_child(rv)

		var top_r: HBoxContainer = HBoxContainer.new()
		top_r.add_theme_constant_override("separation", 8)
		rv.add_child(top_r)

		var ico_rect: TextureRect = TextureRect.new()
		ico_rect.texture = TacticalTheme.load_icon(str(u.get("icon", "wrench")))
		ico_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ico_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ico_rect.custom_minimum_size = Vector2(18.0, 18.0)
		ico_rect.modulate = TacticalTheme.COL_OK if owned else TacticalTheme.COL_ACCENT
		top_r.add_child(ico_rect)

		var uname: Label = _make_label(str(u.get("name", uid)), 14, TacticalTheme.COL_TEXT, true)
		uname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		uname.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		top_r.add_child(uname)

		var udesc: Label = _make_label(str(u.get("description", "")), 12, TacticalTheme.COL_MUTED)
		udesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rv.add_child(udesc)

		var buy_btn: Button = Button.new()
		buy_btn.custom_minimum_size = Vector2(0.0, 28.0)
		buy_btn.add_theme_font_size_override("font_size", 13)
		if owned:
			buy_btn.text = "Куплено и активно"
			buy_btn.disabled = true
		elif cur_cp >= cost:
			buy_btn.text = "Купить за %d ОК" % cost
			buy_btn.add_theme_color_override("font_color", TacticalTheme.COL_ACCENT)
			buy_btn.pressed.connect(func() -> void:
				if AppState.purchase_upgrade(uid):
					_refresh_all()
			)
		else:
			buy_btn.text = "Недостаточно ОК (%d)" % cost
			buy_btn.disabled = true
		rv.add_child(buy_btn)


func _on_launch_pressed() -> void:
	if _selected_op_id.is_empty():
		return
	AppState.launch_operation(_campaign_id, _selected_op_id)


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
