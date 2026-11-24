extends Control

var _continue_btn: Button = null
var _status_label: Label = null
var _quick_panel: PanelContainer = null
var _settings_overlay: Control = null


func _ready() -> void:
	theme = TacticalTheme.build_theme()
	_build_ui()
	_refresh_save_state()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var kev: InputEventKey = event
		if kev.pressed and not kev.echo and kev.keycode == KEY_ESCAPE:
			if _settings_overlay != null:
				_close_settings_overlay()
				get_viewport().set_input_as_handled()
			elif _quick_panel != null and _quick_panel.visible:
				_quick_panel.visible = false
				get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var backdrop: MenuBackdrop = MenuBackdrop.new()
	add_child(backdrop)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 52)
	margin.add_theme_constant_override("margin_right", 52)
	margin.add_theme_constant_override("margin_top", 44)
	margin.add_theme_constant_override("margin_bottom", 36)
	add_child(margin)

	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 24)
	margin.add_child(root_vbox)

	# Header Title Banner
	var hdr_box: VBoxContainer = VBoxContainer.new()
	hdr_box.add_theme_constant_override("separation", 4)
	root_vbox.add_child(hdr_box)

	var stamp_lbl: Label = _make_mono_label("ШТАБ ТЫЛА ОПЕРАТИВНОГО КОМАНДОВАНИЯ • СЕКЦИЯ ГСМ И ПОДВОЗА", 12, TacticalTheme.COL_ACCENT)
	hdr_box.add_child(stamp_lbl)

	var title_lbl: Label = _make_label("OPERATION TAIL: LOGISTICS COMMAND", 40, TacticalTheme.COL_TEXT, true)
	hdr_box.add_child(title_lbl)

	var sub_lbl: Label = _make_label("Оперативная 2D-стратегия снабжения, маскировки складов и манёвра колоннами", 17, TacticalTheme.COL_MUTED)
	hdr_box.add_child(sub_lbl)

	# Main 2-column body
	var body_hbox: HBoxContainer = HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 36)
	root_vbox.add_child(body_hbox)

	# Left column: menu buttons
	var nav_panel: PanelContainer = PanelContainer.new()
	nav_panel.custom_minimum_size = Vector2(360.0, 0.0)
	nav_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	nav_panel.add_theme_stylebox_override("panel", TacticalTheme.make_panel_box(TacticalTheme.COL_PANEL_DARK, TacticalTheme.COL_BORDER_HI, 3, 18))
	body_hbox.add_child(nav_panel)

	var nav_vbox: VBoxContainer = VBoxContainer.new()
	nav_vbox.add_theme_constant_override("separation", 10)
	nav_panel.add_child(nav_vbox)

	nav_vbox.add_child(_make_label("КОМАНДНЫЙ ПУНКТ", 14, TacticalTheme.COL_ACCENT, true))
	nav_vbox.add_child(HSeparator.new())

	_continue_btn = _make_menu_button("Продолжить кампанию", "play-button", TacticalTheme.COL_OK)
	_continue_btn.pressed.connect(_on_continue_pressed)
	nav_vbox.add_child(_continue_btn)

	var select_btn: Button = _make_menu_button("Выбор кампании", "tower-flag", TacticalTheme.COL_ACCENT)
	select_btn.pressed.connect(func() -> void: AppState.goto_campaign_select())
	nav_vbox.add_child(select_btn)

	var quick_btn: Button = _make_menu_button("Быстрая операция", "crosshair", TacticalTheme.COL_FRIENDLY)
	quick_btn.pressed.connect(_on_quick_toggle)
	nav_vbox.add_child(quick_btn)

	var settings_btn: Button = _make_menu_button("Настройки", "wrench", TacticalTheme.COL_TEXT)
	settings_btn.pressed.connect(_open_settings_overlay)
	nav_vbox.add_child(settings_btn)

	nav_vbox.add_child(HSeparator.new())

	var quit_btn: Button = _make_menu_button("Выход", "pause-button", TacticalTheme.COL_CRITICAL)
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	nav_vbox.add_child(quit_btn)

	# Right column: Dossier + Quick Ops Picker
	var right_vbox: VBoxContainer = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 14)
	body_hbox.add_child(right_vbox)

	var dossier_panel: PanelContainer = PanelContainer.new()
	dossier_panel.add_theme_stylebox_override("panel", TacticalTheme.make_panel_box(TacticalTheme.COL_PANEL, TacticalTheme.COL_BORDER, 3, 18))
	right_vbox.add_child(dossier_panel)

	var dos_vbox: VBoxContainer = VBoxContainer.new()
	dos_vbox.add_theme_constant_override("separation", 8)
	dossier_panel.add_child(dos_vbox)

	dos_vbox.add_child(_make_label("ТЕКУЩАЯ ОБСТАНОВКА", 15, TacticalTheme.COL_ACCENT, true))
	_status_label = _make_label("", 15, TacticalTheme.COL_TEXT)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dos_vbox.add_child(_status_label)

	dos_vbox.add_child(HSeparator.new())
	var brief_help: Label = _make_label(
		"Управление на карте:\n• ЛКМ — выбор узла / подтверждение маршрута\n• ПКМ на целевой узел — быстрая отправка свободной колонны\n• Зажать ПКМ / СКМ или WASD — прокрутка карты • Колёсико — масштаб\n• Space — пауза • 1–5 — скорость симуляции (0.5x – 8x) • Esc — меню паузы",
		14,
		TacticalTheme.COL_MUTED
	)
	brief_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dos_vbox.add_child(brief_help)

	# Inline Quick Operation Picker
	_quick_panel = PanelContainer.new()
	_quick_panel.visible = false
	_quick_panel.add_theme_stylebox_override("panel", TacticalTheme.make_panel_box(TacticalTheme.COL_PANEL_DARK, TacticalTheme.COL_FRIENDLY, 3, 16))
	right_vbox.add_child(_quick_panel)

	var q_vbox: VBoxContainer = VBoxContainer.new()
	q_vbox.add_theme_constant_override("separation", 8)
	_quick_panel.add_child(q_vbox)

	var q_hdr: HBoxContainer = HBoxContainer.new()
	q_vbox.add_child(q_hdr)
	var q_title: Label = _make_label("БЫСТРАЯ ОПЕРАЦИЯ (БЕЗ СОХРАНЕНИЯ КАМПАНИИ)", 15, TacticalTheme.COL_FRIENDLY, true)
	q_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q_hdr.add_child(q_title)
	var q_close: Button = Button.new()
	q_close.text = "×"
	q_close.custom_minimum_size = Vector2(28.0, 26.0)
	q_close.pressed.connect(func() -> void: _quick_panel.visible = false)
	q_hdr.add_child(q_close)

	for camp: Dictionary in AppState.campaigns:
		if bool(camp.get("coming_soon", false)):
			continue
		var ops_raw: Variant = camp.get("operations", [])
		if typeof(ops_raw) != TYPE_ARRAY:
			continue
		var ops: Array = ops_raw
		for op_var: Variant in ops:
			if typeof(op_var) != TYPE_DICTIONARY:
				continue
			var op: Dictionary = op_var
			if bool(op.get("coming_soon", false)):
				continue
			var sc_path: String = str(op.get("scenario_path", ""))
			var op_id: String = str(op.get("id", ""))
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			q_vbox.add_child(row)

			var info_lbl: Label = _make_label(
				"%s (%s, %d ч)" % [
					str(op.get("name", op_id)),
					"Оборона" if str(op.get("mode", "OFFENSIVE")) == "DEFENSE" else "Наступление",
					int(op.get("duration_hours", 48)),
				],
				14,
				TacticalTheme.COL_TEXT
			)
			info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(info_lbl)

			var go_btn: Button = Button.new()
			go_btn.text = "Запуск"
			go_btn.custom_minimum_size = Vector2(110.0, 32.0)
			go_btn.pressed.connect(func() -> void: AppState.launch_quick_scenario(sc_path, op_id))
			row.add_child(go_btn)

	# Footer version line
	var footer_hbox: HBoxContainer = HBoxContainer.new()
	root_vbox.add_child(footer_hbox)
	var ver_lbl: Label = _make_mono_label("ПРОТОТИП %s • 1280x800 STEAM DECK READY" % AppState.VERSION_STRING, 12, TacticalTheme.COL_MUTED)
	footer_hbox.add_child(ver_lbl)


func _refresh_save_state() -> void:
	var recent_id: String = AppState.get_most_recent_campaign_id()
	if recent_id.is_empty():
		_continue_btn.disabled = true
		_status_label.text = "Активное сохранение не найдено. Выберите кампанию для начала новой операции или запустите быстрый сценарий."
		return

	_continue_btn.disabled = false
	var camp: Dictionary = AppState.get_campaign_by_id(recent_id)
	var save: Dictionary = AppState.load_campaign_save(recent_id)
	var prog: Dictionary = AppState.get_campaign_progress(recent_id)
	var cp: int = int(save.get("command_points", 0))
	var fleet_raw: Variant = save.get("fleet", {})
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

	var mod_total: int = AppState.get_total_modernized_units(save)
	_status_label.text = "Активная кампания: %s\nПрогресс: %d / %d операций • Очки командования: %d ОК • Ур.II батальонов: %d\nПостоянный автопарк: Борт %d • АТЗ %d • Инж %d • БТР %d" % [
		str(camp.get("name", recent_id)),
		int(prog.get("completed", 0)),
		int(prog.get("total", 0)),
		cp,
		mod_total,
		f_cargo,
		f_tank,
		f_eng,
		f_arm,
	]


func _on_continue_pressed() -> void:
	var recent_id: String = AppState.get_most_recent_campaign_id()
	if not recent_id.is_empty():
		AppState.goto_campaign_hub(recent_id)


func _on_quick_toggle() -> void:
	_quick_panel.visible = not _quick_panel.visible


func _open_settings_overlay() -> void:
	if _settings_overlay != null:
		return
	var packed: PackedScene = load(AppState.SCENE_SETTINGS) as PackedScene
	if packed == null:
		return
	var inst: Control = packed.instantiate() as Control
	if inst == null:
		return
	_settings_overlay = inst
	add_child(inst)
	if inst.has_method("set_modal_mode"):
		inst.call("set_modal_mode", true)
	if inst.has_signal("closed"):
		inst.connect("closed", _close_settings_overlay)


func _close_settings_overlay() -> void:
	if _settings_overlay != null:
		_settings_overlay.queue_free()
		_settings_overlay = null


func _make_menu_button(text: String, icon_name: String, accent: Color) -> Button:
	var btn: Button = Button.new()
	btn.text = "  " + text
	btn.icon = TacticalTheme.load_icon(icon_name)
	btn.expand_icon = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0.0, 44.0)
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", accent)
	return btn


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
