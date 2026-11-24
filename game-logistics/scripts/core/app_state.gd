extends Node

signal settings_changed()
signal campaign_updated()

const VERSION_STRING: String = "v0.6.0-alpha"
const SETTINGS_PATH: String = "user://settings.cfg"
const SAVES_DIR: String = "user://saves"

const SCENE_MAIN_MENU: String = "res://scenes/main_menu.tscn"
const SCENE_CAMPAIGN_SELECT: String = "res://scenes/campaign_select.tscn"
const SCENE_CAMPAIGN_HUB: String = "res://scenes/campaign_hub.tscn"
const SCENE_BATTLE: String = "res://scenes/main.tscn"
const SCENE_SETTINGS: String = "res://scenes/settings_menu.tscn"

# Display & Gameplay Settings
var window_mode: int = 0 # 0: Windowed, 1: Fullscreen, 2: Borderless
var vsync_enabled: bool = true
var camera_scroll_speed: float = 1.0 # 0.5 .. 2.0
var default_sim_speed: float = 1.0 # 0.5 or 1.0
var autopause_train_arrived: bool = false
var autopause_assault_or_phase: bool = true
var autopause_strike_or_bridge: bool = true

# Data-driven catalogs
var campaigns: Array[Dictionary] = []
var upgrades_catalog: Array[Dictionary] = []

# Active campaign / mission launch context
var active_campaign_id: String = ""
var active_operation_id: String = ""
var is_quick_battle: bool = false
var pending_scenario_path: String = "res://data/scenario_offensive.json"
var current_save: Dictionary = {}


func _ready() -> void:
	reload_catalogs()
	load_settings()
	apply_display_settings()


func reload_catalogs() -> void:
	campaigns = CampaignData.load_campaigns_index()
	upgrades_catalog = CampaignData.load_upgrades_catalog()


# -----------------------------------------------------------------------------
# Settings (user://settings.cfg)
# -----------------------------------------------------------------------------

func load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	var err: Error = cfg.load(SETTINGS_PATH)
	if err != OK:
		return
	window_mode = clampi(int(cfg.get_value("display", "window_mode", 0)), 0, 2)
	vsync_enabled = bool(cfg.get_value("display", "vsync", true))
	camera_scroll_speed = clampf(float(cfg.get_value("gameplay", "camera_scroll_speed", 1.0)), 0.5, 2.0)
	var def_sp: float = float(cfg.get_value("gameplay", "default_sim_speed", 1.0))
	default_sim_speed = 0.5 if is_equal_approx(def_sp, 0.5) else 1.0
	autopause_train_arrived = bool(cfg.get_value("autopause", "train_arrived", false))
	autopause_assault_or_phase = bool(cfg.get_value("autopause", "assault_or_phase", true))
	autopause_strike_or_bridge = bool(cfg.get_value("autopause", "strike_or_bridge", true))


func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("display", "window_mode", window_mode)
	cfg.set_value("display", "vsync", vsync_enabled)
	cfg.set_value("gameplay", "camera_scroll_speed", camera_scroll_speed)
	cfg.set_value("gameplay", "default_sim_speed", default_sim_speed)
	cfg.set_value("autopause", "train_arrived", autopause_train_arrived)
	cfg.set_value("autopause", "assault_or_phase", autopause_assault_or_phase)
	cfg.set_value("autopause", "strike_or_bridge", autopause_strike_or_bridge)
	cfg.save(SETTINGS_PATH)
	apply_display_settings()
	settings_changed.emit()


func reset_default_settings() -> void:
	window_mode = 0
	vsync_enabled = true
	camera_scroll_speed = 1.0
	default_sim_speed = 1.0
	autopause_train_arrived = false
	autopause_assault_or_phase = true
	autopause_strike_or_bridge = true
	save_settings()


func apply_display_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return
	match window_mode:
		1:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		_:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	)


# -----------------------------------------------------------------------------
# Campaign Save Management (user://saves/campaign_<id>.json)
# -----------------------------------------------------------------------------

func get_save_path(campaign_id: String) -> String:
	return "%s/campaign_%s.json" % [SAVES_DIR, campaign_id]


func has_campaign_save(campaign_id: String) -> bool:
	if campaign_id.is_empty():
		return false
	return FileAccess.file_exists(get_save_path(campaign_id))


func has_any_save() -> bool:
	return not get_most_recent_campaign_id().is_empty()


func get_most_recent_campaign_id() -> String:
	var best_id: String = ""
	var best_time: int = -1
	for c: Dictionary in campaigns:
		if bool(c.get("coming_soon", false)):
			continue
		var cid: String = str(c.get("id", ""))
		var spath: String = get_save_path(cid)
		if FileAccess.file_exists(spath):
			var data: Dictionary = _read_save_dict(spath)
			var ts: int = int(data.get("updated_unix", 0))
			if best_id.is_empty() or ts >= best_time:
				best_id = cid
				best_time = ts
	return best_id


func load_campaign_save(campaign_id: String) -> Dictionary:
	var spath: String = get_save_path(campaign_id)
	if FileAccess.file_exists(spath):
		var data: Dictionary = _read_save_dict(spath)
		if not data.is_empty():
			return data
	return {}


func start_new_campaign(campaign_id: String) -> Dictionary:
	var camp: Dictionary = get_campaign_by_id(campaign_id)
	var start_cp: int = int(camp.get("starting_command_points", 60))
	var base_fleet_raw: Variant = camp.get("starting_fleet", {})
	var base_fleet: Dictionary = {
		"CARGO": 5,
		"TANKER": 3,
		"ENGINEER": 1,
		"ARMORED": 0,
	}
	if typeof(base_fleet_raw) == TYPE_DICTIONARY:
		var bf: Dictionary = base_fleet_raw
		base_fleet["CARGO"] = int(bf.get("CARGO", 5))
		base_fleet["TANKER"] = int(bf.get("TANKER", 3))
		base_fleet["ENGINEER"] = int(bf.get("ENGINEER", 1))
		base_fleet["ARMORED"] = int(bf.get("ARMORED", 0))

	var save_dict: Dictionary = {
		"campaign_id": campaign_id,
		"command_points": start_cp,
		"completed_operations": [],
		"awarded_primary_ops": [],
		"awarded_secondaries": [],
		"purchased_upgrades": [],
		"modernized_by_op": {},
		"fleet": base_fleet,
		"history": [],
		"updated_unix": int(Time.get_unix_time_from_system()),
	}
	active_campaign_id = campaign_id
	current_save = save_dict
	save_current_campaign()
	return current_save


func ensure_campaign_loaded(campaign_id: String) -> Dictionary:
	if has_campaign_save(campaign_id):
		current_save = load_campaign_save(campaign_id)
		active_campaign_id = campaign_id
		if current_save.is_empty():
			return start_new_campaign(campaign_id)
		return current_save
	return start_new_campaign(campaign_id)


func save_current_campaign() -> void:
	if active_campaign_id.is_empty() or current_save.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(SAVES_DIR)
	current_save["updated_unix"] = int(Time.get_unix_time_from_system())
	var spath: String = get_save_path(active_campaign_id)
	var file: FileAccess = FileAccess.open(spath, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(current_save, "  "))
		file.close()
	campaign_updated.emit()


func get_campaign_by_id(campaign_id: String) -> Dictionary:
	for c: Dictionary in campaigns:
		if str(c.get("id", "")) == campaign_id:
			return c
	return {}


func get_operation_by_id(campaign_id: String, op_id: String) -> Dictionary:
	var camp: Dictionary = get_campaign_by_id(campaign_id)
	var ops_raw: Variant = camp.get("operations", [])
	if typeof(ops_raw) != TYPE_ARRAY:
		return {}
	var ops: Array = ops_raw
	for op_var: Variant in ops:
		if typeof(op_var) == TYPE_DICTIONARY:
			var op: Dictionary = op_var
			if str(op.get("id", "")) == op_id:
				return op
	return {}


func is_operation_completed(op_id: String, save_dict: Dictionary = current_save) -> bool:
	var completed_raw: Variant = save_dict.get("completed_operations", [])
	if typeof(completed_raw) == TYPE_ARRAY:
		var arr: Array = completed_raw
		for item: Variant in arr:
			if str(item) == op_id:
				return true
	return false


func is_operation_unlocked(op_dict: Dictionary, save_dict: Dictionary = current_save) -> bool:
	if bool(op_dict.get("coming_soon", false)):
		return false
	var req: String = str(op_dict.get("requires_operation", ""))
	if req.is_empty():
		return true
	return is_operation_completed(req, save_dict)


func get_campaign_progress(campaign_id: String) -> Dictionary:
	var camp: Dictionary = get_campaign_by_id(campaign_id)
	var ops_raw: Variant = camp.get("operations", [])
	var playable_total: int = 0
	var completed_cnt: int = 0
	var save_dict: Dictionary = load_campaign_save(campaign_id)
	if typeof(ops_raw) == TYPE_ARRAY:
		var ops: Array = ops_raw
		for op_var: Variant in ops:
			if typeof(op_var) != TYPE_DICTIONARY:
				continue
			var op: Dictionary = op_var
			if bool(op.get("coming_soon", false)):
				continue
			playable_total += 1
			if not save_dict.is_empty() and is_operation_completed(str(op.get("id", "")), save_dict):
				completed_cnt += 1
	return {
		"completed": completed_cnt,
		"total": playable_total,
	}


func get_purchased_upgrades(save_dict: Dictionary = current_save) -> Array[String]:
	var out: Array[String] = []
	var raw: Variant = save_dict.get("purchased_upgrades", [])
	if typeof(raw) == TYPE_ARRAY:
		var arr: Array = raw
		for item: Variant in arr:
			out.append(str(item))
	return out


func is_upgrade_purchased(upgrade_id: String, save_dict: Dictionary = current_save) -> bool:
	return get_purchased_upgrades(save_dict).has(upgrade_id)


func purchase_upgrade(upgrade_id: String) -> bool:
	if current_save.is_empty() or is_upgrade_purchased(upgrade_id):
		return false
	var upg: Dictionary = {}
	for u: Dictionary in upgrades_catalog:
		if str(u.get("id", "")) == upgrade_id:
			upg = u
			break
	if upg.is_empty():
		return false

	var cost: int = int(upg.get("cost_cp", 0))
	var cur_cp: int = int(current_save.get("command_points", 0))
	if cur_cp < cost:
		return false

	current_save["command_points"] = cur_cp - cost
	var purchased: Array = current_save.get("purchased_upgrades", [])
	purchased.append(upgrade_id)
	current_save["purchased_upgrades"] = purchased

	var eff_raw: Variant = upg.get("effects", {})
	if typeof(eff_raw) == TYPE_DICTIONARY:
		var eff: Dictionary = eff_raw
		var fleet_raw: Variant = current_save.get("fleet", {})
		var fleet: Dictionary = fleet_raw if typeof(fleet_raw) == TYPE_DICTIONARY else {"CARGO": 5, "TANKER": 3, "ENGINEER": 1, "ARMORED": 0}
		fleet["CARGO"] = int(fleet.get("CARGO", 5)) + int(eff.get("bonus_cargo_convoys", 0))
		fleet["TANKER"] = int(fleet.get("TANKER", 3)) + int(eff.get("bonus_tanker_convoys", 0))
		fleet["ENGINEER"] = int(fleet.get("ENGINEER", 1)) + int(eff.get("bonus_engineer_convoys", 0))
		fleet["ARMORED"] = int(fleet.get("ARMORED", 0)) + int(eff.get("bonus_armored_convoys", 0))
		current_save["fleet"] = fleet

	save_current_campaign()
	return true


func get_active_modifiers() -> SimTypes.CampaignModifiers:
	if is_quick_battle or current_save.is_empty():
		return SimTypes.CampaignModifiers.new()
	return CampaignData.build_modifiers(get_purchased_upgrades(current_save), upgrades_catalog)


func record_operation_result(
	sim_result: SimTypes.GameResult,
	stats: SimTypes.SimStats,
	secondary_results: Array[Dictionary]
) -> Dictionary:
	var summary: Dictionary = {
		"primary_cp_earned": 0,
		"secondary_cp_earned": 0,
		"total_cp_earned": 0,
		"already_awarded_primary": false,
		"total_command_points": int(current_save.get("command_points", 0)),
	}
	if is_quick_battle or active_campaign_id.is_empty() or active_operation_id.is_empty() or current_save.is_empty():
		return summary

	var op: Dictionary = get_operation_by_id(active_campaign_id, active_operation_id)
	var is_victory: bool = (sim_result == SimTypes.GameResult.VICTORY)

	var primary_cp: int = 0
	var secondary_cp: int = 0
	var already_primary: bool = false

	if is_victory:
		var completed_ops: Array = current_save.get("completed_operations", [])
		if not completed_ops.has(active_operation_id):
			completed_ops.append(active_operation_id)
		current_save["completed_operations"] = completed_ops

		var awarded_primary: Array = current_save.get("awarded_primary_ops", [])
		if awarded_primary.has(active_operation_id):
			already_primary = true
		else:
			awarded_primary.append(active_operation_id)
			primary_cp = int(op.get("reward_cp", 100))
		current_save["awarded_primary_ops"] = awarded_primary

		var awarded_sec: Array = current_save.get("awarded_secondaries", [])
		for sec: Dictionary in secondary_results:
			if not bool(sec.get("completed", false)):
				continue
			var sec_key: String = "%s::%s" % [active_operation_id, str(sec.get("id", ""))]
			if not awarded_sec.has(sec_key):
				awarded_sec.append(sec_key)
				secondary_cp += int(sec.get("bonus_cp", 0))
		current_save["awarded_secondaries"] = awarded_sec

	var earned_total: int = primary_cp + secondary_cp
	var new_cp: int = int(current_save.get("command_points", 0)) + earned_total
	current_save["command_points"] = new_cp

	var sec_done_ids: Array[String] = []
	for sec: Dictionary in secondary_results:
		if bool(sec.get("completed", false)):
			sec_done_ids.append(str(sec.get("id", "")))

	var mod_map_raw: Variant = current_save.get("modernized_by_op", {})
	var mod_map: Dictionary = mod_map_raw if typeof(mod_map_raw) == TYPE_DICTIONARY else {}
	if is_victory:
		mod_map[active_operation_id] = maxi(int(mod_map.get(active_operation_id, 0)), stats.units_modernized)
	current_save["modernized_by_op"] = mod_map

	var history: Array = current_save.get("history", [])
	history.append({
		"operation_id": active_operation_id,
		"operation_name": str(op.get("name", active_operation_id)),
		"victory": is_victory,
		"elapsed_hours": snappedf(stats.elapsed_hours, 0.1),
		"total_delivered_tons": snappedf(stats.total_delivered_tons, 1.0),
		"wounded_evacuated": snappedf(stats.wounded_evacuated, 1.0),
		"wounded_evac_ratio": snappedf(stats.wounded_evac_ratio, 0.01),
		"depot_strikes": stats.depot_strikes,
		"field_depots_deployed": stats.field_depots_deployed,
		"units_modernized": stats.units_modernized,
		"convoys_disabled_count": stats.convoys_disabled_count,
		"secondary_completed": sec_done_ids,
		"cp_earned": earned_total,
	})
	current_save["history"] = history
	save_current_campaign()

	summary["primary_cp_earned"] = primary_cp
	summary["secondary_cp_earned"] = secondary_cp
	summary["total_cp_earned"] = earned_total
	summary["already_awarded_primary"] = already_primary
	summary["total_command_points"] = new_cp
	summary["units_modernized"] = stats.units_modernized
	return summary


func get_total_modernized_units(save_dict: Dictionary = current_save) -> int:
	var mod_map_raw: Variant = save_dict.get("modernized_by_op", {})
	if typeof(mod_map_raw) != TYPE_DICTIONARY:
		return 0
	var total: int = 0
	var mod_map: Dictionary = mod_map_raw
	for k: Variant in mod_map.keys():
		total += int(mod_map[k])
	return total


# -----------------------------------------------------------------------------
# Scene Navigation
# -----------------------------------------------------------------------------

func goto_main_menu() -> void:
	is_quick_battle = false
	get_tree().change_scene_to_file(SCENE_MAIN_MENU)


func goto_campaign_select() -> void:
	get_tree().change_scene_to_file(SCENE_CAMPAIGN_SELECT)


func goto_campaign_hub(campaign_id: String = "") -> void:
	if not campaign_id.is_empty():
		ensure_campaign_loaded(campaign_id)
	is_quick_battle = false
	get_tree().change_scene_to_file(SCENE_CAMPAIGN_HUB)


func launch_operation(campaign_id: String, op_id: String) -> void:
	ensure_campaign_loaded(campaign_id)
	var op: Dictionary = get_operation_by_id(campaign_id, op_id)
	if op.is_empty():
		push_error("Operation not found: %s / %s" % [campaign_id, op_id])
		return
	active_campaign_id = campaign_id
	active_operation_id = op_id
	is_quick_battle = false
	pending_scenario_path = str(op.get("scenario_path", "res://data/scenario_offensive.json"))
	get_tree().change_scene_to_file(SCENE_BATTLE)


func launch_quick_scenario(scenario_path: String, op_id: String = "") -> void:
	is_quick_battle = true
	active_operation_id = op_id
	pending_scenario_path = scenario_path
	get_tree().change_scene_to_file(SCENE_BATTLE)


func _read_save_dict(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}
