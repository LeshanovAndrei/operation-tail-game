extends Control

signal closed()

var _is_modal: bool = false
var _backdrop: MenuBackdrop = null
var _modal_dim: ColorRect = null

var _window_opt: OptionButton = null
var _vsync_chk: CheckBox = null
var _scroll_slider: HSlider = null
var _scroll_val_lbl: Label = null
var _speed_opt: OptionButton = null
var _ap_train_chk: CheckBox = null
var _ap_assault_chk: CheckBox = null
var _ap_strike_chk: CheckBox = null
var _syncing: bool = false


func _ready() -> void:
	theme = TacticalTheme.build_theme()
	_build_ui()
	_sync_from_state()


func set_modal_mode(modal: bool) -> void:
	_is_modal = modal
	if _backdrop != null:
		_backdrop.visible = not modal
	if _modal_dim != null:
		_modal_dim.visible = modal


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var kev: InputEventKey = event
		if kev.pressed and not kev.echo and kev.keycode == KEY_ESCAPE:
			_on_close_pressed()
			get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_backdrop = MenuBackdrop.new()
	_backdrop.visible = not _is_modal
	add_child(_backdrop)

	_modal_dim = ColorRect.new()
	_modal_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_dim.color = Color(0.05, 0.06, 0.05, 0.72)
	_modal_dim.visible = _is_modal
	add_child(_modal_dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(680.0, 560.0)
	panel.add_theme_stylebox_override("panel", TacticalTheme.make_panel_box(TacticalTheme.COL_PANEL_DARK, TacticalTheme.COL_BORDER_HI, 3, 22))
	center.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var hdr: HBoxContainer = HBoxContainer.new()
	vbox.add_child(hdr)
	var title: Label = _make_label("НАСТРОЙКИ ШТАБА И СИМУЛЯЦИИ", 22, TacticalTheme.COL_ACCENT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(title)
	var x_btn: Button = Button.new()
	x_btn.text = "×"
	x_btn.custom_minimum_size = Vector2(32.0, 30.0)
	x_btn.pressed.connect(_on_close_pressed)
	hdr.add_child(x_btn)

	vbox.add_child(HSeparator.new())

	# Display section
	vbox.add_child(_make_label("ЭКРАН И ОТОБРАЖЕНИЕ", 15, TacticalTheme.COL_FRIENDLY, true))

	var win_row: HBoxContainer = HBoxContainer.new()
	win_row.add_theme_constant_override("separation", 12)
	vbox.add_child(win_row)
	var win_lbl: Label = _make_label("Режим окна:", 15, TacticalTheme.COL_TEXT)
	win_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	win_row.add_child(win_lbl)

	_window_opt = OptionButton.new()
	_window_opt.custom_minimum_size = Vector2(240.0, 34.0)
	_window_opt.add_item("Оконный (Windowed)")
	_window_opt.add_item("Полный экран (Fullscreen)")
	_window_opt.add_item("Без рамки (Borderless)")
	_window_opt.item_selected.connect(func(idx: int) -> void:
		if _syncing:
			return
		AppState.window_mode = idx
		AppState.save_settings()
	)
	win_row.add_child(_window_opt)

	_vsync_chk = CheckBox.new()
	_vsync_chk.text = "Вертикальная синхронизация (VSync)"
	_vsync_chk.add_theme_font_size_override("font_size", 15)
	_vsync_chk.toggled.connect(func(on: bool) -> void:
		if _syncing:
			return
		AppState.vsync_enabled = on
		AppState.save_settings()
	)
	vbox.add_child(_vsync_chk)

	vbox.add_child(HSeparator.new())

	# Gameplay section
	vbox.add_child(_make_label("ГЕЙМПЛЕЙ И УПРАВЛЕНИЕ", 15, TacticalTheme.COL_FRIENDLY, true))

	var scroll_row: HBoxContainer = HBoxContainer.new()
	scroll_row.add_theme_constant_override("separation", 12)
	vbox.add_child(scroll_row)
	var sc_lbl: Label = _make_label("Скорость прокрутки камеры:", 15, TacticalTheme.COL_TEXT)
	sc_lbl.custom_minimum_size = Vector2(240.0, 0.0)
	scroll_row.add_child(sc_lbl)

	_scroll_slider = HSlider.new()
	_scroll_slider.min_value = 0.5
	_scroll_slider.max_value = 2.0
	_scroll_slider.step = 0.1
	_scroll_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_slider.value_changed.connect(func(v: float) -> void:
		_scroll_val_lbl.text = "%d%%" % int(round(v * 100.0))
		if _syncing:
			return
		AppState.camera_scroll_speed = v
		AppState.save_settings()
	)
	scroll_row.add_child(_scroll_slider)

	_scroll_val_lbl = _make_mono_label("100%", 14, TacticalTheme.COL_ACCENT)
	_scroll_val_lbl.custom_minimum_size = Vector2(54.0, 0.0)
	_scroll_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	scroll_row.add_child(_scroll_val_lbl)

	var spd_row: HBoxContainer = HBoxContainer.new()
	spd_row.add_theme_constant_override("separation", 12)
	vbox.add_child(spd_row)
	var spd_lbl: Label = _make_label("Скорость симуляции на старте:", 15, TacticalTheme.COL_TEXT)
	spd_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spd_row.add_child(spd_lbl)

	_speed_opt = OptionButton.new()
	_speed_opt.custom_minimum_size = Vector2(240.0, 34.0)
	_speed_opt.add_item("0.5x (Размеренная)")
	_speed_opt.add_item("1x (Штатная)")
	_speed_opt.item_selected.connect(func(idx: int) -> void:
		if _syncing:
			return
		AppState.default_sim_speed = 0.5 if idx == 0 else 1.0
		AppState.save_settings()
	)
	spd_row.add_child(_speed_opt)

	vbox.add_child(HSeparator.new())

	# Autopause section
	vbox.add_child(_make_label("АВТОПАУЗА ПРИ СОБЫТИЯХ", 15, TacticalTheme.COL_ACCENT, true))

	_ap_train_chk = CheckBox.new()
	_ap_train_chk.text = "Ставить на паузу при прибытии ж/д эшелона"
	_ap_train_chk.add_theme_font_size_override("font_size", 15)
	_ap_train_chk.toggled.connect(func(on: bool) -> void:
		if _syncing:
			return
		AppState.autopause_train_arrived = on
		AppState.save_settings()
	)
	vbox.add_child(_ap_train_chk)

	_ap_assault_chk = CheckBox.new()
	_ap_assault_chk.text = "Ставить на паузу при начале штурма / смене фазы операции"
	_ap_assault_chk.add_theme_font_size_override("font_size", 15)
	_ap_assault_chk.toggled.connect(func(on: bool) -> void:
		if _syncing:
			return
		AppState.autopause_assault_or_phase = on
		AppState.save_settings()
	)
	vbox.add_child(_ap_assault_chk)

	_ap_strike_chk = CheckBox.new()
	_ap_strike_chk.text = "Ставить на паузу при ударе по складу / повреждении моста"
	_ap_strike_chk.add_theme_font_size_override("font_size", 15)
	_ap_strike_chk.toggled.connect(func(on: bool) -> void:
		if _syncing:
			return
		AppState.autopause_strike_or_bridge = on
		AppState.save_settings()
	)
	vbox.add_child(_ap_strike_chk)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	vbox.add_child(HSeparator.new())

	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	vbox.add_child(footer)

	var reset_btn: Button = Button.new()
	reset_btn.text = "Сбросить по умолчанию"
	reset_btn.custom_minimum_size = Vector2(200.0, 38.0)
	reset_btn.pressed.connect(func() -> void:
		AppState.reset_default_settings()
		_sync_from_state()
	)
	footer.add_child(reset_btn)

	var f_sp: Control = Control.new()
	f_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(f_sp)

	var close_btn: Button = Button.new()
	close_btn.text = "Применить и закрыть"
	close_btn.custom_minimum_size = Vector2(200.0, 38.0)
	close_btn.add_theme_color_override("font_color", TacticalTheme.COL_OK)
	close_btn.pressed.connect(_on_close_pressed)
	footer.add_child(close_btn)


func _sync_from_state() -> void:
	_syncing = true
	_window_opt.select(clampi(AppState.window_mode, 0, 2))
	_vsync_chk.button_pressed = AppState.vsync_enabled
	_scroll_slider.value = AppState.camera_scroll_speed
	_scroll_val_lbl.text = "%d%%" % int(round(AppState.camera_scroll_speed * 100.0))
	_speed_opt.select(0 if is_equal_approx(AppState.default_sim_speed, 0.5) else 1)
	_ap_train_chk.button_pressed = AppState.autopause_train_arrived
	_ap_assault_chk.button_pressed = AppState.autopause_assault_or_phase
	_ap_strike_chk.button_pressed = AppState.autopause_strike_or_bridge
	_syncing = false


func _on_close_pressed() -> void:
	if _is_modal:
		closed.emit()
	else:
		AppState.goto_main_menu()


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
