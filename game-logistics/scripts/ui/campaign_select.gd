extends Control

var _cards_hbox: HBoxContainer = null
var _confirm_reset_id: String = ""


func _ready() -> void:
	theme = TacticalTheme.build_theme()
	_build_ui()
	_rebuild_cards()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var kev: InputEventKey = event
		if kev.pressed and not kev.echo and kev.keycode == KEY_ESCAPE:
			AppState.goto_main_menu()
			get_viewport().set_input_as_handled()


func _build_ui() -> void:
	add_child(MenuBackdrop.new())

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	# Top Bar
	var top_bar: PanelContainer = PanelContainer.new()
	top_bar.add_theme_stylebox_override("panel", TacticalTheme.make_panel_box(TacticalTheme.COL_PANEL_DARK, TacticalTheme.COL_BORDER, 2, 12))
	vbox.add_child(top_bar)

	var top_hbox: HBoxContainer = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 16)
	top_bar.add_child(top_hbox)

	var back_btn: Button = Button.new()
	back_btn.text = "← В главное меню"
	back_btn.custom_minimum_size = Vector2(170.0, 34.0)
	back_btn.pressed.connect(func() -> void: AppState.goto_main_menu())
	top_hbox.add_child(back_btn)

	var title_lbl: Label = _make_label("ВЫБОР ТЕАТРА ОПЕРАЦИЙ И КАМПАНИИ", 22, TacticalTheme.COL_ACCENT, true)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(title_lbl)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_cards_hbox = HBoxContainer.new()
	_cards_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_hbox.add_theme_constant_override("separation", 22)
	scroll.add_child(_cards_hbox)


func _rebuild_cards() -> void:
	for child: Node in _cards_hbox.get_children():
		child.queue_free()

	for camp: Dictionary in AppState.campaigns:
		var cid: String = str(camp.get("id", ""))
		var coming_soon: bool = bool(camp.get("coming_soon", false))
		var has_save: bool = (not coming_soon) and AppState.has_campaign_save(cid)
		var prog: Dictionary = AppState.get_campaign_progress(cid)

		var card: PanelContainer = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(460.0, 0.0)
		var border_col: Color = TacticalTheme.COL_MUTED if coming_soon else TacticalTheme.COL_BORDER_HI
		card.add_theme_stylebox_override("panel", TacticalTheme.make_panel_box(TacticalTheme.COL_PANEL_DARK, border_col, 3, 20))
		_cards_hbox.add_child(card)

		var cv: VBoxContainer = VBoxContainer.new()
		cv.add_theme_constant_override("separation", 10)
		card.add_child(cv)

		var badge_lbl: Label = _make_mono_label(
			"В РАЗРАБОТКЕ / СКОРО" if coming_soon else ("АКТИВНОЕ СОХРАНЕНИЕ" if has_save else "ДОСТУПНА"),
			12,
			TacticalTheme.COL_MUTED if coming_soon else (TacticalTheme.COL_OK if has_save else TacticalTheme.COL_ACCENT)
		)
		cv.add_child(badge_lbl)

		var name_lbl: Label = _make_label(str(camp.get("name", cid)), 24, TacticalTheme.COL_TEXT if not coming_soon else TacticalTheme.COL_MUTED, true)
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(name_lbl)

		var sub_lbl: Label = _make_label(str(camp.get("subtitle", "")), 14, TacticalTheme.COL_ACCENT if not coming_soon else TacticalTheme.COL_MUTED)
		sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(sub_lbl)

		cv.add_child(HSeparator.new())

		var desc_lbl: Label = _make_label(str(camp.get("description", "")), 15, TacticalTheme.COL_TEXT if not coming_soon else TacticalTheme.COL_MUTED)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(desc_lbl)

		if not coming_soon:
			cv.add_child(HSeparator.new())
			var prog_lbl: Label = _make_mono_label(
				"Прогресс: %d / %d операций" % [int(prog.get("completed", 0)), int(prog.get("total", 0))],
				14,
				TacticalTheme.COL_TEXT
			)
			cv.add_child(prog_lbl)

			if has_save:
				var save: Dictionary = AppState.load_campaign_save(cid)
				var cp: int = int(save.get("command_points", 0))
				var upg_arr: Array = save.get("purchased_upgrades", [])
				var stat_lbl: Label = _make_label(
					"Очки командования: %d ОК • Улучшений штаба: %d" % [cp, upg_arr.size()],
					14,
					TacticalTheme.COL_OK
				)
				cv.add_child(stat_lbl)
			else:
				var start_cp: int = int(camp.get("starting_command_points", 60))
				cv.add_child(_make_label("Стартовый резерв штаба: %d ОК" % start_cp, 14, TacticalTheme.COL_MUTED))

		var spacer: Control = Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cv.add_child(spacer)

		cv.add_child(HSeparator.new())

		var btn_row: HBoxContainer = HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 10)
		cv.add_child(btn_row)

		if coming_soon:
			var dis_btn: Button = Button.new()
			dis_btn.text = "В разработке / Скоро"
			dis_btn.disabled = true
			dis_btn.custom_minimum_size = Vector2(0.0, 42.0)
			dis_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_row.add_child(dis_btn)
		elif has_save:
			var cont_btn: Button = Button.new()
			cont_btn.text = "Продолжить"
			cont_btn.custom_minimum_size = Vector2(0.0, 42.0)
			cont_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cont_btn.add_theme_font_size_override("font_size", 16)
			cont_btn.add_theme_color_override("font_color", TacticalTheme.COL_OK)
			cont_btn.pressed.connect(func() -> void: AppState.goto_campaign_hub(cid))
			btn_row.add_child(cont_btn)

			var rst_btn: Button = Button.new()
			rst_btn.text = "Подтвердить сброс?" if _confirm_reset_id == cid else "Начать заново"
			rst_btn.custom_minimum_size = Vector2(170.0, 42.0)
			rst_btn.add_theme_color_override("font_color", TacticalTheme.COL_CRITICAL if _confirm_reset_id == cid else TacticalTheme.COL_ACCENT)
			rst_btn.pressed.connect(func() -> void:
				if _confirm_reset_id == cid:
					_confirm_reset_id = ""
					AppState.start_new_campaign(cid)
					AppState.goto_campaign_hub(cid)
				else:
					_confirm_reset_id = cid
					_rebuild_cards()
			)
			btn_row.add_child(rst_btn)
		else:
			var start_btn: Button = Button.new()
			start_btn.text = "Начать кампанию"
			start_btn.custom_minimum_size = Vector2(0.0, 42.0)
			start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			start_btn.add_theme_font_size_override("font_size", 16)
			start_btn.add_theme_color_override("font_color", TacticalTheme.COL_ACCENT)
			start_btn.pressed.connect(func() -> void:
				AppState.start_new_campaign(cid)
				AppState.goto_campaign_hub(cid)
			)
			btn_row.add_child(start_btn)


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
