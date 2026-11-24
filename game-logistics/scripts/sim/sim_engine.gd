class_name SimEngine
extends RefCounted

const TICK_MINUTES: int = 10
const TICKS_PER_HOUR: int = 6
const TICK_HOURS: float = 1.0 / 6.0

var config: SimTypes.ScenarioConfig = null
var campaign_modifiers: SimTypes.CampaignModifiers = SimTypes.CampaignModifiers.new()
var graph: WorldGraph = null
var convoys: Array[Convoy] = []
var event_log: Array[SimTypes.SimEvent] = []
var radiograms: Array[SimTypes.Radiogram] = []
var last_tick_autopause_tags: Array[SimTypes.AutoPauseTag] = []

var current_tick: int = 0
var phase: SimTypes.OperationPhase = SimTypes.OperationPhase.BUILDUP
var phase1_readiness_achieved: float = 0.0
var result: SimTypes.GameResult = SimTypes.GameResult.RUNNING
var result_reason: String = ""

var weather: SimTypes.Weather = SimTypes.Weather.CLEAR
var weather_seen: Dictionary[SimTypes.Weather, bool] = {}

var target_railhead_id: String = "rail_zapadnaya"
var inbound_train_target_id: String = "rail_zapadnaya"
var next_train_target_id: String = "rail_zapadnaya"
var inbound_train_slots: Array[SimTypes.TrainSlotType] = []
var next_train_slots: Array[SimTypes.TrainSlotType] = []
var truck_order_cooldown_ticks: int = 0

var arty_support_by_flank: Dictionary[String, bool] = {
	"NORTH": false,
	"SOUTH": false,
	"ALL": false,
}
var arty_support_ticks: int = 0
var _arty_out_warned: Dictionary[String, bool] = {}

var trains_arrived: int = 0
var convoys_spawned_by_train: int = 0
var strikes_triggered: int = 0
var bridges_damaged_count: int = 0
var bridges_repaired: int = 0
var roads_demined: int = 0
var objectives_captured: int = 0
var field_depots_deployed: int = 0
var field_depots_packed: int = 0
var units_modernized: int = 0
var convoys_damaged_hits: int = 0
var convoys_disabled_count: int = 0
var peak_depot_signature: float = 0.0
var min_sector_integrity_seen: float = 100.0
var total_wounded_generated: float = 0.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _fired_radiograms: Dictionary[String, bool] = {}
var _fired_bridge_strikes: Dictionary[int, bool] = {}
var _announced_high_waves: Dictionary[int, bool] = {}
var _next_convoy_num: int = 1
var _sector_supplied_this_tick: Dictionary[String, bool] = {}
var _was_night: bool = false
var _need_modernize_warned: bool = false


func load_scenario(path: String, modifiers: SimTypes.CampaignModifiers = null) -> bool:
	var loaded: ScenarioLoader.LoadResult = ScenarioLoader.load_from_file(path)
	if not loaded.ok:
		push_error(loaded.error)
		return false

	config = loaded.config
	campaign_modifiers = modifiers if modifiers != null else SimTypes.CampaignModifiers.new()
	graph = loaded.graph
	graph.dirt_mud_speed_mult = campaign_modifiers.dirt_mud_speed_mult
	convoys.clear()
	event_log.clear()
	radiograms.clear()
	last_tick_autopause_tags.clear()
	_fired_radiograms.clear()
	_fired_bridge_strikes.clear()
	_announced_high_waves.clear()
	weather_seen.clear()
	_arty_out_warned.clear()
	_sector_supplied_this_tick.clear()

	current_tick = 0
	phase = SimTypes.OperationPhase.BUILDUP
	phase1_readiness_achieved = 0.0
	result = SimTypes.GameResult.RUNNING
	result_reason = ""
	trains_arrived = 0
	convoys_spawned_by_train = 0
	strikes_triggered = 0
	bridges_damaged_count = 0
	bridges_repaired = 0
	roads_demined = 0
	objectives_captured = 0
	field_depots_deployed = 0
	field_depots_packed = 0
	units_modernized = 0
	convoys_damaged_hits = 0
	convoys_disabled_count = 0
	peak_depot_signature = 0.0
	min_sector_integrity_seen = 100.0
	total_wounded_generated = 0.0
	_need_modernize_warned = false
	arty_support_by_flank = {"NORTH": false, "SOUTH": false, "ALL": false}
	arty_support_ticks = 0
	truck_order_cooldown_ticks = 0
	_next_convoy_num = 1
	_was_night = is_night()
	_rng.seed = config.rng_seed

	for entry: Dictionary in config.initial_fleet:
		var ctype: SimTypes.ConvoyType = SimTypes.convoy_type_from_string(str(entry.get("type", "CARGO")))
		var spawn_id: String = str(entry.get("node", config.default_train_target))
		_spawn_convoy(spawn_id, ctype)

	for _bc: int in range(campaign_modifiers.bonus_cargo_convoys):
		_spawn_convoy(config.default_train_target, SimTypes.ConvoyType.CARGO)
	for _bt: int in range(campaign_modifiers.bonus_tanker_convoys):
		_spawn_convoy(config.default_train_target, SimTypes.ConvoyType.TANKER)
	for _be: int in range(campaign_modifiers.bonus_engineer_convoys):
		_spawn_convoy(config.default_train_target, SimTypes.ConvoyType.ENGINEER)
	for _ba: int in range(campaign_modifiers.bonus_armored_convoys):
		_spawn_convoy(config.default_train_target, SimTypes.ConvoyType.ARMORED)

	_update_frontline_danger()

	target_railhead_id = config.default_train_target
	inbound_train_target_id = config.default_train_target
	next_train_target_id = config.default_train_target
	inbound_train_slots = _clone_slots(config.default_train_slots)
	next_train_slots = _clone_slots(config.default_train_slots)
	_normalize_slots_size(inbound_train_slots)
	_normalize_slots_size(next_train_slots)

	for node: SimTypes.MapNode in graph.get_all_nodes():
		if node.is_vulnerable and node.signature > peak_depot_signature:
			peak_depot_signature = node.signature
		if node.node_type == SimTypes.NodeType.FRONT_SECTOR and node.integrity < min_sector_integrity_seen:
			min_sector_integrity_seen = node.integrity

	_apply_weather(0)
	_apply_wave_intensities(0)
	_trigger_scheduled_radiograms(0)
	var start_msg: String = "%s началась. Оборонительная операция (%d ч)." % [config.scenario_name, config.duration_hours]
	if config.mission_mode == SimTypes.MissionMode.OFFENSIVE:
		start_msg = "%s началась. Фаза 1: накопление (%d ч)." % [config.scenario_name, config.phase2_start_hour]
	_emit_event(
		SimTypes.EventSeverity.INFO,
		"SYSTEM",
		"",
		start_msg
	)
	return true


func get_effective_train_slots() -> int:
	if config == null:
		return 6
	return maxi(1, config.train_slots + campaign_modifiers.bonus_train_slots)


func step_tick() -> void:
	if result != SimTypes.GameResult.RUNNING or config == null or graph == null:
		return

	last_tick_autopause_tags.clear()
	current_tick += 1
	if truck_order_cooldown_ticks > 0:
		truck_order_cooldown_ticks -= 1

	for node: SimTypes.MapNode in graph.get_all_nodes():
		node.had_traffic_this_tick = false
		node.active_loading_count = 0
		node.last_sig_storage = 0.0
		node.last_sig_traffic = 0.0
		node.last_sig_queue = 0.0
		node.last_sig_idle = 0.0
		node.last_sig_decay = 0.0

	var night_now: bool = is_night()
	if night_now and not _was_night:
		var night_convoys: int = 0
		for c: Convoy in convoys:
			if c.night_only and c.state != SimTypes.ConvoyState.IDLE:
				night_convoys += 1
		if night_convoys > 0:
			_emit_event(
				SimTypes.EventSeverity.INFO,
				"SYSTEM",
				"",
				"Наступила ночь (20:00): %d колонн(ы) в ночном режиме вышли на маршруты." % night_convoys
			)
	_was_night = night_now

	var elapsed_hour: int = int(floor(float(current_tick - 1) / float(TICKS_PER_HOUR)))
	_check_phase_transition(elapsed_hour)
	_apply_weather(elapsed_hour)
	_apply_wave_intensities(elapsed_hour)
	_trigger_bridge_strikes(elapsed_hour)
	_trigger_scheduled_radiograms(elapsed_hour)

	_step_railhead_deliveries()
	_step_convoys()
	_check_bridge_repairs()
	_step_field_depots()
	_step_reequipment()
	graph.step_road_recovery(0.0015, 0.0030)
	_step_road_wear_warnings()
	_step_depots_and_recon()
	_step_artillery()
	_step_front_sectors()
	_step_objectives()
	_evaluate_win_loss()


func validate_dispatch(
	origin_id: String,
	dest_id: String,
	ctype: SimTypes.ConvoyType,
	pref: SimTypes.CargoPreference,
	mode: SimTypes.OrderMode
) -> Dictionary:
	if origin_id.is_empty() or dest_id.is_empty() or origin_id == dest_id:
		return {"ok": false, "reason": "Выберите другой узел назначения"}
	var dest_node: SimTypes.MapNode = graph.get_node(dest_id)
	if dest_node == null:
		return {"ok": false, "reason": "Узел не найден"}
	if dest_node.owner != SimTypes.Owner.FRIENDLY:
		return {"ok": false, "reason": "Узел контролируется противником"}

	if dest_node.node_type == SimTypes.NodeType.JUNCTION and mode != SimTypes.OrderMode.REDEPLOY:
		var is_eng_parts: bool = (
			ctype == SimTypes.ConvoyType.ENGINEER
			and (pref == SimTypes.CargoPreference.PARTS or pref == SimTypes.CargoPreference.MIXED)
		)
		if not is_eng_parts:
			return {"ok": false, "reason": "Развязка без склада: используйте «Передислокацию» или «Инж + Запчасти»"}
		if not graph.junction_needs_engineer(dest_id):
			return {"ok": false, "reason": "Мост и подъезды к развязке уже исправны"}

	if mode != SimTypes.OrderMode.REDEPLOY:
		if ctype == SimTypes.ConvoyType.TANKER and pref != SimTypes.CargoPreference.FUEL and pref != SimTypes.CargoPreference.MIXED:
			return {"ok": false, "reason": "АТЗ перевозит только Топливо"}
		if ctype == SimTypes.ConvoyType.ENGINEER and pref != SimTypes.CargoPreference.PARTS and pref != SimTypes.CargoPreference.EQUIPMENT and pref != SimTypes.CargoPreference.MIXED:
			return {"ok": false, "reason": "Инженерная колонна возит только Запчасти или Перевооружение"}

	var path: Array[String] = graph.find_path(origin_id, dest_id, weather, ctype)
	if path.size() < 2:
		return {"ok": false, "reason": "Нет доступного маршрута"}

	return {"ok": true, "reason": ""}


func dispatch_idle_from_node(
	origin_id: String,
	dest_id: String,
	convoy_type_filter: int,
	pref: SimTypes.CargoPreference,
	mode: SimTypes.OrderMode,
	evac_wounded: bool = false,
	is_night_only: bool = false
) -> Convoy:
	for convoy: Convoy in convoys:
		if convoy.state != SimTypes.ConvoyState.IDLE or convoy.current_node_id != origin_id:
			continue
		if convoy_type_filter >= 0 and int(convoy.convoy_type) != convoy_type_filter:
			continue
		if convoy.assign_order(dest_id, pref, mode, graph, weather, evac_wounded, is_night_only):
			var orig_node: SimTypes.MapNode = graph.get_node(origin_id)
			var dest_node: SimTypes.MapNode = graph.get_node(dest_id)
			var orig_name: String = orig_node.display_name if orig_node != null else origin_id
			var dest_name: String = dest_node.display_name if dest_node != null else dest_id
			var night_tag: String = ", ночью" if is_night_only else ""
			_emit_event(
				SimTypes.EventSeverity.INFO,
				"CONVOY",
				dest_id,
				"%s (%s): %s -> %s (%s%s)." % [
					convoy.callsign,
					SimTypes.convoy_type_label(convoy.convoy_type),
					orig_name,
					dest_name,
					SimTypes.order_mode_label(mode),
					night_tag,
				],
				dest_node.position if dest_node != null else Vector2.ZERO
			)
			return convoy
	return null


func dispatch_convoy(
	convoy_id: String,
	dest_id: String,
	pref: SimTypes.CargoPreference,
	mode: SimTypes.OrderMode,
	evac_wounded: bool = false,
	is_night_only: bool = false
) -> bool:
	for convoy: Convoy in convoys:
		if convoy.id == convoy_id:
			return convoy.assign_order(dest_id, pref, mode, graph, weather, evac_wounded, is_night_only)
	return false


func set_convoy_cargo_pref(convoy_id: String, pref: SimTypes.CargoPreference) -> bool:
	for convoy: Convoy in convoys:
		if convoy.id == convoy_id:
			return convoy.set_cargo_preference(pref)
	return false


func toggle_convoy_night_only(convoy_id: String) -> bool:
	for convoy: Convoy in convoys:
		if convoy.id == convoy_id:
			convoy.set_night_only(not convoy.night_only)
			return true
	return false


func toggle_convoy_evac_wounded(convoy_id: String) -> bool:
	for convoy: Convoy in convoys:
		if convoy.id == convoy_id:
			convoy.set_evacuate_wounded(not convoy.evacuate_wounded)
			return true
	return false


func toggle_node_camouflage(node_id: String) -> bool:
	var node: SimTypes.MapNode = graph.get_node(node_id)
	if node == null or not node.is_vulnerable:
		return false
	node.camouflaged = not node.camouflaged
	_emit_event(
		SimTypes.EventSeverity.INFO,
		"CAMO",
		node.id,
		"%s: маскировка %s (%s)." % [
			node.display_name,
			"ВКЛЮЧЕНА" if node.camouflaged else "СНЯТА",
			"-50% сигнатуры, +40% погрузка" if node.camouflaged else "обычный режим погрузки",
		],
		node.position
	)
	return true


func stop_convoy_loop(convoy_id: String) -> bool:
	for convoy: Convoy in convoys:
		if convoy.id == convoy_id and convoy.loop:
			convoy.stop_loop()
			_emit_event(
				SimTypes.EventSeverity.INFO,
				"CONVOY",
				convoy.destination_node_id,
				"%s завершит текущий рейс без повтора." % convoy.callsign
			)
			return true
	return false


func get_ticks_until_next_train() -> int:
	if config == null:
		return 0
	var interval_ticks: int = maxi(1, config.railhead_interval_hours * TICKS_PER_HOUR)
	return interval_ticks - (current_tick % interval_ticks)


func get_ticks_until_next_recon() -> int:
	if config == null:
		return 0
	var interval_ticks: int = maxi(1, config.recon_interval_hours * TICKS_PER_HOUR)
	return interval_ticks - (current_tick % interval_ticks)


func get_max_vulnerable_signature() -> float:
	if graph == null:
		return 0.0
	var m: float = 0.0
	for n: SimTypes.MapNode in graph.get_all_nodes():
		if n.is_vulnerable and n.signature > m:
			m = n.signature
	return m


func get_signature_rate_breakdown(node_id: String) -> Dictionary:
	var node: SimTypes.MapNode = graph.get_node(node_id)
	if node == null:
		return {}
	var mult: float = float(TICKS_PER_HOUR)
	var stor_h: float = node.last_sig_storage * mult
	var traf_h: float = node.last_sig_traffic * mult
	var queue_h: float = node.last_sig_queue * mult
	var idle_h: float = node.last_sig_idle * mult
	var dec_h: float = node.last_sig_decay * mult
	var net_h: float = stor_h + traf_h + queue_h + idle_h + dec_h
	return {
		"storage_per_h": stor_h,
		"traffic_per_h": traf_h,
		"queue_per_h": queue_h,
		"idle_per_h": idle_h,
		"decay_per_h": dec_h,
		"net_per_h": net_h,
	}


func is_inbound_train_locked() -> bool:
	if config == null:
		return false
	return get_ticks_until_next_train() <= config.train_lock_hours * TICKS_PER_HOUR


func get_editable_train_target() -> String:
	if is_inbound_train_locked():
		return next_train_target_id
	return inbound_train_target_id


func set_train_target_railhead(node_id: String) -> bool:
	var node: SimTypes.MapNode = graph.get_node(node_id)
	if node == null or node.node_type != SimTypes.NodeType.RAILHEAD:
		return false
	if is_inbound_train_locked():
		next_train_target_id = node_id
	else:
		inbound_train_target_id = node_id
	target_railhead_id = node_id
	return true


func get_editable_train_slots() -> Array[SimTypes.TrainSlotType]:
	if is_inbound_train_locked():
		return next_train_slots
	return inbound_train_slots


func set_editable_train_slot(slot_idx: int, slot_type: SimTypes.TrainSlotType) -> bool:
	var slots: Array[SimTypes.TrainSlotType] = get_editable_train_slots()
	if slot_idx < 0 or slot_idx >= slots.size():
		return false
	if slot_type in [
		SimTypes.TrainSlotType.TRUCK_CARGO,
		SimTypes.TrainSlotType.TRUCK_TANKER,
		SimTypes.TrainSlotType.TRUCK_ENGINEER,
		SimTypes.TrainSlotType.TRUCK_ARMORED,
		SimTypes.TrainSlotType.TRUCK_LOCKED,
		SimTypes.TrainSlotType.EQUIPMENT_PLATFORM,
		SimTypes.TrainSlotType.EQUIPMENT_LOCKED,
	]:
		return false

	if slots[slot_idx] in [SimTypes.TrainSlotType.TRUCK_CARGO, SimTypes.TrainSlotType.TRUCK_TANKER, SimTypes.TrainSlotType.TRUCK_ENGINEER, SimTypes.TrainSlotType.TRUCK_ARMORED]:
		slots[slot_idx] = slot_type
		if slot_idx + 1 < slots.size() and slots[slot_idx + 1] == SimTypes.TrainSlotType.TRUCK_LOCKED:
			slots[slot_idx + 1] = SimTypes.TrainSlotType.AMMO
		return true
	if slots[slot_idx] == SimTypes.TrainSlotType.TRUCK_LOCKED:
		slots[slot_idx] = slot_type
		if slot_idx - 1 >= 0 and slots[slot_idx - 1] in [SimTypes.TrainSlotType.TRUCK_CARGO, SimTypes.TrainSlotType.TRUCK_TANKER, SimTypes.TrainSlotType.TRUCK_ENGINEER, SimTypes.TrainSlotType.TRUCK_ARMORED]:
			slots[slot_idx - 1] = SimTypes.TrainSlotType.FUEL
		return true
	if slots[slot_idx] == SimTypes.TrainSlotType.EQUIPMENT_PLATFORM:
		slots[slot_idx] = slot_type
		if slot_idx + 1 < slots.size() and slots[slot_idx + 1] == SimTypes.TrainSlotType.EQUIPMENT_LOCKED:
			slots[slot_idx + 1] = SimTypes.TrainSlotType.AMMO
		return true
	if slots[slot_idx] == SimTypes.TrainSlotType.EQUIPMENT_LOCKED:
		slots[slot_idx] = slot_type
		if slot_idx - 1 >= 0 and slots[slot_idx - 1] == SimTypes.TrainSlotType.EQUIPMENT_PLATFORM:
			slots[slot_idx - 1] = SimTypes.TrainSlotType.FUEL
		return true

	slots[slot_idx] = slot_type
	return true


func cycle_editable_train_slot(slot_idx: int) -> bool:
	var slots: Array[SimTypes.TrainSlotType] = get_editable_train_slots()
	if slot_idx < 0 or slot_idx >= slots.size():
		return false
	var next_type: SimTypes.TrainSlotType = SimTypes.TrainSlotType.FUEL
	match slots[slot_idx]:
		SimTypes.TrainSlotType.FUEL:
			next_type = SimTypes.TrainSlotType.AMMO
		SimTypes.TrainSlotType.AMMO:
			next_type = SimTypes.TrainSlotType.PROVISIONS
		SimTypes.TrainSlotType.PROVISIONS:
			next_type = SimTypes.TrainSlotType.PARTS
		SimTypes.TrainSlotType.PARTS:
			next_type = SimTypes.TrainSlotType.FUEL
		_:
			next_type = SimTypes.TrainSlotType.FUEL
	return set_editable_train_slot(slot_idx, next_type)


func has_truck_convoy_in_slots(slots: Array[SimTypes.TrainSlotType]) -> bool:
	for s: SimTypes.TrainSlotType in slots:
		if s in [SimTypes.TrainSlotType.TRUCK_CARGO, SimTypes.TrainSlotType.TRUCK_TANKER, SimTypes.TrainSlotType.TRUCK_ENGINEER, SimTypes.TrainSlotType.TRUCK_ARMORED]:
			return true
	return false


func get_truck_order_in_slots(slots: Array[SimTypes.TrainSlotType]) -> String:
	for s: SimTypes.TrainSlotType in slots:
		if s == SimTypes.TrainSlotType.TRUCK_CARGO:
			return "Борт"
		if s == SimTypes.TrainSlotType.TRUCK_TANKER:
			return "АТЗ"
		if s == SimTypes.TrainSlotType.TRUCK_ENGINEER:
			return "Инж"
		if s == SimTypes.TrainSlotType.TRUCK_ARMORED:
			return "БТР"
	return ""


func cycle_truck_convoy_order() -> bool:
	var slots: Array[SimTypes.TrainSlotType] = get_editable_train_slots()
	if slots.size() < 2:
		return false

	var last_idx: int = slots.size() - 2
	var cur: SimTypes.TrainSlotType = slots[last_idx]
	if cur == SimTypes.TrainSlotType.TRUCK_CARGO:
		slots[last_idx] = SimTypes.TrainSlotType.TRUCK_TANKER
		slots[last_idx + 1] = SimTypes.TrainSlotType.TRUCK_LOCKED
		return true
	if cur == SimTypes.TrainSlotType.TRUCK_TANKER:
		slots[last_idx] = SimTypes.TrainSlotType.TRUCK_ENGINEER
		slots[last_idx + 1] = SimTypes.TrainSlotType.TRUCK_LOCKED
		return true
	if cur == SimTypes.TrainSlotType.TRUCK_ENGINEER:
		slots[last_idx] = SimTypes.TrainSlotType.TRUCK_ARMORED
		slots[last_idx + 1] = SimTypes.TrainSlotType.TRUCK_LOCKED
		return true
	if cur == SimTypes.TrainSlotType.TRUCK_ARMORED:
		slots[last_idx] = SimTypes.TrainSlotType.PROVISIONS
		slots[last_idx + 1] = SimTypes.TrainSlotType.PARTS
		return true

	if truck_order_cooldown_ticks > 0:
		return false
	slots[last_idx] = SimTypes.TrainSlotType.TRUCK_CARGO
	slots[last_idx + 1] = SimTypes.TrainSlotType.TRUCK_LOCKED
	return true


func set_truck_convoy_order(ctype: SimTypes.ConvoyType) -> bool:
	if truck_order_cooldown_ticks > 0:
		return false
	var slots: Array[SimTypes.TrainSlotType] = get_editable_train_slots()
	if slots.size() < 2:
		return false
	var last_idx: int = slots.size() - 2
	match ctype:
		SimTypes.ConvoyType.CARGO:
			slots[last_idx] = SimTypes.TrainSlotType.TRUCK_CARGO
		SimTypes.ConvoyType.TANKER:
			slots[last_idx] = SimTypes.TrainSlotType.TRUCK_TANKER
		SimTypes.ConvoyType.ENGINEER:
			slots[last_idx] = SimTypes.TrainSlotType.TRUCK_ENGINEER
		SimTypes.ConvoyType.ARMORED:
			slots[last_idx] = SimTypes.TrainSlotType.TRUCK_ARMORED
	slots[last_idx + 1] = SimTypes.TrainSlotType.TRUCK_LOCKED
	return true


func has_equipment_platform_in_slots(slots: Array[SimTypes.TrainSlotType]) -> bool:
	for s: SimTypes.TrainSlotType in slots:
		if s == SimTypes.TrainSlotType.EQUIPMENT_PLATFORM:
			return true
	return false


func toggle_equipment_platform_order() -> bool:
	var slots: Array[SimTypes.TrainSlotType] = get_editable_train_slots()
	if slots.size() < 2:
		return false
	if slots[0] == SimTypes.TrainSlotType.EQUIPMENT_PLATFORM:
		slots[0] = SimTypes.TrainSlotType.FUEL
		if slots[1] == SimTypes.TrainSlotType.EQUIPMENT_LOCKED:
			slots[1] = SimTypes.TrainSlotType.AMMO
		return true
	if slots[0] in [SimTypes.TrainSlotType.TRUCK_CARGO, SimTypes.TrainSlotType.TRUCK_TANKER, SimTypes.TrainSlotType.TRUCK_ENGINEER, SimTypes.TrainSlotType.TRUCK_ARMORED, SimTypes.TrainSlotType.TRUCK_LOCKED]:
		return false
	if slots[1] in [SimTypes.TrainSlotType.TRUCK_CARGO, SimTypes.TrainSlotType.TRUCK_TANKER, SimTypes.TrainSlotType.TRUCK_ENGINEER, SimTypes.TrainSlotType.TRUCK_ARMORED, SimTypes.TrainSlotType.TRUCK_LOCKED]:
		return false
	slots[0] = SimTypes.TrainSlotType.EQUIPMENT_PLATFORM
	slots[1] = SimTypes.TrainSlotType.EQUIPMENT_LOCKED
	return true


func request_deploy_field_depot(node_id: String) -> Dictionary:
	var node: SimTypes.MapNode = graph.get_node(node_id)
	if node == null or not node.can_deploy_depot or node.node_type != SimTypes.NodeType.JUNCTION:
		return {"ok": false, "reason": "Площадка недоступна для развертывания"}
	if node.deploy_build_ticks_remaining > 0:
		return {"ok": false, "reason": "Строительство склада уже идёт"}

	node.deploy_requested = true
	var dispatched: String = ""
	for convoy: Convoy in convoys:
		if convoy.state != SimTypes.ConvoyState.IDLE or convoy.is_disabled():
			continue
		if convoy.convoy_type != SimTypes.ConvoyType.ENGINEER:
			continue
		if convoy.current_node_id == node_id:
			continue
		var origin_n: SimTypes.MapNode = graph.get_node(convoy.current_node_id)
		if origin_n != null and origin_n.get_stock(SimTypes.ResourceType.PARTS) >= 10.0:
			if convoy.assign_order(node_id, SimTypes.CargoPreference.PARTS, SimTypes.OrderMode.ONE_WAY_RETURN, graph, weather, false, false):
				dispatched = convoy.callsign
				break

	_emit_event(
		SimTypes.EventSeverity.INFO,
		"DEPOT",
		node_id,
		"Начата подготовка полевого склада: %s (%s)." % [
			node.display_name,
			("вышла " + dispatched) if not dispatched.is_empty() else "направьте Инж + 25т ЗП",
		],
		node.position
	)
	return {"ok": true, "dispatched_callsign": dispatched}


func request_pack_field_depot(node_id: String) -> bool:
	var node: SimTypes.MapNode = graph.get_node(node_id)
	if node == null or node.node_type != SimTypes.NodeType.FIELD_DEPOT:
		return false
	if node.pack_ticks_remaining > 0:
		return false
	node.pack_ticks_remaining = node.pack_ticks_total
	var stock_left: float = node.get_total_stock()
	_emit_event(
		SimTypes.EventSeverity.WARNING if stock_left > 5.0 else SimTypes.EventSeverity.INFO,
		"DEPOT",
		node_id,
		"%s: начато сворачивание (3 ч)%s." % [
			node.display_name,
			" — осталось %.0fт грузов!" % stock_left if stock_left > 5.0 else "",
		],
		node.position
	)
	return true


func get_idle_convoys_at(node_id: String) -> Array[Convoy]:
	var list: Array[Convoy] = []
	for convoy: Convoy in convoys:
		if convoy.state == SimTypes.ConvoyState.IDLE and not convoy.is_disabled() and convoy.current_node_id == node_id:
			list.append(convoy)
	return list


func get_idle_counts_by_type_at(node_id: String) -> Dictionary[SimTypes.ConvoyType, int]:
	var counts: Dictionary[SimTypes.ConvoyType, int] = {
		SimTypes.ConvoyType.CARGO: 0,
		SimTypes.ConvoyType.TANKER: 0,
		SimTypes.ConvoyType.ENGINEER: 0,
		SimTypes.ConvoyType.ARMORED: 0,
	}
	for convoy: Convoy in convoys:
		if convoy.state == SimTypes.ConvoyState.IDLE and not convoy.is_disabled() and convoy.current_node_id == node_id:
			counts[convoy.convoy_type] = counts.get(convoy.convoy_type, 0) + 1
	return counts


func get_all_idle_convoys() -> Array[Convoy]:
	var list: Array[Convoy] = []
	for convoy: Convoy in convoys:
		if convoy.state == SimTypes.ConvoyState.IDLE and not convoy.is_disabled():
			list.append(convoy)
	return list


func get_convoys_related_to_node(node_id: String) -> Array[Convoy]:
	var list: Array[Convoy] = []
	for convoy: Convoy in convoys:
		if convoy.current_node_id == node_id or convoy.origin_node_id == node_id or convoy.destination_node_id == node_id:
			list.append(convoy)
	return list


func get_buildup_readiness_ratio() -> float:
	if config == null or graph == null:
		return 0.0
	var cur_fuel: float = get_total_forward_stock(SimTypes.ResourceType.FUEL)
	var cur_ammo: float = get_total_forward_stock(SimTypes.ResourceType.AMMO)
	var req_fuel: float = maxf(1.0, config.phase1_readiness_target.get(SimTypes.ResourceType.FUEL, 340.0))
	var req_ammo: float = maxf(1.0, config.phase1_readiness_target.get(SimTypes.ResourceType.AMMO, 460.0))
	return clampf((minf(1.0, cur_fuel / req_fuel) + minf(1.0, cur_ammo / req_ammo)) * 0.5, 0.0, 1.0)


func get_total_forward_stock(res: SimTypes.ResourceType) -> float:
	if graph == null:
		return 0.0
	var total: float = 0.0
	for node: SimTypes.MapNode in graph.get_all_nodes():
		if node.node_type == SimTypes.NodeType.FRONT_SECTOR or node.node_type == SimTypes.NodeType.ARTILLERY or (node.node_type == SimTypes.NodeType.OBJECTIVE and node.owner == SimTypes.Owner.FRIENDLY):
			total += node.get_stock(res)
	return total


func get_total_front_stock(res: SimTypes.ResourceType) -> float:
	if graph == null:
		return 0.0
	var total: float = 0.0
	for sector: SimTypes.MapNode in graph.get_nodes_by_type(SimTypes.NodeType.FRONT_SECTOR):
		total += sector.get_stock(res)
	return total


func get_weather_forecast_6h() -> SimTypes.Weather:
	if config == null:
		return weather
	var target_hour: int = int(floor(float(current_tick) / float(TICKS_PER_HOUR))) + 6
	for we: SimTypes.WeatherEntry in config.weather_schedule:
		if target_hour >= we.start_hour and target_hour < we.end_hour:
			return we.weather
	return weather


func get_latest_active_radiogram() -> SimTypes.Radiogram:
	for i: int in range(radiograms.size() - 1, -1, -1):
		if not radiograms[i].dismissed:
			return radiograms[i]
	return null


func dismiss_radiogram(rad_id: String) -> void:
	for rad: SimTypes.Radiogram in radiograms:
		if rad.id == rad_id:
			rad.dismissed = true


func get_total_minutes_of_day() -> int:
	if config == null:
		return 0
	return config.start_hour * 60 + current_tick * TICK_MINUTES


func get_day() -> int:
	return int(floor(float(get_total_minutes_of_day()) / 1440.0)) + 1


func get_hour() -> int:
	return int(floor(float(get_total_minutes_of_day() % 1440) / 60.0))


func get_minute() -> int:
	return get_total_minutes_of_day() % 60


func get_elapsed_hours() -> float:
	return float(current_tick) / float(TICKS_PER_HOUR)


func is_night() -> bool:
	var h: int = get_hour()
	return h >= 20 or h < 6


func get_formatted_time() -> String:
	return "День %d | %02d:%02d" % [get_day(), get_hour(), get_minute()]


func get_total_wounded() -> float:
	if graph == null:
		return 0.0
	var total: float = 0.0
	for sector: SimTypes.MapNode in graph.get_nodes_by_type(SimTypes.NodeType.FRONT_SECTOR):
		total += sector.wounded
	return total


func get_total_wounded_evacuated() -> float:
	var total: float = 0.0
	for convoy: Convoy in convoys:
		total += convoy.total_wounded_evacuated
	return total


func get_total_delivered(res: SimTypes.ResourceType) -> float:
	var total: float = 0.0
	for convoy: Convoy in convoys:
		total += convoy.total_delivered.get(res, 0.0)
	return total


func get_total_fuel_burned() -> float:
	var total: float = 0.0
	for convoy: Convoy in convoys:
		total += convoy.total_fuel_burned
	return total


func _spawn_convoy(node_id: String, ctype: SimTypes.ConvoyType) -> Convoy:
	var convoy: Convoy = Convoy.new()
	convoy.id = "convoy_%02d" % _next_convoy_num
	convoy.callsign = "К-%02d" % _next_convoy_num
	_next_convoy_num += 1
	convoy.configure_for_type(
		ctype,
		config.convoy_fuel_tank,
		config.convoy_fuel_burn_per_km,
		config.convoy_load_ticks
	)
	convoy.current_node_id = node_id
	convoys.append(convoy)
	return convoy


func _clone_slots(src: Array[SimTypes.TrainSlotType]) -> Array[SimTypes.TrainSlotType]:
	var copy: Array[SimTypes.TrainSlotType] = []
	for s: SimTypes.TrainSlotType in src:
		copy.append(s)
	return copy


func _normalize_slots_size(slots: Array[SimTypes.TrainSlotType]) -> void:
	var target_slots: int = get_effective_train_slots()
	while slots.size() < target_slots:
		slots.append(SimTypes.TrainSlotType.AMMO)
	while slots.size() > target_slots:
		slots.pop_back()


func _check_phase_transition(elapsed_hour: int) -> void:
	if config.mission_mode == SimTypes.MissionMode.DEFENSE or config.phase2_start_hour <= 0:
		return
	if phase == SimTypes.OperationPhase.BUILDUP and elapsed_hour >= config.phase2_start_hour:
		phase = SimTypes.OperationPhase.OFFENSIVE
		phase1_readiness_achieved = get_buildup_readiness_ratio()
		var bonus_prog: float = 12.0 if phase1_readiness_achieved >= 0.85 else 0.0
		if bonus_prog > 0.0:
			for obj: SimTypes.MapNode in graph.get_nodes_by_type(SimTypes.NodeType.OBJECTIVE):
				obj.capture_progress = minf(99.0, obj.capture_progress + bonus_prog)
		_emit_event(
			SimTypes.EventSeverity.WARNING,
			"PHASE",
			"",
			"ФАЗА 2: НАСТУПЛЕНИЕ! Готовность резервов: %d%%." % int(round(phase1_readiness_achieved * 100.0)),
			Vector2.ZERO,
			SimTypes.AutoPauseTag.ASSAULT_STARTED
		)


func _apply_weather(elapsed_hour: int) -> void:
	for we: SimTypes.WeatherEntry in config.weather_schedule:
		if elapsed_hour >= we.start_hour and elapsed_hour < we.end_hour:
			if weather != we.weather or not weather_seen.has(we.weather):
				if weather != we.weather and current_tick > 0:
					var desc: String = "Погода прояснилась: ЯСНО — скорость на дорогах восстановлена."
					var sev: SimTypes.EventSeverity = SimTypes.EventSeverity.SUCCESS
					if we.weather == SimTypes.Weather.RAIN:
						desc = "Погода ухудшилась: ДОЖДЬ — скорость на грунтовках -35%, износ x2."
						sev = SimTypes.EventSeverity.WARNING
					elif we.weather == SimTypes.Weather.MUD:
						desc = "Погода ухудшилась: РАСПУТИЦА — скорость на грунтовках -55%, износ x2.2."
						sev = SimTypes.EventSeverity.WARNING
					_emit_event(sev, "WEATHER", "", desc)
				weather = we.weather
				weather_seen[weather] = true
			return


func _apply_wave_intensities(elapsed_hour: int) -> void:
	for w_idx: int in range(config.waves.size()):
		var wave: SimTypes.WaveEntry = config.waves[w_idx]
		if elapsed_hour >= wave.start_hour and elapsed_hour < wave.end_hour:
			for sec_id: String in wave.sector_intensities.keys():
				var node: SimTypes.MapNode = graph.get_node(sec_id)
				if node != null and node.node_type == SimTypes.NodeType.FRONT_SECTOR:
					var desired: SimTypes.Intensity = wave.sector_intensities[sec_id]
					var obj: SimTypes.MapNode = graph.get_node(node.target_objective_id)
					if obj != null and obj.owner == SimTypes.Owner.FRIENDLY:
						desired = SimTypes.Intensity.LOW
					if desired != node.intensity and current_tick > 0:
						if desired == SimTypes.Intensity.HIGH:
							var wave_tag: SimTypes.AutoPauseTag = SimTypes.AutoPauseTag.NONE
							if not _announced_high_waves.get(w_idx, false):
								_announced_high_waves[w_idx] = true
								wave_tag = SimTypes.AutoPauseTag.ASSAULT_STARTED
							_emit_event(
								SimTypes.EventSeverity.CRITICAL,
								"COMBAT",
								node.id,
								"%s: активность боёв повысилась до ВЫСОКОЙ (расход БК x2, растёт число раненых)." % node.display_name,
								node.position,
								wave_tag
							)
						elif desired == SimTypes.Intensity.MEDIUM and node.intensity == SimTypes.Intensity.LOW:
							_emit_event(
								SimTypes.EventSeverity.WARNING,
								"COMBAT",
								node.id,
								"%s: бои усилились до СРЕДНЕЙ интенсивности." % node.display_name,
								node.position
							)
					node.intensity = desired
			return


func _trigger_bridge_strikes(elapsed_hour: int) -> void:
	for i: int in range(config.bridge_strikes.size()):
		if _fired_bridge_strikes.get(i, false):
			continue
		var bs: SimTypes.BridgeStrikeEntry = config.bridge_strikes[i]
		if elapsed_hour >= bs.hour:
			_fired_bridge_strikes[i] = true
			var node: SimTypes.MapNode = graph.get_node(bs.node_id)
			if node != null and node.is_bridge and not node.damaged:
				node.damaged = true
				node.repair_progress_parts = 0.0
				bridges_damaged_count += 1
				_emit_event(
					SimTypes.EventSeverity.CRITICAL,
					"BRIDGE",
					node.id,
					"ПОВРЕЖДЁН МОСТ: %s! Направьте Инженерную колонну (%.0fт ЗП)." % [node.display_name, node.repair_cost_parts],
					node.position,
					SimTypes.AutoPauseTag.STRIKE_OR_DAMAGE
				)


func _trigger_scheduled_radiograms(elapsed_hour: int) -> void:
	for rad: SimTypes.Radiogram in config.scheduled_radiograms:
		if _fired_radiograms.get(rad.id, false):
			continue
		if elapsed_hour >= rad.hour:
			_fired_radiograms[rad.id] = true
			_push_radiogram(rad.id, rad.sender, rad.node_id, rad.text, rad.severity)


func _push_radiogram(rad_id: String, sender: String, node_id: String, text: String, sev: SimTypes.EventSeverity) -> void:
	var copy: SimTypes.Radiogram = SimTypes.Radiogram.new()
	copy.id = rad_id
	copy.tick = current_tick
	copy.hour = int(floor(get_elapsed_hours()))
	copy.sender = sender
	copy.node_id = node_id
	copy.text = text
	copy.severity = sev
	copy.dismissed = false
	radiograms.append(copy)
	var n: SimTypes.MapNode = graph.get_node(node_id)
	_emit_event(sev, "RADIO", node_id, "Р/г (%s): %s" % [sender, text], n.position if n != null else Vector2.ZERO)


func _step_railhead_deliveries() -> void:
	var interval_ticks: int = maxi(1, config.railhead_interval_hours * TICKS_PER_HOUR)
	if current_tick % interval_ticks != 0:
		return

	var railhead: SimTypes.MapNode = graph.get_node(inbound_train_target_id)
	if railhead == null:
		railhead = graph.get_node(config.default_train_target)
	if railhead == null:
		return

	var added_summary: Dictionary[SimTypes.ResourceType, float] = {
		SimTypes.ResourceType.FUEL: 0.0,
		SimTypes.ResourceType.AMMO: 0.0,
		SimTypes.ResourceType.PROVISIONS: 0.0,
		SimTypes.ResourceType.PARTS: 0.0,
		SimTypes.ResourceType.EQUIPMENT: 0.0,
	}
	var spawned_label: String = ""
	for slot: SimTypes.TrainSlotType in inbound_train_slots:
		match slot:
			SimTypes.TrainSlotType.FUEL:
				var af: float = config.slot_amounts.get(SimTypes.ResourceType.FUEL, 80.0)
				added_summary[SimTypes.ResourceType.FUEL] += railhead.add_stock(SimTypes.ResourceType.FUEL, af)
			SimTypes.TrainSlotType.AMMO:
				var aa: float = config.slot_amounts.get(SimTypes.ResourceType.AMMO, 95.0)
				added_summary[SimTypes.ResourceType.AMMO] += railhead.add_stock(SimTypes.ResourceType.AMMO, aa)
			SimTypes.TrainSlotType.PROVISIONS:
				var ap: float = config.slot_amounts.get(SimTypes.ResourceType.PROVISIONS, 60.0)
				added_summary[SimTypes.ResourceType.PROVISIONS] += railhead.add_stock(SimTypes.ResourceType.PROVISIONS, ap)
			SimTypes.TrainSlotType.PARTS:
				var az: float = config.slot_amounts.get(SimTypes.ResourceType.PARTS, 50.0)
				added_summary[SimTypes.ResourceType.PARTS] += railhead.add_stock(SimTypes.ResourceType.PARTS, az)
			SimTypes.TrainSlotType.EQUIPMENT_PLATFORM:
				added_summary[SimTypes.ResourceType.EQUIPMENT] += railhead.add_stock(SimTypes.ResourceType.EQUIPMENT, config.equipment_platform_amount)
			SimTypes.TrainSlotType.TRUCK_CARGO, SimTypes.TrainSlotType.TRUCK_TANKER, SimTypes.TrainSlotType.TRUCK_ENGINEER, SimTypes.TrainSlotType.TRUCK_ARMORED:
				var new_type: SimTypes.ConvoyType = SimTypes.ConvoyType.CARGO
				if slot == SimTypes.TrainSlotType.TRUCK_TANKER:
					new_type = SimTypes.ConvoyType.TANKER
				elif slot == SimTypes.TrainSlotType.TRUCK_ENGINEER:
					new_type = SimTypes.ConvoyType.ENGINEER
				elif slot == SimTypes.TrainSlotType.TRUCK_ARMORED:
					new_type = SimTypes.ConvoyType.ARMORED
				var nc: Convoy = _spawn_convoy(railhead.id, new_type)
				convoys_spawned_by_train += 1
				truck_order_cooldown_ticks = config.truck_order_cooldown_hours * TICKS_PER_HOUR
				spawned_label = " + %s (%s)" % [nc.callsign, SimTypes.convoy_type_label(new_type)]

	if railhead.is_vulnerable:
		railhead.had_traffic_this_tick = true
		var train_spike: float = (5.0 if is_night() else 10.0) * (0.5 if railhead.camouflaged else 1.0) * railhead.signature_mult * campaign_modifiers.depot_signature_growth_mult
		railhead.last_sig_traffic += train_spike
		railhead.signature = clampf(railhead.signature + train_spike, 0.0, 100.0)

	var eq_txt: String = ", Пер+%.0f" % added_summary[SimTypes.ResourceType.EQUIPMENT] if added_summary[SimTypes.ResourceType.EQUIPMENT] > 0.5 else ""
	trains_arrived += 1
	_emit_event(
		SimTypes.EventSeverity.SUCCESS,
		"RAILHEAD",
		railhead.id,
		"Эшелон на %s: Т+%.0f, БК+%.0f, Пр+%.0f, Зп+%.0f%sт%s." % [
			railhead.display_name,
			added_summary[SimTypes.ResourceType.FUEL],
			added_summary[SimTypes.ResourceType.AMMO],
			added_summary[SimTypes.ResourceType.PROVISIONS],
			added_summary[SimTypes.ResourceType.PARTS],
			eq_txt,
			spawned_label,
		],
		railhead.position,
		SimTypes.AutoPauseTag.TRAIN_ARRIVED
	)

	inbound_train_slots = _clone_slots(next_train_slots)
	inbound_train_target_id = next_train_target_id
	for i: int in range(next_train_slots.size()):
		if next_train_slots[i] in [SimTypes.TrainSlotType.TRUCK_CARGO, SimTypes.TrainSlotType.TRUCK_TANKER, SimTypes.TrainSlotType.TRUCK_ENGINEER, SimTypes.TrainSlotType.TRUCK_ARMORED]:
			next_train_slots[i] = SimTypes.TrainSlotType.PROVISIONS
		elif next_train_slots[i] == SimTypes.TrainSlotType.TRUCK_LOCKED:
			next_train_slots[i] = SimTypes.TrainSlotType.PARTS
		elif next_train_slots[i] == SimTypes.TrainSlotType.EQUIPMENT_PLATFORM:
			next_train_slots[i] = SimTypes.TrainSlotType.FUEL
		elif next_train_slots[i] == SimTypes.TrainSlotType.EQUIPMENT_LOCKED:
			next_train_slots[i] = SimTypes.TrainSlotType.AMMO


func _step_convoys() -> void:
	var night_now: bool = is_night()
	var base_traffic: float = 1.05 if night_now else 3.0
	var base_queue: float = 0.70 if night_now else 2.0
	var used_slots: Dictionary[String, int] = {}

	for convoy: Convoy in convoys:
		var can_use: bool = true
		if convoy.state == SimTypes.ConvoyState.LOADING or convoy.state == SimTypes.ConvoyState.UNLOADING:
			var n: SimTypes.MapNode = graph.get_node(convoy.current_node_id)
			if n != null and not convoy.is_waiting_night:
				var cur_used: int = used_slots.get(n.id, 0)
				if cur_used < n.loading_slots:
					used_slots[n.id] = cur_used + 1
					n.active_loading_count = cur_used + 1
				else:
					can_use = false

		var res: Dictionary = convoy.step_tick(graph, night_now, TICK_HOURS, weather, can_use)
		if bool(res.get("recovered_from_repair", false)):
			var rec_n: SimTypes.MapNode = graph.get_node(convoy.current_node_id)
			_emit_event(
				SimTypes.EventSeverity.SUCCESS,
				"REPAIR",
				convoy.current_node_id,
				"%s завершила капремонт и вернулась в строй." % convoy.callsign,
				rec_n.position if rec_n != null else Vector2.ZERO
			)

		var sig_convoy_mult: float = 0.40 if convoy.convoy_type == SimTypes.ConvoyType.ARMORED else 1.0
		var visited_vulns: Array[String] = res.get("visited_vulns", [])
		for vuln_id: String in visited_vulns:
			var vn: SimTypes.MapNode = graph.get_node(vuln_id)
			if vn != null:
				vn.had_traffic_this_tick = true
				var spike: float = base_traffic * sig_convoy_mult * (0.5 if vn.camouflaged else 1.0) * vn.signature_mult * campaign_modifiers.depot_signature_growth_mult
				vn.last_sig_traffic += spike
				vn.signature = clampf(vn.signature + spike, 0.0, 100.0)

		var queued_at: String = str(res.get("queued_at", ""))
		if not queued_at.is_empty():
			var qn: SimTypes.MapNode = graph.get_node(queued_at)
			if qn != null and qn.is_vulnerable:
				qn.had_traffic_this_tick = true
				var q_spike: float = base_queue * sig_convoy_mult * (0.5 if qn.camouflaged else 1.0) * qn.signature_mult * campaign_modifiers.depot_signature_growth_mult
				qn.last_sig_queue += q_spike
				qn.signature = clampf(qn.signature + q_spike, 0.0, 100.0)

		var demined_edges: Array[String] = res.get("demined_edges", [])
		for eid: String in demined_edges:
			roads_demined += 1
			var cn: SimTypes.MapNode = graph.get_node(convoy.current_node_id)
			_emit_event(
				SimTypes.EventSeverity.SUCCESS,
				"ENGINEER",
				convoy.current_node_id,
				"%s разминировал(а) трассу (%s)." % [convoy.callsign, eid],
				cn.position if cn != null else Vector2.ZERO
			)

		var danger_edges: Array[String] = res.get("traversed_danger_edges", [])
		if not danger_edges.is_empty() and not convoy.is_disabled():
			_resolve_convoy_interdiction(convoy, danger_edges, night_now)


func _resolve_convoy_interdiction(convoy: Convoy, danger_edges: Array[String], night_now: bool) -> void:
	if config.frontline_interdiction_mult <= 0.0:
		return
	var max_inten: SimTypes.Intensity = SimTypes.Intensity.LOW
	var hit_edge: SimTypes.RoadEdge = null
	for eid: String in danger_edges:
		for e: SimTypes.RoadEdge in graph.edges:
			if e.id == eid and e.frontline_danger:
				var e_inten: SimTypes.Intensity = _get_edge_combat_intensity(e)
				if int(e_inten) > int(max_inten):
					max_inten = e_inten
					hit_edge = e
	if max_inten == SimTypes.Intensity.LOW or hit_edge == null:
		return

	var chance: float = (0.045 if max_inten == SimTypes.Intensity.MEDIUM else 0.105) * config.frontline_interdiction_mult
	if night_now:
		chance *= 0.30
	if convoy.convoy_type == SimTypes.ConvoyType.ARMORED:
		chance *= 0.50
	if _rng.randf() >= chance:
		return

	var dmg: float = _rng.randf_range(25.0, 45.0)
	var cargo_loss: float = _rng.randf_range(0.20, 0.30)
	if convoy.convoy_type == SimTypes.ConvoyType.ARMORED:
		dmg = _rng.randf_range(2.5, 4.5)
		cargo_loss = 0.0
	var hit_res: Dictionary = convoy.apply_artillery_hit(dmg, cargo_loss)
	convoys_damaged_hits += 1
	var mid_p: Vector2 = graph.get_edge_midpoint(hit_edge)

	if convoy.hp <= 0.01:
		convoys_disabled_count += 1
		convoy.disabled_ticks_remaining = 96
		convoy.state = SimTypes.ConvoyState.IDLE
		convoy.route_nodes.clear()
		convoy.route_segment_index = 0
		convoy.segment_progress_km = 0.0
		convoy.carried_wounded = 0.0
		for r: SimTypes.ResourceType in SimTypes.all_resources():
			convoy.cargo[r] = 0.0
		convoy.current_node_id = config.default_train_target
		_emit_event(
			SimTypes.EventSeverity.CRITICAL,
			"INTERDICTION",
			config.default_train_target,
			"ВЫБЫЛА КОЛОННА %s под артобстрелом! Эвакуирована в глубокий ремонт (16 ч)." % convoy.callsign,
			mid_p,
			SimTypes.AutoPauseTag.STRIKE_OR_DAMAGE
		)
	else:
		var sev: SimTypes.EventSeverity = SimTypes.EventSeverity.INFO if convoy.convoy_type == SimTypes.ConvoyType.ARMORED else SimTypes.EventSeverity.WARNING
		var ap_tag: SimTypes.AutoPauseTag = SimTypes.AutoPauseTag.NONE if convoy.convoy_type == SimTypes.ConvoyType.ARMORED else SimTypes.AutoPauseTag.STRIKE_OR_DAMAGE
		var lost_t: float = float(hit_res.get("cargo_lost", 0.0))
		_emit_event(
			sev,
			"INTERDICTION",
			hit_edge.to_id,
			"%s (%s) попала под обстрел на передовой: прочность %.0f%% (-%.0f HP%s)." % [
				convoy.callsign,
				SimTypes.convoy_type_label(convoy.convoy_type),
				convoy.hp,
				float(hit_res.get("hp_lost", dmg)),
				", потеря груза %.1fт" % lost_t if lost_t > 0.1 else "",
			],
			mid_p,
			ap_tag
		)


func _get_edge_combat_intensity(edge: SimTypes.RoadEdge) -> SimTypes.Intensity:
	var best: SimTypes.Intensity = SimTypes.Intensity.LOW
	for nid: String in [edge.from_id, edge.to_id]:
		var n: SimTypes.MapNode = graph.get_node(nid)
		if n != null and n.node_type == SimTypes.NodeType.FRONT_SECTOR:
			if int(n.intensity) > int(best):
				best = n.intensity
	return best


func _update_frontline_danger() -> void:
	if graph == null:
		return
	for edge: SimTypes.RoadEdge in graph.edges:
		var na: SimTypes.MapNode = graph.get_node(edge.from_id)
		var nb: SimTypes.MapNode = graph.get_node(edge.to_id)
		var has_active_front: bool = false
		for n: SimTypes.MapNode in [na, nb]:
			if n != null and n.node_type == SimTypes.NodeType.FRONT_SECTOR:
				var obj: SimTypes.MapNode = graph.get_node(n.target_objective_id)
				if obj == null or obj.owner != SimTypes.Owner.FRIENDLY:
					has_active_front = true
		if has_active_front and (edge.base_frontline_danger or config.frontline_interdiction_mult > 0.0):
			edge.frontline_danger = true
		else:
			edge.frontline_danger = false


func _step_field_depots() -> void:
	for node: SimTypes.MapNode in graph.get_all_nodes():
		if node.can_deploy_depot and node.node_type == SimTypes.NodeType.JUNCTION:
			if node.deploy_build_ticks_remaining > 0:
				node.deploy_build_ticks_remaining -= 1
				if node.deploy_build_ticks_remaining == 0:
					node.node_type = SimTypes.NodeType.FIELD_DEPOT
					node.is_vulnerable = true
					node.signature_mult = 0.75
					node.loading_slots = 2
					node.signature = 5.0
					node.deploy_progress_parts = 0.0
					node.deploy_requested = false
					node.capacity[SimTypes.ResourceType.FUEL] = 180.0
					node.capacity[SimTypes.ResourceType.AMMO] = 180.0
					node.capacity[SimTypes.ResourceType.PROVISIONS] = 120.0
					node.capacity[SimTypes.ResourceType.PARTS] = 120.0
					node.capacity[SimTypes.ResourceType.EQUIPMENT] = 60.0
					field_depots_deployed += 1
					_emit_event(
						SimTypes.EventSeverity.SUCCESS,
						"DEPOT",
						node.id,
						"Полевой склад «%s» развёрнут и готов к приёму грузов (180т/ресурс, -25%% сигнатуры)." % node.display_name,
						node.position
					)
			elif node.deploy_progress_parts >= node.deploy_cost_parts - 0.01:
				node.deploy_build_ticks_remaining = node.deploy_build_ticks_total
				_emit_event(
					SimTypes.EventSeverity.INFO,
					"DEPOT",
					node.id,
					"%s: доставлено 25т ЗП — начато развёртывание склада (4 ч)." % node.display_name,
					node.position
				)
		elif node.node_type == SimTypes.NodeType.FIELD_DEPOT and node.pack_ticks_remaining > 0:
			node.pack_ticks_remaining -= 1
			if node.pack_ticks_remaining == 0:
				for res: SimTypes.ResourceType in SimTypes.all_resources():
					node.stock[res] = 0.0
					node.capacity[res] = 0.0
				node.node_type = SimTypes.NodeType.JUNCTION
				node.is_vulnerable = false
				node.signature = 0.0
				node.signature_mult = 1.0
				node.loading_slots = 99
				node.camouflaged = false
				node.can_deploy_depot = true
				node.deploy_progress_parts = 0.0
				node.deploy_requested = false
				field_depots_packed += 1
				var rh: SimTypes.MapNode = graph.get_node(config.default_train_target)
				if rh != null:
					rh.add_stock(SimTypes.ResourceType.PARTS, 10.0)
				_emit_event(
					SimTypes.EventSeverity.INFO,
					"DEPOT",
					node.id,
					"Полевой склад %s свёрнут; часть запчастей (+10т ЗП) возвращена на ж/д станцию." % node.display_name,
					node.position
				)


func _step_reequipment() -> void:
	for node: SimTypes.MapNode in graph.get_all_nodes():
		if node.node_type != SimTypes.NodeType.FRONT_SECTOR and node.node_type != SimTypes.NodeType.ARTILLERY:
			continue
		if node.equipment_tier >= 2:
			continue
		if node.reequip_ticks_remaining > 0:
			node.reequip_ticks_remaining -= 1
			if node.reequip_ticks_remaining == 0:
				node.equipment_tier = 2
				node.reequip_progress = node.reequip_cost
				units_modernized += 1
				_emit_event(
					SimTypes.EventSeverity.SUCCESS,
					"EQUIPMENT",
					node.id,
					"ПЕРЕВООРУЖЕНИЕ ЗАВЕРШЕНО: %s перешёл на Уровень II (+35%% боевой эфф., -20%% расход БК)." % node.display_name,
					node.position
				)
		elif node.reequip_progress >= node.reequip_cost - 0.01:
			node.reequip_ticks_remaining = node.reequip_ticks_total
			_emit_event(
				SimTypes.EventSeverity.INFO,
				"EQUIPMENT",
				node.id,
				"%s: получено 30т комплектов — переформирование на Уровень II (3 ч)." % node.display_name,
				node.position
			)


func _check_bridge_repairs() -> void:
	for node: SimTypes.MapNode in graph.get_all_nodes():
		if node.is_bridge and node.damaged and node.repair_progress_parts >= node.repair_cost_parts - 0.01:
			node.damaged = false
			node.repair_progress_parts = 0.0
			bridges_repaired += 1
			_push_radiogram(
				"dyn_bridge_%s_%d" % [node.id, current_tick],
				"Инженерная служба",
				node.id,
				"%s восстановлен! Движение по переправе полностью открыто." % node.display_name,
				SimTypes.EventSeverity.SUCCESS
			)


func _step_road_wear_warnings() -> void:
	for edge: SimTypes.RoadEdge in graph.edges:
		if edge.wear >= 0.65 and not edge.heavy_wear_warned:
			edge.heavy_wear_warned = true
			var na: SimTypes.MapNode = graph.get_node(edge.from_id)
			var nb: SimTypes.MapNode = graph.get_node(edge.to_id)
			var n1: String = na.display_name if na != null else edge.from_id
			var n2: String = nb.display_name if nb != null else edge.to_id
			_emit_event(
				SimTypes.EventSeverity.WARNING,
				"ROAD",
				edge.from_id,
				"Дорога %s — %s сильно разбита (износ %.0f%%), скорость колонн упала." % [n1, n2, edge.wear * 100.0],
				graph.get_edge_midpoint(edge)
			)
		elif edge.wear < 0.45:
			edge.heavy_wear_warned = false


func _step_depots_and_recon() -> void:
	var recon_interval_ticks: int = maxi(1, config.recon_interval_hours * TICKS_PER_HOUR)
	var is_recon_window: bool = (current_tick % recon_interval_ticks == 0)
	var night_now: bool = is_night()

	var max_sig: float = 0.0
	var max_sig_name: String = ""
	var max_sig_node_id: String = ""
	var max_sig_pos: Vector2 = Vector2.ZERO
	var any_recon_hit: bool = false

	for node: SimTypes.MapNode in graph.get_all_nodes():
		if not node.is_vulnerable:
			continue

		var total_cap: float = maxf(1.0, node.get_total_capacity())
		var fill_ratio: float = node.get_total_stock() / total_cap
		var growth: float = fill_ratio * 0.14 if fill_ratio <= 0.75 else (0.75 * 0.14 + (fill_ratio - 0.75) * 0.85)
		if night_now:
			growth *= 0.50
		if node.camouflaged:
			growth *= 0.50
		growth *= node.signature_mult * campaign_modifiers.depot_signature_growth_mult
		node.last_sig_storage = growth
		node.signature += growth

		# Idle convoy penalty only when > 4 idle convoys pile up at a depot
		var idle_here: int = get_idle_convoys_at(node.id).size()
		if idle_here > 4:
			var idle_pen: float = float(idle_here - 4) * 0.08 * (0.5 if node.camouflaged else 1.0) * node.signature_mult * campaign_modifiers.depot_signature_growth_mult
			node.last_sig_idle = idle_pen
			node.signature += idle_pen

		if not node.had_traffic_this_tick:
			var decay: float = 0.48 if node.camouflaged else 0.24
			node.last_sig_decay = -decay
			node.signature -= decay

		node.signature = clampf(node.signature, 0.0, 100.0)

		if node.signature > peak_depot_signature:
			peak_depot_signature = node.signature
		if node.signature >= max_sig:
			max_sig = node.signature
			max_sig_name = node.display_name
			max_sig_node_id = node.id
			max_sig_pos = node.position

		if node.signature >= 65.0 and not node.high_signature_warned:
			node.high_signature_warned = true
			_emit_event(
				SimTypes.EventSeverity.WARNING,
				"SIGNATURE",
				node.id,
				"Высокая заметность: %s (сигнатура %.0f%%) — включите маскировку или снизьте трафик!" % [node.display_name, node.signature],
				node.position
			)
		elif node.signature < 50.0:
			node.high_signature_warned = false

		if is_recon_window and node.signature >= 75.0 and node.pending_strike_ticks < 0:
			any_recon_hit = true
			node.pending_strike_ticks = _rng.randi_range(6, 12)
			_emit_event(
				SimTypes.EventSeverity.CRITICAL,
				"RECON",
				node.id,
				"Пролёт разведки: вскрыт %s (сигнатура %.0f%%)! Удар ожидается через 1–2 ч!" % [node.display_name, node.signature],
				node.position
			)

		if node.pending_strike_ticks > 0:
			node.pending_strike_ticks -= 1
			if node.pending_strike_ticks == 0:
				_execute_vuln_strike(node)

	if is_recon_window and not any_recon_hit and not max_sig_name.is_empty():
		_emit_event(
			SimTypes.EventSeverity.SUCCESS,
			"RECON",
			max_sig_node_id,
			"Пролёт разведки противника: склады в безопасности (макс. сигнатура %.0f%% на %s)." % [max_sig, max_sig_name],
			max_sig_pos
		)


func _execute_vuln_strike(node: SimTypes.MapNode) -> void:
	var loss_ratio: float = _rng.randf_range(0.50, 0.70)
	var lost_fuel: float = node.get_stock(SimTypes.ResourceType.FUEL) * loss_ratio
	var lost_ammo: float = node.get_stock(SimTypes.ResourceType.AMMO) * loss_ratio
	node.take_stock(SimTypes.ResourceType.FUEL, lost_fuel)
	node.take_stock(SimTypes.ResourceType.AMMO, lost_ammo)
	node.take_stock(SimTypes.ResourceType.PROVISIONS, node.get_stock(SimTypes.ResourceType.PROVISIONS) * loss_ratio)
	node.take_stock(SimTypes.ResourceType.PARTS, node.get_stock(SimTypes.ResourceType.PARTS) * loss_ratio)
	node.signature = 15.0
	node.high_signature_warned = false
	node.pending_strike_ticks = -1
	strikes_triggered += 1
	_emit_event(
		SimTypes.EventSeverity.CRITICAL,
		"STRIKE",
		node.id,
		"РАКЕТНЫЙ УДАР по %s! Потеряно %.0fт ГСМ и %.0fт БК." % [node.display_name, lost_fuel, lost_ammo],
		node.position,
		SimTypes.AutoPauseTag.STRIKE_OR_DAMAGE
	)


func _step_artillery() -> void:
	var flank_max_combat: Dictionary[String, SimTypes.Intensity] = {
		"NORTH": SimTypes.Intensity.LOW,
		"SOUTH": SimTypes.Intensity.LOW,
		"ALL": SimTypes.Intensity.LOW,
	}
	for sector: SimTypes.MapNode in graph.get_nodes_by_type(SimTypes.NodeType.FRONT_SECTOR):
		var fl: String = sector.flank if not sector.flank.is_empty() else "NORTH"
		var cur: SimTypes.Intensity = flank_max_combat.get(fl, SimTypes.Intensity.LOW)
		if int(sector.intensity) > int(cur):
			flank_max_combat[fl] = sector.intensity
		if int(sector.intensity) > int(flank_max_combat["ALL"]):
			flank_max_combat["ALL"] = sector.intensity

	for fl_key: String in ["NORTH", "SOUTH", "ALL"]:
		arty_support_by_flank[fl_key] = false

	var any_active: bool = false
	for arty: SimTypes.MapNode in graph.get_nodes_by_type(SimTypes.NodeType.ARTILLERY):
		var fl: String = arty.flank if not arty.flank.is_empty() else "NORTH"
		var max_c: SimTypes.Intensity = flank_max_combat.get(fl, SimTypes.Intensity.LOW)
		if max_c == SimTypes.Intensity.LOW:
			continue

		var ammo_need: float = 0.45 if max_c == SimTypes.Intensity.HIGH else 0.22
		if arty.equipment_tier >= 2:
			ammo_need *= 0.80
		var fuel_need: float = 0.06
		arty.take_stock(SimTypes.ResourceType.FUEL, fuel_need)
		var ammo_taken: float = arty.take_stock(SimTypes.ResourceType.AMMO, ammo_need)
		if ammo_taken >= ammo_need * 0.95:
			arty_support_by_flank[fl] = true
			any_active = true
			_arty_out_warned[arty.id] = false
		elif not _arty_out_warned.get(arty.id, false):
			_arty_out_warned[arty.id] = true
			var fl_title: String = "всей полосы" if fl == "ALL" else ("Север" if fl == "NORTH" else "Юг")
			_push_radiogram(
				"dyn_arty_dry_%s_%d" % [arty.id, current_tick],
				arty.display_name,
				arty.id,
				"Закончились снаряды! Батареи (%s) замолчали!" % fl_title,
				SimTypes.EventSeverity.CRITICAL
			)

	if any_active:
		arty_support_ticks += 1


func _step_front_sectors() -> void:
	_sector_supplied_this_tick.clear()
	var buildup_scale: float = 0.85 if (config.mission_mode == SimTypes.MissionMode.OFFENSIVE and phase == SimTypes.OperationPhase.BUILDUP) else 1.0

	for sector: SimTypes.MapNode in graph.get_nodes_by_type(SimTypes.NodeType.FRONT_SECTOR):
		var ammo_need: float = 0.18
		var fuel_need: float = 0.10
		var prov_need: float = 0.06
		var prev_wounded: float = sector.wounded
		var tier_mult: float = 0.80 if sector.equipment_tier >= 2 else 1.0
		match sector.intensity:
			SimTypes.Intensity.LOW:
				ammo_need = 0.18
				fuel_need = 0.10
				prov_need = 0.06
			SimTypes.Intensity.MEDIUM:
				ammo_need = 0.40
				fuel_need = 0.22
				prov_need = 0.11
				sector.wounded = minf(45.0, sector.wounded + 0.15 * tier_mult)
			SimTypes.Intensity.HIGH:
				ammo_need = 0.72
				fuel_need = 0.36
				prov_need = 0.16
				sector.wounded = minf(45.0, sector.wounded + 0.32 * tier_mult)

		if sector.wounded > prev_wounded:
			total_wounded_generated += (sector.wounded - prev_wounded)

		ammo_need *= buildup_scale * tier_mult
		fuel_need *= buildup_scale
		prov_need *= buildup_scale

		var fuel_taken: float = sector.take_stock(SimTypes.ResourceType.FUEL, fuel_need)
		var has_fuel: bool = fuel_taken >= fuel_need * 0.99
		if not has_fuel:
			ammo_need *= 1.35

		var ammo_taken: float = sector.take_stock(SimTypes.ResourceType.AMMO, ammo_need)
		var has_ammo: bool = ammo_taken >= ammo_need * 0.99

		var prov_taken: float = sector.take_stock(SimTypes.ResourceType.PROVISIONS, prov_need)
		var has_prov: bool = prov_taken >= prov_need * 0.99
		if sector.intensity == SimTypes.Intensity.LOW and has_prov and sector.wounded > 0.0:
			sector.wounded = maxf(0.0, sector.wounded - 0.05)

		_sector_supplied_this_tick[sector.id] = (has_ammo and has_fuel and has_prov)

		var delta_integrity: float = 0.0
		if has_ammo and has_fuel and has_prov:
			delta_integrity = 0.10
			if sector.integrity < 99.5 and sector.take_stock(SimTypes.ResourceType.PARTS, 0.15) >= 0.14:
				delta_integrity += 0.15
		else:
			if not has_ammo:
				delta_integrity -= 1.05
			if not has_fuel:
				delta_integrity -= 0.38
			if not has_prov:
				delta_integrity -= 0.28

		if sector.wounded >= 24.0:
			delta_integrity -= 0.18

		if sector.equipment_tier >= 2:
			if delta_integrity < 0.0:
				delta_integrity *= 0.75
			else:
				delta_integrity *= 1.35

		var fl: String = sector.flank if not sector.flank.is_empty() else "NORTH"
		if arty_support_by_flank.get(fl, false) or arty_support_by_flank.get("ALL", false):
			if delta_integrity < 0.0:
				delta_integrity *= 0.60
			else:
				delta_integrity += 0.10

		sector.integrity = clampf(sector.integrity + delta_integrity, 0.0, 100.0)
		if sector.integrity < min_sector_integrity_seen:
			min_sector_integrity_seen = sector.integrity

		if not has_ammo and not sector.ammo_empty_warned:
			sector.ammo_empty_warned = true
			_emit_event(SimTypes.EventSeverity.CRITICAL, "FRONT", sector.id, "Дефицит БК: %s! Целостность %.0f%%." % [sector.display_name, sector.integrity], sector.position)
		elif sector.get_stock(SimTypes.ResourceType.AMMO) >= 5.0:
			sector.ammo_empty_warned = false

		if not has_fuel and not sector.fuel_empty_warned:
			sector.fuel_empty_warned = true
			_emit_event(SimTypes.EventSeverity.CRITICAL, "FRONT", sector.id, "Дефицит ГСМ: %s!" % sector.display_name, sector.position)
		elif sector.get_stock(SimTypes.ResourceType.FUEL) >= 5.0:
			sector.fuel_empty_warned = false

		if not has_prov and not sector.provisions_empty_warned:
			sector.provisions_empty_warned = true
			_emit_event(SimTypes.EventSeverity.WARNING, "FRONT", sector.id, "Закончилась провизия: %s!" % sector.display_name, sector.position)
		elif sector.get_stock(SimTypes.ResourceType.PROVISIONS) >= 5.0:
			sector.provisions_empty_warned = false

		if sector.wounded >= 24.0 and not sector.wounded_warned:
			sector.wounded_warned = true
			_emit_event(SimTypes.EventSeverity.WARNING, "MEDEVAC", sector.id, "Перегружен медпункт (%s: %.0f ран.)." % [sector.display_name, sector.wounded], sector.position)
		elif sector.wounded < 12.0:
			sector.wounded_warned = false


func _step_objectives() -> void:
	if phase != SimTypes.OperationPhase.OFFENSIVE:
		return

	var front_sectors: Array[SimTypes.MapNode] = graph.get_nodes_by_type(SimTypes.NodeType.FRONT_SECTOR)
	for obj: SimTypes.MapNode in graph.get_nodes_by_type(SimTypes.NodeType.OBJECTIVE):
		if obj.owner == SimTypes.Owner.FRIENDLY:
			continue

		var obj_delta: float = 0.0
		for sec: SimTypes.MapNode in front_sectors:
			if sec.target_objective_id != obj.id:
				continue
			var supplied: bool = _sector_supplied_this_tick.get(sec.id, false)
			if supplied and sec.integrity >= 45.0 and sec.wounded < 25.0:
				var fl: String = sec.flank if not sec.flank.is_empty() else "NORTH"
				var push: float = 0.25 if (arty_support_by_flank.get(fl, false) or arty_support_by_flank.get("ALL", false)) else 0.18
				if sec.equipment_tier >= 2:
					push *= 1.35
				obj_delta += push
			else:
				obj_delta -= 0.10

		if obj_delta > 0.0 and obj.fortified_resistance > 1.0:
			obj_delta /= obj.fortified_resistance

		obj.capture_progress = clampf(obj.capture_progress + obj_delta, 0.0, 100.0)
		if obj.capture_progress >= 100.0:
			obj.owner = SimTypes.Owner.FRIENDLY
			objectives_captured += 1
			_update_frontline_danger()
			for sec: SimTypes.MapNode in front_sectors:
				if sec.target_objective_id == obj.id:
					sec.intensity = SimTypes.Intensity.LOW
			_push_radiogram(
				"dyn_cap_%s_%d" % [obj.id, current_tick],
				"Штаб 2-й ОГ",
				obj.id,
				"ПРОРЫВ! %s взят под наш контроль! Направьте туда Инженерную колонну для разминирования подъездов." % obj.display_name,
				SimTypes.EventSeverity.SUCCESS
			)


func _evaluate_win_loss() -> void:
	for sector: SimTypes.MapNode in graph.get_nodes_by_type(SimTypes.NodeType.FRONT_SECTOR):
		if sector.integrity <= 0.0:
			result = SimTypes.GameResult.DEFEAT
			result_reason = "Оборона прорвана: %s (целостность 0%%)" % sector.display_name
			_emit_event(SimTypes.EventSeverity.CRITICAL, "RESULT", sector.id, result_reason, sector.position)
			return

	var target_ticks: int = config.duration_hours * TICKS_PER_HOUR
	var all_objectives: Array[SimTypes.MapNode] = graph.get_nodes_by_type(SimTypes.NodeType.OBJECTIVE)
	var total_objs: int = all_objectives.size()
	if config.mission_mode == SimTypes.MissionMode.DEFENSE or total_objs == 0:
		if current_tick >= target_ticks:
			result = SimTypes.GameResult.VICTORY
			result_reason = "Оборона удержана в течение %d ч! Все батальоны сохранили боеспособность." % config.duration_hours
			_emit_event(SimTypes.EventSeverity.SUCCESS, "RESULT", "", result_reason)
		return

	if total_objs > 0 and objectives_captured >= total_objs:
		if units_modernized >= config.required_modernized_units:
			result = SimTypes.GameResult.VICTORY
			result_reason = "Все %d целевых узла захвачены за %.1f ч! Разминировано дорог: %d." % [
				total_objs,
				get_elapsed_hours(),
				roads_demined,
			]
			_emit_event(SimTypes.EventSeverity.SUCCESS, "RESULT", "", result_reason)
			return
		elif not _need_modernize_warned:
			_need_modernize_warned = true
			_emit_event(
				SimTypes.EventSeverity.WARNING,
				"EQUIPMENT",
				"",
				"Все цели захвачены, но требуется перевооружить ещё подразделения до Уровня II (%d/%d)!" % [units_modernized, config.required_modernized_units]
			)

	if current_tick >= target_ticks:
		result = SimTypes.GameResult.DEFEAT
		result_reason = "Операция не завершена в срок (%d ч): захвачено %d/%d узлов, перевооружено %d/%d." % [
			config.duration_hours,
			objectives_captured,
			total_objs,
			units_modernized,
			config.required_modernized_units,
		]
		_emit_event(SimTypes.EventSeverity.CRITICAL, "RESULT", "", result_reason)


func get_operation_stats() -> SimTypes.SimStats:
	var stats: SimTypes.SimStats = SimTypes.SimStats.new()
	stats.elapsed_hours = get_elapsed_hours()
	var total_deliv: float = 0.0
	for res: SimTypes.ResourceType in SimTypes.all_resources():
		var amt: float = get_total_delivered(res)
		stats.delivered_by_resource[res] = amt
		total_deliv += amt
	stats.total_delivered_tons = total_deliv
	stats.wounded_evacuated = get_total_wounded_evacuated()
	stats.wounded_remaining = get_total_wounded()
	stats.wounded_generated = maxf(total_wounded_generated, stats.wounded_evacuated + stats.wounded_remaining)
	var denom: float = stats.wounded_evacuated + stats.wounded_remaining
	stats.wounded_evac_ratio = (stats.wounded_evacuated / denom) if denom > 0.01 else 1.0
	stats.depot_strikes = strikes_triggered
	stats.bridges_damaged = bridges_damaged_count
	stats.bridges_repaired = bridges_repaired
	stats.roads_demined = roads_demined
	stats.objectives_captured = objectives_captured
	stats.objectives_total = graph.get_nodes_by_type(SimTypes.NodeType.OBJECTIVE).size() if graph != null else 0
	stats.min_sector_integrity = min_sector_integrity_seen
	stats.peak_depot_signature = peak_depot_signature
	stats.trains_arrived = trains_arrived
	stats.field_depots_deployed = field_depots_deployed
	stats.field_depots_packed = field_depots_packed
	stats.units_modernized = units_modernized
	stats.convoys_damaged_hits = convoys_damaged_hits
	stats.convoys_disabled_count = convoys_disabled_count
	return stats


func evaluate_secondary_objectives() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if config == null:
		return results
	var stats: SimTypes.SimStats = get_operation_stats()
	for spec: SimTypes.SecondaryObjectiveSpec in config.secondary_objectives:
		var cond_met: bool = false
		var prog_txt: String = ""
		match spec.metric:
			"NO_DEPOT_STRIKES":
				cond_met = (stats.depot_strikes <= int(round(spec.target_value)))
				prog_txt = "Ударов по складам: %d" % stats.depot_strikes
			"WOUNDED_EVAC_RATIO":
				cond_met = (stats.wounded_evac_ratio >= spec.target_value)
				prog_txt = "Вывезено: %d%% (цель %d%%)" % [int(round(stats.wounded_evac_ratio * 100.0)), int(round(spec.target_value * 100.0))]
			"VICTORY_UNDER_HOURS":
				cond_met = (result == SimTypes.GameResult.VICTORY and stats.elapsed_hours <= spec.target_value)
				prog_txt = "Время: %.1f / %.0f ч" % [stats.elapsed_hours, spec.target_value]
			"MIN_SECTOR_INTEGRITY":
				cond_met = (stats.min_sector_integrity >= spec.target_value)
				prog_txt = "Мин. целостность: %.0f%% (порог %.0f%%)" % [stats.min_sector_integrity, spec.target_value]
			"FIELD_DEPOTS_DEPLOYED":
				cond_met = (stats.field_depots_deployed >= int(round(spec.target_value)))
				prog_txt = "Развёрнуто складов: %d (цель %.0f)" % [stats.field_depots_deployed, spec.target_value]
			"ZERO_CONVOY_LOSSES":
				cond_met = (stats.convoys_disabled_count <= int(round(spec.target_value)))
				prog_txt = "Выбыло колонн: %d" % stats.convoys_disabled_count
			"UNITS_MODERNIZED":
				cond_met = (stats.units_modernized >= int(round(spec.target_value)))
				prog_txt = "Перевооружено: %d (цель %.0f)" % [stats.units_modernized, spec.target_value]
			_:
				cond_met = false
				prog_txt = ""

		results.append({
			"id": spec.id,
			"title": spec.title,
			"description": spec.description,
			"bonus_cp": spec.bonus_cp,
			"condition_met": cond_met,
			"completed": (result == SimTypes.GameResult.VICTORY and cond_met),
			"progress_text": prog_txt,
		})
	return results


func _emit_event(
	severity: SimTypes.EventSeverity,
	category: String,
	node_id: String,
	message: String,
	world_pos: Vector2 = Vector2.ZERO,
	autopause_tag: SimTypes.AutoPauseTag = SimTypes.AutoPauseTag.NONE
) -> void:
	var ev: SimTypes.SimEvent = SimTypes.SimEvent.new()
	ev.tick = current_tick
	ev.day = get_day()
	ev.hour = get_hour()
	ev.minute = get_minute()
	ev.severity = severity
	ev.category = category
	ev.autopause_tag = autopause_tag
	ev.node_id = node_id
	if world_pos != Vector2.ZERO:
		ev.world_pos = world_pos
		ev.has_world_pos = true
	elif not node_id.is_empty() and graph != null:
		var n: SimTypes.MapNode = graph.get_node(node_id)
		if n != null:
			ev.world_pos = n.position
			ev.has_world_pos = true
	ev.message = message
	event_log.append(ev)
	if autopause_tag != SimTypes.AutoPauseTag.NONE and not last_tick_autopause_tags.has(autopause_tag):
		last_tick_autopause_tags.append(autopause_tag)
