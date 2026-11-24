extends Node2D

const DEFAULT_SCENARIO_PATH: String = "res://data/scenario_offensive.json"
const BASE_TICK_SECONDS: float = 2.5

@onready var _camera: CameraController = $Camera2D
@onready var _topo_backdrop: TopoBackdrop = $TopoBackdrop
@onready var _map_view: MapView = $MapView
@onready var _hud: TacticalHUD = $HUD

var _engine: SimEngine = SimEngine.new()
var _scenario_path: String = DEFAULT_SCENARIO_PATH
var _selected_node_id: String = ""
var _speed_multiplier: float = 1.0
var _last_nonzero_speed: float = 1.0
var _tick_accumulator: float = 0.0
var _night_blend: float = 0.0
var _pause_open: bool = false
var _debrief_shown: bool = false
var _speed_before_pause_menu: float = 1.0
var _settings_overlay: Control = null


func _ready() -> void:
	_map_view.node_selected.connect(_on_node_selected)
	_map_view.route_target_confirmed.connect(_on_route_target_confirmed)
	_map_view.route_target_cancelled.connect(_on_route_target_cancelled)
	_map_view.quick_route_requested.connect(_on_quick_route_requested)

	_hud.speed_selected.connect(_on_speed_selected)
	_hud.route_aim_toggled.connect(_on_route_aim_toggled)
	_hud.dispatch_options_changed.connect(_on_dispatch_options_changed)
	_hud.stop_loop_requested.connect(_on_stop_loop_requested)
	_hud.cycle_convoy_cargo_requested.connect(_on_cycle_convoy_cargo_requested)
	_hud.convoy_night_toggled.connect(_on_convoy_night_toggled)
	_hud.convoy_evac_toggled.connect(_on_convoy_evac_toggled)
	_hud.camouflage_toggled.connect(_on_camouflage_toggled)
	_hud.train_target_selected.connect(_on_train_target_selected)
	_hud.train_slot_cycled.connect(_on_train_slot_cycled)
	_hud.train_truck_cycled.connect(_on_train_truck_cycled)
	_hud.train_equipment_toggled.connect(_on_train_equipment_toggled)
	_hud.deploy_depot_requested.connect(_on_deploy_depot_requested)
	_hud.pack_depot_requested.connect(_on_pack_depot_requested)
	_hud.radiogram_jump_requested.connect(_on_radiogram_jump_requested)
	_hud.radiogram_dismissed.connect(_on_radiogram_dismissed)
	_hud.event_clicked.connect(_on_event_clicked)
	_hud.restart_requested.connect(_start_new_game)
	_hud.layer_toggled.connect(_on_layer_toggled)
	_hud.zoom_in_requested.connect(func() -> void: _camera.zoom_in())
	_hud.zoom_out_requested.connect(func() -> void: _camera.zoom_out())
	_hud.inspector_closed.connect(_on_inspector_closed)

	_hud.pause_resume_requested.connect(_close_pause_menu)
	_hud.pause_settings_requested.connect(_open_settings_overlay)
	_hud.pause_restart_requested.connect(_start_new_game)
	_hud.pause_hub_requested.connect(_on_return_to_hub)
	_hud.pause_main_menu_requested.connect(_on_return_to_main_menu)

	_hud.debrief_continue_requested.connect(_on_return_to_hub)
	_hud.debrief_restart_requested.connect(_start_new_game)
	_hud.debrief_main_menu_requested.connect(_on_return_to_main_menu)

	AppState.settings_changed.connect(_apply_app_settings)
	_apply_app_settings()
	_start_new_game()


func _process(delta: float) -> void:
	_hud.set_scale_zoom(_camera.zoom.x)
	if not _pause_open and not _debrief_shown and _settings_overlay == null:
		_hud.update_hover_tooltip(_map_view.get_hover_tooltip_data(), get_viewport().get_mouse_position())
	else:
		_hud.update_hover_tooltip({}, Vector2.ZERO)

	var target_night: float = 1.0 if _engine.is_night() else 0.0
	if not is_equal_approx(_night_blend, target_night):
		_night_blend = move_toward(_night_blend, target_night, delta * 1.2)
		_topo_backdrop.set_night_factor(_night_blend)

	if _pause_open or _debrief_shown or _speed_multiplier <= 0.0 or _engine.result != SimTypes.GameResult.RUNNING:
		return

	var step_interval: float = BASE_TICK_SECONDS / _speed_multiplier
	_tick_accumulator += delta
	var stepped: bool = false
	while _tick_accumulator >= step_interval and _engine.result == SimTypes.GameResult.RUNNING:
		_tick_accumulator -= step_interval
		_map_view.snapshot_before_tick()
		_engine.step_tick()
		stepped = true
		if _check_autopause_triggers():
			break

	_map_view.tick_alpha = clampf(_tick_accumulator / step_interval, 0.0, 1.0)
	if stepped:
		_check_operation_finished()
		_refresh_views()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var kev: InputEventKey = event
		if kev.pressed and not kev.echo:
			if kev.keycode == KEY_ESCAPE:
				if _settings_overlay != null:
					_close_settings_overlay()
				elif _debrief_shown:
					pass
				elif _pause_open:
					_close_pause_menu()
				elif _map_view.is_targeting():
					_map_view.cancel_route_targeting()
					_refresh_views()
				else:
					_open_pause_menu()
				get_viewport().set_input_as_handled()
				return

			if _pause_open or _debrief_shown or _settings_overlay != null:
				return

			match kev.keycode:
				KEY_SPACE:
					if is_equal_approx(_speed_multiplier, 0.0):
						_on_speed_selected(_last_nonzero_speed)
					else:
						_on_speed_selected(0.0)
				KEY_1:
					_on_speed_selected(0.5)
				KEY_2:
					_on_speed_selected(1.0)
				KEY_3:
					_on_speed_selected(2.0)
				KEY_4:
					_on_speed_selected(4.0)
				KEY_5:
					_on_speed_selected(8.0)


func _apply_app_settings() -> void:
	_camera.pan_speed_scale = AppState.camera_scroll_speed


func _start_new_game() -> void:
	_close_settings_overlay()
	_pause_open = false
	_debrief_shown = false
	_hud.set_pause_menu_visible(false, _is_campaign_mode())
	_hud.hide_debriefing()
	_hud.clear_autopause_notice()

	_scenario_path = AppState.pending_scenario_path if not AppState.pending_scenario_path.is_empty() else DEFAULT_SCENARIO_PATH
	var modifiers: SimTypes.CampaignModifiers = AppState.get_active_modifiers()

	_tick_accumulator = 0.0
	_speed_multiplier = AppState.default_sim_speed
	_last_nonzero_speed = AppState.default_sim_speed
	_speed_before_pause_menu = _speed_multiplier
	_night_blend = 0.0
	_topo_backdrop.set_night_factor(0.0)

	_engine = SimEngine.new()
	_engine.load_scenario(_scenario_path, modifiers)
	_camera.set_map_bounds(_engine.config.map_bounds)
	_camera.reset_view()
	_selected_node_id = _engine.config.default_train_target
	_hud.reset_log()
	_map_view.set_engine(_engine, _scenario_path)
	_map_view.set_selected_node(_selected_node_id)
	_map_view.tick_alpha = 1.0
	_refresh_views()


func _is_campaign_mode() -> bool:
	return (not AppState.is_quick_battle) and (not AppState.active_campaign_id.is_empty())


func _check_autopause_triggers() -> bool:
	for tag: SimTypes.AutoPauseTag in _engine.last_tick_autopause_tags:
		match tag:
			SimTypes.AutoPauseTag.TRAIN_ARRIVED:
				if AppState.autopause_train_arrived:
					_trigger_autopause("Прибыл ж/д эшелон снабжения")
					return true
			SimTypes.AutoPauseTag.ASSAULT_STARTED:
				if AppState.autopause_assault_or_phase:
					_trigger_autopause("Начался штурм / усиление боёв на фронте")
					return true
			SimTypes.AutoPauseTag.STRIKE_OR_DAMAGE:
				if AppState.autopause_strike_or_bridge:
					_trigger_autopause("Удар противника или повреждение моста!")
					return true
	return false


func _trigger_autopause(reason: String) -> void:
	if _speed_multiplier > 0.0:
		_last_nonzero_speed = _speed_multiplier
	_speed_multiplier = 0.0
	_tick_accumulator = 0.0
	_hud.show_autopause_notice(reason)


func _check_operation_finished() -> void:
	if _debrief_shown or _engine.result == SimTypes.GameResult.RUNNING:
		return
	_debrief_shown = true
	_speed_multiplier = 0.0
	_tick_accumulator = 0.0
	_hud.clear_autopause_notice()

	var stats: SimTypes.SimStats = _engine.get_operation_stats()
	var sec_results: Array[Dictionary] = _engine.evaluate_secondary_objectives()
	var in_camp: bool = _is_campaign_mode()
	var reward_info: Dictionary = {}
	if in_camp:
		reward_info = AppState.record_operation_result(_engine.result, stats, sec_results)
	_hud.show_debriefing(_engine, stats, sec_results, reward_info, in_camp)


func _open_pause_menu() -> void:
	_pause_open = true
	_speed_before_pause_menu = _speed_multiplier
	_speed_multiplier = 0.0
	_hud.set_pause_menu_visible(true, _is_campaign_mode())
	_refresh_views()


func _close_pause_menu() -> void:
	_close_settings_overlay()
	_pause_open = false
	_speed_multiplier = _speed_before_pause_menu
	_hud.set_pause_menu_visible(false, _is_campaign_mode())
	_refresh_views()


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
	_hud.add_child(inst)
	if inst.has_method("set_modal_mode"):
		inst.call("set_modal_mode", true)
	if inst.has_signal("closed"):
		inst.connect("closed", _close_settings_overlay)


func _close_settings_overlay() -> void:
	if _settings_overlay != null:
		_settings_overlay.queue_free()
		_settings_overlay = null


func _on_return_to_hub() -> void:
	AppState.goto_campaign_hub()


func _on_return_to_main_menu() -> void:
	AppState.goto_main_menu()


func _refresh_views() -> void:
	_map_view.set_targeting_options(
		_hud.get_selected_convoy_type(),
		_hud.get_selected_order_mode(),
		_hud.get_selected_cargo_pref()
	)
	_map_view.queue_redraw()
	_hud.refresh(_engine, _selected_node_id, _speed_multiplier, _map_view.is_targeting())


func _on_node_selected(node_id: String) -> void:
	_selected_node_id = node_id
	_refresh_views()


func _on_inspector_closed() -> void:
	_map_view.cancel_route_targeting()
	_selected_node_id = ""
	_map_view.set_selected_node("")
	_refresh_views()


func _on_dispatch_options_changed() -> void:
	_refresh_views()


func _on_route_aim_toggled(origin_id: String) -> void:
	if _map_view.is_targeting():
		_map_view.cancel_route_targeting()
	elif not origin_id.is_empty():
		var ctype: SimTypes.ConvoyType = _hud.get_selected_convoy_type()
		var counts: Dictionary[SimTypes.ConvoyType, int] = _engine.get_idle_counts_by_type_at(origin_id)
		if counts.get(ctype, 0) > 0:
			_map_view.start_route_targeting(
				origin_id,
				ctype,
				_hud.get_selected_order_mode(),
				_hud.get_selected_cargo_pref()
			)
	_refresh_views()


func _on_route_target_confirmed(origin_id: String, dest_id: String) -> void:
	_dispatch_with_hud_settings(origin_id, dest_id)


func _on_route_target_cancelled() -> void:
	_refresh_views()


func _on_quick_route_requested(origin_id: String, dest_id: String) -> void:
	_dispatch_with_hud_settings(origin_id, dest_id)


func _dispatch_with_hud_settings(origin_id: String, dest_id: String) -> void:
	var ctype: SimTypes.ConvoyType = _hud.get_selected_convoy_type()
	var mode: SimTypes.OrderMode = _hud.get_selected_order_mode()
	var pref: SimTypes.CargoPreference = _hud.get_selected_cargo_pref()
	_engine.dispatch_idle_from_node(
		origin_id,
		dest_id,
		int(ctype),
		pref,
		mode,
		_hud.is_evac_checked(),
		_hud.is_night_only_checked()
	)
	_refresh_views()


func _on_stop_loop_requested(convoy_id: String) -> void:
	_engine.stop_convoy_loop(convoy_id)
	_refresh_views()


func _on_cycle_convoy_cargo_requested(convoy_id: String) -> void:
	for convoy: Convoy in _engine.convoys:
		if convoy.id == convoy_id and (convoy.convoy_type == SimTypes.ConvoyType.CARGO or convoy.convoy_type == SimTypes.ConvoyType.ARMORED):
			var next_pref: SimTypes.CargoPreference = SimTypes.CargoPreference.MIXED
			match convoy.cargo_preference:
				SimTypes.CargoPreference.MIXED:
					next_pref = SimTypes.CargoPreference.FUEL
				SimTypes.CargoPreference.FUEL:
					next_pref = SimTypes.CargoPreference.AMMO
				SimTypes.CargoPreference.AMMO:
					next_pref = SimTypes.CargoPreference.PROVISIONS
				SimTypes.CargoPreference.PROVISIONS:
					next_pref = SimTypes.CargoPreference.PARTS
				SimTypes.CargoPreference.PARTS:
					next_pref = SimTypes.CargoPreference.EQUIPMENT
				SimTypes.CargoPreference.EQUIPMENT:
					next_pref = SimTypes.CargoPreference.MIXED
			_engine.set_convoy_cargo_pref(convoy_id, next_pref)
			break
	_refresh_views()


func _on_deploy_depot_requested(node_id: String) -> void:
	_engine.request_deploy_field_depot(node_id)
	_refresh_views()


func _on_pack_depot_requested(node_id: String) -> void:
	_engine.request_pack_field_depot(node_id)
	_refresh_views()


func _on_train_equipment_toggled() -> void:
	_engine.toggle_equipment_platform_order()
	_refresh_views()


func _on_convoy_night_toggled(convoy_id: String) -> void:
	_engine.toggle_convoy_night_only(convoy_id)
	_refresh_views()


func _on_convoy_evac_toggled(convoy_id: String) -> void:
	_engine.toggle_convoy_evac_wounded(convoy_id)
	_refresh_views()


func _on_camouflage_toggled(node_id: String) -> void:
	_engine.toggle_node_camouflage(node_id)
	_refresh_views()


func _on_train_target_selected(node_id: String) -> void:
	_engine.set_train_target_railhead(node_id)
	_refresh_views()


func _on_train_slot_cycled(slot_idx: int) -> void:
	_engine.cycle_editable_train_slot(slot_idx)
	_refresh_views()


func _on_train_truck_cycled() -> void:
	_engine.cycle_truck_convoy_order()
	_refresh_views()


func _on_radiogram_jump_requested(node_id: String) -> void:
	var node: SimTypes.MapNode = _engine.graph.get_node(node_id)
	if node != null:
		_selected_node_id = node_id
		_map_view.set_selected_node(node_id)
		_camera.focus_on(node.position)
		_refresh_views()


func _on_radiogram_dismissed(rad_id: String) -> void:
	_engine.dismiss_radiogram(rad_id)
	_refresh_views()


func _on_event_clicked(event_index: int) -> void:
	if event_index < 0 or event_index >= _engine.event_log.size():
		return
	var ev: SimTypes.SimEvent = _engine.event_log[event_index]
	if ev.has_world_pos:
		_camera.focus_on(ev.world_pos)
	if not ev.node_id.is_empty():
		_selected_node_id = ev.node_id
		_map_view.set_selected_node(ev.node_id)
	_refresh_views()


func _on_layer_toggled(layer_name: String, enabled: bool) -> void:
	_map_view.set_layer_flag(layer_name, enabled)


func _on_speed_selected(speed_multiplier: float) -> void:
	if speed_multiplier > 0.0:
		_last_nonzero_speed = speed_multiplier
		_hud.clear_autopause_notice()
	_speed_multiplier = speed_multiplier
	_tick_accumulator = 0.0
	_refresh_views()
