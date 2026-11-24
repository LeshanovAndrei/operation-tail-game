class_name SimTypes
extends RefCounted

enum NodeType {
	RAILHEAD,
	DEPOT,
	FIELD_DEPOT,
	JUNCTION,
	ARTILLERY,
	FRONT_SECTOR,
	OBJECTIVE,
}

enum Owner {
	FRIENDLY,
	ENEMY,
}

enum RoadType {
	HIGHWAY,
	SECONDARY,
	DIRT,
}

enum ResourceType {
	FUEL,
	AMMO,
	PROVISIONS,
	PARTS,
	EQUIPMENT,
}

enum CargoPreference {
	MIXED,
	FUEL,
	AMMO,
	PROVISIONS,
	PARTS,
	EQUIPMENT,
	EMPTY,
}

enum ConvoyType {
	CARGO,
	TANKER,
	ENGINEER,
	ARMORED,
}

enum OrderMode {
	ONE_WAY_RETURN,
	REDEPLOY,
	LOOP,
}

enum OperationPhase {
	BUILDUP,
	OFFENSIVE,
}

enum TrainSlotType {
	FUEL,
	AMMO,
	PROVISIONS,
	PARTS,
	TRUCK_CARGO,
	TRUCK_TANKER,
	TRUCK_ENGINEER,
	TRUCK_ARMORED,
	TRUCK_LOCKED,
	EQUIPMENT_PLATFORM,
	EQUIPMENT_LOCKED,
}

enum Weather {
	CLEAR,
	RAIN,
	MUD,
}

enum Intensity {
	LOW,
	MEDIUM,
	HIGH,
}

enum ConvoyState {
	IDLE,
	LOADING,
	MOVING,
	UNLOADING,
}

enum GameResult {
	RUNNING,
	VICTORY,
	DEFEAT,
}

enum EventSeverity {
	INFO,
	SUCCESS,
	WARNING,
	CRITICAL,
}

enum MissionMode {
	DEFENSE,
	OFFENSIVE,
}

enum AutoPauseTag {
	NONE,
	TRAIN_ARRIVED,
	ASSAULT_STARTED,
	STRIKE_OR_DAMAGE,
}


static func base_resources() -> Array[ResourceType]:
	return [
		ResourceType.FUEL,
		ResourceType.AMMO,
		ResourceType.PROVISIONS,
		ResourceType.PARTS,
	]


static func all_resources() -> Array[ResourceType]:
	return [
		ResourceType.FUEL,
		ResourceType.AMMO,
		ResourceType.PROVISIONS,
		ResourceType.PARTS,
		ResourceType.EQUIPMENT,
	]


static func node_type_from_string(value: String) -> NodeType:
	match value.to_upper():
		"RAILHEAD":
			return NodeType.RAILHEAD
		"DEPOT":
			return NodeType.DEPOT
		"FIELD_DEPOT":
			return NodeType.FIELD_DEPOT
		"JUNCTION":
			return NodeType.JUNCTION
		"ARTILLERY":
			return NodeType.ARTILLERY
		"FRONT_SECTOR":
			return NodeType.FRONT_SECTOR
		"OBJECTIVE":
			return NodeType.OBJECTIVE
		_:
			return NodeType.JUNCTION


static func node_type_label(t: NodeType) -> String:
	match t:
		NodeType.RAILHEAD:
			return "Ж/Д станция"
		NodeType.DEPOT:
			return "Полевой склад"
		NodeType.FIELD_DEPOT:
			return "Полевой склад (разв.)"
		NodeType.JUNCTION:
			return "Дорожный узел / Переправа"
		NodeType.ARTILLERY:
			return "Артдивизион"
		NodeType.FRONT_SECTOR:
			return "Участок фронта"
		NodeType.OBJECTIVE:
			return "Целевой узел"
	return "Узел"


static func owner_from_string(value: String) -> Owner:
	if value.to_upper() == "ENEMY":
		return Owner.ENEMY
	return Owner.FRIENDLY


static func convoy_type_from_string(value: String) -> ConvoyType:
	match value.to_upper():
		"TANKER":
			return ConvoyType.TANKER
		"ENGINEER":
			return ConvoyType.ENGINEER
		"ARMORED":
			return ConvoyType.ARMORED
		_:
			return ConvoyType.CARGO


static func convoy_type_label(t: ConvoyType) -> String:
	match t:
		ConvoyType.CARGO:
			return "Борт"
		ConvoyType.TANKER:
			return "АТЗ"
		ConvoyType.ENGINEER:
			return "Инж"
		ConvoyType.ARMORED:
			return "БТР"
	return "Борт"


static func order_mode_label(m: OrderMode) -> String:
	match m:
		OrderMode.ONE_WAY_RETURN:
			return "Разовый + возврат"
		OrderMode.REDEPLOY:
			return "Передислокация"
		OrderMode.LOOP:
			return "Циклический"
	return "Циклический"


static func road_type_from_string(value: String) -> RoadType:
	match value.to_upper():
		"HIGHWAY":
			return RoadType.HIGHWAY
		"SECONDARY":
			return RoadType.SECONDARY
		"DIRT":
			return RoadType.DIRT
		_:
			return RoadType.SECONDARY


static func road_type_label(t: RoadType) -> String:
	match t:
		RoadType.HIGHWAY:
			return "Шоссе"
		RoadType.SECONDARY:
			return "Второстепенная"
		RoadType.DIRT:
			return "Грунтовка"
	return "Дорога"


static func resource_type_from_string(value: String) -> ResourceType:
	match value.to_upper():
		"FUEL":
			return ResourceType.FUEL
		"AMMO":
			return ResourceType.AMMO
		"PROVISIONS":
			return ResourceType.PROVISIONS
		"PARTS":
			return ResourceType.PARTS
		"EQUIPMENT":
			return ResourceType.EQUIPMENT
		_:
			return ResourceType.FUEL


static func resource_label(r: ResourceType) -> String:
	match r:
		ResourceType.FUEL:
			return "Топливо"
		ResourceType.AMMO:
			return "Боеприпасы"
		ResourceType.PROVISIONS:
			return "Провизия"
		ResourceType.PARTS:
			return "Запчасти"
		ResourceType.EQUIPMENT:
			return "Перевооружение"
	return "Груз"


static func resource_short_label(r: ResourceType) -> String:
	match r:
		ResourceType.FUEL:
			return "ГСМ"
		ResourceType.AMMO:
			return "БК"
		ResourceType.PROVISIONS:
			return "ПР"
		ResourceType.PARTS:
			return "ЗП"
		ResourceType.EQUIPMENT:
			return "ПЕР"
	return "?"


static func cargo_pref_label(p: CargoPreference) -> String:
	match p:
		CargoPreference.MIXED:
			return "Смешанный"
		CargoPreference.FUEL:
			return "Топливо"
		CargoPreference.AMMO:
			return "Боеприпасы"
		CargoPreference.PROVISIONS:
			return "Провизия"
		CargoPreference.PARTS:
			return "Запчасти"
		CargoPreference.EQUIPMENT:
			return "Перевооружение"
		CargoPreference.EMPTY:
			return "Порожняком"
	return "Смешанный"


static func train_slot_from_string(value: String) -> TrainSlotType:
	match value.to_upper():
		"FUEL":
			return TrainSlotType.FUEL
		"AMMO":
			return TrainSlotType.AMMO
		"PROVISIONS":
			return TrainSlotType.PROVISIONS
		"PARTS":
			return TrainSlotType.PARTS
		"TRUCK_CARGO":
			return TrainSlotType.TRUCK_CARGO
		"TRUCK_TANKER":
			return TrainSlotType.TRUCK_TANKER
		"TRUCK_ENGINEER":
			return TrainSlotType.TRUCK_ENGINEER
		"TRUCK_ARMORED":
			return TrainSlotType.TRUCK_ARMORED
		"TRUCK_LOCKED":
			return TrainSlotType.TRUCK_LOCKED
		"EQUIPMENT_PLATFORM":
			return TrainSlotType.EQUIPMENT_PLATFORM
		"EQUIPMENT_LOCKED":
			return TrainSlotType.EQUIPMENT_LOCKED
		_:
			return TrainSlotType.FUEL


static func train_slot_short_label(s: TrainSlotType) -> String:
	match s:
		TrainSlotType.FUEL:
			return "ГСМ +80т"
		TrainSlotType.AMMO:
			return "БК +95т"
		TrainSlotType.PROVISIONS:
			return "ПРОВ +60т"
		TrainSlotType.PARTS:
			return "ЗАПЧ +50т"
		TrainSlotType.TRUCK_CARGO:
			return "+БОРТ"
		TrainSlotType.TRUCK_TANKER:
			return "+АТЗ"
		TrainSlotType.TRUCK_ENGINEER:
			return "+ИНЖ"
		TrainSlotType.TRUCK_ARMORED:
			return "+БТР"
		TrainSlotType.TRUCK_LOCKED:
			return "(ПЛАТФ.)"
		TrainSlotType.EQUIPMENT_PLATFORM:
			return "ПЕРЕВООР."
		TrainSlotType.EQUIPMENT_LOCKED:
			return "(ПЕРЕВ.)"
	return "ГСМ"


static func weather_from_string(value: String) -> Weather:
	match value.to_upper():
		"CLEAR":
			return Weather.CLEAR
		"RAIN":
			return Weather.RAIN
		"MUD":
			return Weather.MUD
		_:
			return Weather.CLEAR


static func weather_label(w: Weather) -> String:
	match w:
		Weather.CLEAR:
			return "ЯСНО"
		Weather.RAIN:
			return "ДОЖДЬ"
		Weather.MUD:
			return "РАСПУТИЦА"
	return "ЯСНО"


static func intensity_from_string(value: String) -> Intensity:
	match value.to_upper():
		"LOW":
			return Intensity.LOW
		"MEDIUM":
			return Intensity.MEDIUM
		"HIGH":
			return Intensity.HIGH
		_:
			return Intensity.LOW


static func intensity_label(i: Intensity) -> String:
	match i:
		Intensity.LOW:
			return "НИЗКАЯ"
		Intensity.MEDIUM:
			return "СРЕДНЯЯ"
		Intensity.HIGH:
			return "ВЫСОКАЯ"
	return "НИЗКАЯ"


static func convoy_state_label(s: ConvoyState) -> String:
	match s:
		ConvoyState.IDLE:
			return "Ожидание"
		ConvoyState.LOADING:
			return "Погрузка"
		ConvoyState.MOVING:
			return "В пути"
		ConvoyState.UNLOADING:
			return "Разгрузка"
	return "Ожидание"


class MapNode extends RefCounted:
	var id: String = ""
	var display_name: String = ""
	var node_type: NodeType = NodeType.JUNCTION
	var owner: Owner = Owner.FRIENDLY
	var position: Vector2 = Vector2.ZERO
	var flank: String = ""

	var stock: Dictionary[ResourceType, float] = {
		ResourceType.FUEL: 0.0,
		ResourceType.AMMO: 0.0,
		ResourceType.PROVISIONS: 0.0,
		ResourceType.PARTS: 0.0,
		ResourceType.EQUIPMENT: 0.0,
	}
	var capacity: Dictionary[ResourceType, float] = {
		ResourceType.FUEL: 0.0,
		ResourceType.AMMO: 0.0,
		ResourceType.PROVISIONS: 0.0,
		ResourceType.PARTS: 0.0,
		ResourceType.EQUIPMENT: 0.0,
	}

	var is_vulnerable: bool = false
	var camouflaged: bool = false
	var signature_mult: float = 1.0
	var loading_slots: int = 99
	var active_loading_count: int = 0
	var signature: float = 0.0
	var high_signature_warned: bool = false
	var pending_strike_ticks: int = -1
	var had_traffic_this_tick: bool = false

	# Field depot deployment / packing
	var can_deploy_depot: bool = false
	var deploy_requested: bool = false
	var deploy_cost_parts: float = 25.0
	var deploy_progress_parts: float = 0.0
	var deploy_build_ticks_remaining: int = 0
	var deploy_build_ticks_total: int = 24
	var pack_ticks_remaining: int = 0
	var pack_ticks_total: int = 18

	# Unit re-equipment & fortified objectives
	var equipment_tier: int = 1
	var reequip_progress: float = 0.0
	var reequip_cost: float = 30.0
	var reequip_ticks_remaining: int = 0
	var reequip_ticks_total: int = 18
	var fortified_resistance: float = 1.0

	# Per-tick signature telemetry (converted to /hour in SimEngine.get_signature_rate_breakdown)
	var last_sig_storage: float = 0.0
	var last_sig_traffic: float = 0.0
	var last_sig_queue: float = 0.0
	var last_sig_idle: float = 0.0
	var last_sig_decay: float = 0.0

	var is_bridge: bool = false
	var damaged: bool = false
	var repair_cost_parts: float = 20.0
	var repair_progress_parts: float = 0.0

	var integrity: float = 100.0
	var intensity: Intensity = Intensity.LOW
	var wounded: float = 0.0
	var target_objective_id: String = ""
	var capture_progress: float = 0.0

	var ammo_empty_warned: bool = false
	var fuel_empty_warned: bool = false
	var provisions_empty_warned: bool = false
	var wounded_warned: bool = false

	func get_stock(res: ResourceType) -> float:
		return stock.get(res, 0.0)

	func get_capacity(res: ResourceType) -> float:
		return capacity.get(res, 0.0)

	func add_stock(res: ResourceType, amount: float, is_engineer: bool = false) -> float:
		if amount <= 0.0:
			return 0.0
		if is_bridge and damaged and res == ResourceType.PARTS:
			if not is_engineer:
				return 0.0
			var needed: float = maxf(0.0, repair_cost_parts - repair_progress_parts)
			var applied: float = minf(amount, needed)
			repair_progress_parts += applied
			return applied
		if can_deploy_depot and node_type == NodeType.JUNCTION and res == ResourceType.PARTS and is_engineer and deploy_build_ticks_remaining <= 0:
			var needed_dep: float = maxf(0.0, deploy_cost_parts - deploy_progress_parts)
			var applied_dep: float = minf(amount, needed_dep)
			if applied_dep > 0.0:
				deploy_progress_parts += applied_dep
				deploy_requested = true
			return applied_dep
		if res == ResourceType.EQUIPMENT and (node_type == NodeType.FRONT_SECTOR or node_type == NodeType.ARTILLERY):
			if equipment_tier >= 2 or reequip_ticks_remaining > 0:
				return 0.0
			var needed_eq: float = maxf(0.0, reequip_cost - reequip_progress)
			var applied_eq: float = minf(amount, needed_eq)
			reequip_progress += applied_eq
			return applied_eq
		var cap: float = get_capacity(res)
		if cap <= 0.0:
			return 0.0
		var cur: float = get_stock(res)
		var space: float = maxf(0.0, cap - cur)
		var added: float = minf(amount, space)
		stock[res] = cur + added
		return added

	func take_stock(res: ResourceType, amount: float) -> float:
		if amount <= 0.0:
			return 0.0
		var cur: float = get_stock(res)
		var taken: float = minf(amount, cur)
		stock[res] = cur - taken
		return taken

	func get_total_stock() -> float:
		return (
			get_stock(ResourceType.FUEL)
			+ get_stock(ResourceType.AMMO)
			+ get_stock(ResourceType.PROVISIONS)
			+ get_stock(ResourceType.PARTS)
			+ get_stock(ResourceType.EQUIPMENT)
		)

	func get_total_capacity() -> float:
		return (
			get_capacity(ResourceType.FUEL)
			+ get_capacity(ResourceType.AMMO)
			+ get_capacity(ResourceType.PROVISIONS)
			+ get_capacity(ResourceType.PARTS)
			+ get_capacity(ResourceType.EQUIPMENT)
		)

	func has_storage() -> bool:
		return get_total_capacity() > 0.0


class RoadEdge extends RefCounted:
	var id: String = ""
	var from_id: String = ""
	var to_id: String = ""
	var road_type: RoadType = RoadType.SECONDARY
	var distance_km: float = 10.0
	var wear: float = 0.0
	var mined: bool = false
	var frontline_danger: bool = false
	var base_frontline_danger: bool = false
	var heavy_wear_warned: bool = false

	func get_base_speed_kmh() -> float:
		match road_type:
			RoadType.HIGHWAY:
				return 58.0
			RoadType.SECONDARY:
				return 40.0
			RoadType.DIRT:
				return 26.0
		return 40.0

	func get_min_speed_factor() -> float:
		match road_type:
			RoadType.HIGHWAY:
				return 0.85
			RoadType.SECONDARY:
				return 0.62
			RoadType.DIRT:
				return 0.42
		return 0.62

	func get_wear_rate_per_km(weather: Weather = Weather.CLEAR) -> float:
		var base_rate: float = 0.0028
		match road_type:
			RoadType.HIGHWAY:
				base_rate = 0.0005
			RoadType.SECONDARY:
				base_rate = 0.0028
			RoadType.DIRT:
				base_rate = 0.0095
		if road_type == RoadType.DIRT:
			if weather == Weather.RAIN:
				base_rate *= 2.0
			elif weather == Weather.MUD:
				base_rate *= 2.2
		elif road_type == RoadType.SECONDARY and weather == Weather.MUD:
			base_rate *= 1.35
		return base_rate

	func get_effective_speed_kmh(
		weather: Weather = Weather.CLEAR,
		bridge_damaged: bool = false,
		convoy_type: ConvoyType = ConvoyType.CARGO,
		dirt_mud_speed_mult: float = 1.0
	) -> float:
		var clamped_wear: float = clampf(wear, 0.0, 1.0)
		var factor: float = lerpf(1.0, get_min_speed_factor(), clamped_wear)
		var spd: float = get_base_speed_kmh() * factor
		if road_type == RoadType.DIRT:
			if weather == Weather.RAIN:
				spd *= (0.90 if convoy_type == ConvoyType.ARMORED else 0.65)
			elif weather == Weather.MUD:
				spd *= (0.80 if convoy_type == ConvoyType.ARMORED else 0.45)
			if convoy_type == ConvoyType.CARGO and weather != Weather.CLEAR:
				spd *= 1.15
			elif convoy_type == ConvoyType.TANKER:
				if weather != Weather.CLEAR:
					spd *= 0.70
				elif clamped_wear > 0.25:
					spd *= 0.85
		elif road_type == RoadType.SECONDARY and convoy_type != ConvoyType.ARMORED:
			if weather == Weather.RAIN:
				spd *= 0.90
			elif weather == Weather.MUD:
				spd *= 0.85
		if road_type == RoadType.DIRT or weather == Weather.MUD:
			spd *= dirt_mud_speed_mult
		if bridge_damaged:
			spd *= 0.15
		if mined:
			spd *= 0.65 if convoy_type == ConvoyType.ENGINEER else 0.15
		return maxf(2.0, spd)

	func get_travel_time_hours(
		weather: Weather = Weather.CLEAR,
		bridge_damaged: bool = false,
		convoy_type: ConvoyType = ConvoyType.CARGO,
		dirt_mud_speed_mult: float = 1.0
	) -> float:
		return distance_km / maxf(1.0, get_effective_speed_kmh(weather, bridge_damaged, convoy_type, dirt_mud_speed_mult))

	func get_other_node(node_id: String) -> String:
		if node_id == from_id:
			return to_id
		if node_id == to_id:
			return from_id
		return ""


class WaveEntry extends RefCounted:
	var start_hour: int = 0
	var end_hour: int = 120
	var sector_intensities: Dictionary[String, Intensity] = {}


class WeatherEntry extends RefCounted:
	var start_hour: int = 0
	var end_hour: int = 120
	var weather: Weather = Weather.CLEAR


class BridgeStrikeEntry extends RefCounted:
	var hour: int = 24
	var node_id: String = ""


class Radiogram extends RefCounted:
	var id: String = ""
	var tick: int = 0
	var hour: int = 0
	var sender: String = ""
	var node_id: String = ""
	var text: String = ""
	var severity: EventSeverity = EventSeverity.INFO
	var dismissed: bool = false


class SimEvent extends RefCounted:
	var tick: int = 0
	var day: int = 1
	var hour: int = 6
	var minute: int = 0
	var severity: EventSeverity = EventSeverity.INFO
	var category: String = "SYSTEM"
	var autopause_tag: AutoPauseTag = AutoPauseTag.NONE
	var node_id: String = ""
	var world_pos: Vector2 = Vector2.ZERO
	var has_world_pos: bool = false
	var message: String = ""

	func format_line() -> String:
		return "[Д%d %02d:%02d] %s" % [day, hour, minute, message]


class CampaignModifiers extends RefCounted:
	var bonus_cargo_convoys: int = 0
	var bonus_tanker_convoys: int = 0
	var bonus_engineer_convoys: int = 0
	var bonus_armored_convoys: int = 0
	var bonus_train_slots: int = 0
	var depot_signature_growth_mult: float = 1.0
	var dirt_mud_speed_mult: float = 1.0


class SecondaryObjectiveSpec extends RefCounted:
	var id: String = ""
	var title: String = ""
	var description: String = ""
	var metric: String = ""
	var target_value: float = 0.0
	var bonus_cp: int = 40


class SimStats extends RefCounted:
	var elapsed_hours: float = 0.0
	var delivered_by_resource: Dictionary[ResourceType, float] = {
		ResourceType.FUEL: 0.0,
		ResourceType.AMMO: 0.0,
		ResourceType.PROVISIONS: 0.0,
		ResourceType.PARTS: 0.0,
		ResourceType.EQUIPMENT: 0.0,
	}
	var total_delivered_tons: float = 0.0
	var wounded_generated: float = 0.0
	var wounded_evacuated: float = 0.0
	var wounded_remaining: float = 0.0
	var wounded_evac_ratio: float = 1.0
	var depot_strikes: int = 0
	var bridges_damaged: int = 0
	var bridges_repaired: int = 0
	var roads_demined: int = 0
	var objectives_captured: int = 0
	var objectives_total: int = 0
	var min_sector_integrity: float = 100.0
	var peak_depot_signature: float = 0.0
	var trains_arrived: int = 0
	var field_depots_deployed: int = 0
	var field_depots_packed: int = 0
	var units_modernized: int = 0
	var convoys_damaged_hits: int = 0
	var convoys_disabled_count: int = 0


class ScenarioConfig extends RefCounted:
	var id: String = "scenario_offensive"
	var scenario_name: String = ""
	var short_title: String = ""
	var mission_mode: MissionMode = MissionMode.OFFENSIVE
	var map_bounds: Rect2 = Rect2(0.0, 0.0, 2200.0, 1250.0)
	var duration_hours: int = 120
	var phase2_start_hour: int = 36
	var start_hour: int = 6
	var rng_seed: int = 404120
	var required_modernized_units: int = 0
	var frontline_interdiction_mult: float = 0.65
	var equipment_platform_amount: float = 30.0
	var phase1_readiness_target: Dictionary[ResourceType, float] = {
		ResourceType.FUEL: 340.0,
		ResourceType.AMMO: 460.0,
	}
	var railhead_interval_hours: int = 8
	var train_lock_hours: int = 3
	var train_slots: int = 6
	var truck_order_cooldown_hours: int = 16
	var default_train_target: String = "rail_zapadnaya"
	var default_train_slots: Array[TrainSlotType] = [
		TrainSlotType.FUEL,
		TrainSlotType.FUEL,
		TrainSlotType.AMMO,
		TrainSlotType.AMMO,
		TrainSlotType.PROVISIONS,
		TrainSlotType.PARTS,
	]
	var slot_amounts: Dictionary[ResourceType, float] = {
		ResourceType.FUEL: 80.0,
		ResourceType.AMMO: 95.0,
		ResourceType.PROVISIONS: 60.0,
		ResourceType.PARTS: 50.0,
	}
	var recon_interval_hours: int = 8
	var convoy_cargo_capacity: float = 28.0
	var convoy_fuel_tank: float = 7.0
	var convoy_fuel_burn_per_km: float = 0.008
	var convoy_load_ticks: int = 2
	var initial_fleet: Array[Dictionary] = []
	var waves: Array[WaveEntry] = []
	var weather_schedule: Array[WeatherEntry] = []
	var bridge_strikes: Array[BridgeStrikeEntry] = []
	var scheduled_radiograms: Array[Radiogram] = []
	var secondary_objectives: Array[SecondaryObjectiveSpec] = []
