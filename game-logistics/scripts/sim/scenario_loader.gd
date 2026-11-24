class_name ScenarioLoader
extends RefCounted


class LoadResult extends RefCounted:
	var ok: bool = false
	var error: String = ""
	var config: SimTypes.ScenarioConfig = null
	var graph: WorldGraph = null


static func load_from_file(path: String) -> LoadResult:
	var res: LoadResult = LoadResult.new()
	if not FileAccess.file_exists(path):
		res.error = "Scenario file not found: %s" % path
		return res

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		res.error = "Failed to open scenario file: %s" % path
		return res

	var raw_text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		res.error = "Invalid JSON root in %s" % path
		return res

	var data: Dictionary = parsed
	var config: SimTypes.ScenarioConfig = SimTypes.ScenarioConfig.new()
	config.id = str(data.get("id", "scenario_offensive"))
	config.scenario_name = str(data.get("name", "Операция"))
	config.short_title = str(data.get("short_title", config.scenario_name))
	config.duration_hours = int(data.get("duration_hours", 120))
	config.phase2_start_hour = int(data.get("phase2_start_hour", 36))
	config.start_hour = int(data.get("start_hour", 6))
	config.rng_seed = int(data.get("rng_seed", 404120))
	config.required_modernized_units = int(data.get("required_modernized_units", 0))
	config.frontline_interdiction_mult = float(data.get("frontline_interdiction_mult", 0.65))
	config.equipment_platform_amount = float(data.get("equipment_platform_amount", 30.0))
	config.railhead_interval_hours = int(data.get("railhead_interval_hours", 8))
	config.train_lock_hours = int(data.get("train_lock_hours", 3))
	config.train_slots = int(data.get("train_slots", 6))
	config.truck_order_cooldown_hours = int(data.get("truck_order_cooldown_hours", 16))
	config.default_train_target = str(data.get("default_train_target", "rail_zapadnaya"))
	config.recon_interval_hours = int(data.get("recon_interval_hours", 8))

	var bounds_raw: Variant = data.get("map_bounds", {})
	if typeof(bounds_raw) == TYPE_DICTIONARY:
		var bdict: Dictionary = bounds_raw
		config.map_bounds = Rect2(
			float(bdict.get("x", 0.0)),
			float(bdict.get("y", 0.0)),
			float(bdict.get("width", 2200.0)),
			float(bdict.get("height", 1250.0))
		)

	var ready_raw: Variant = data.get("phase1_readiness_target", {})
	if typeof(ready_raw) == TYPE_DICTIONARY:
		var rdict: Dictionary = ready_raw
		config.phase1_readiness_target[SimTypes.ResourceType.FUEL] = float(rdict.get("FUEL", 340.0))
		config.phase1_readiness_target[SimTypes.ResourceType.AMMO] = float(rdict.get("AMMO", 460.0))

	var def_slots_raw: Variant = data.get("default_train_slots", [])
	if typeof(def_slots_raw) == TYPE_ARRAY:
		var ds_arr: Array = def_slots_raw
		if not ds_arr.is_empty():
			config.default_train_slots.clear()
			for item: Variant in ds_arr:
				config.default_train_slots.append(SimTypes.train_slot_from_string(str(item)))

	var slot_amts_raw: Variant = data.get("slot_amounts", {})
	if typeof(slot_amts_raw) == TYPE_DICTIONARY:
		var sa_dict: Dictionary = slot_amts_raw
		for res_key: String in ["FUEL", "AMMO", "PROVISIONS", "PARTS"]:
			if sa_dict.has(res_key):
				var rtype: SimTypes.ResourceType = SimTypes.resource_type_from_string(res_key)
				config.slot_amounts[rtype] = float(sa_dict[res_key])

	var convoys_raw: Variant = data.get("convoys", {})
	if typeof(convoys_raw) == TYPE_DICTIONARY:
		var convoys_dict: Dictionary = convoys_raw
		config.convoy_cargo_capacity = float(convoys_dict.get("cargo_capacity", 24.0))
		config.convoy_fuel_tank = float(convoys_dict.get("fuel_tank", 7.0))
		config.convoy_fuel_burn_per_km = float(convoys_dict.get("fuel_burn_per_km", 0.008))
		config.convoy_load_ticks = int(convoys_dict.get("load_ticks", 2))
		var fleet_raw: Variant = convoys_dict.get("initial_fleet", [])
		if typeof(fleet_raw) == TYPE_ARRAY:
			var fleet_arr: Array = fleet_raw
			for item: Variant in fleet_arr:
				if typeof(item) == TYPE_DICTIONARY:
					config.initial_fleet.append(item)

	var graph: WorldGraph = WorldGraph.new()

	var nodes_raw: Variant = data.get("nodes", [])
	if typeof(nodes_raw) != TYPE_ARRAY:
		res.error = "Scenario missing nodes array"
		return res

	var nodes_arr: Array = nodes_raw
	for item: Variant in nodes_arr:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var nd: Dictionary = item
		var node: SimTypes.MapNode = SimTypes.MapNode.new()
		node.id = str(nd.get("id", ""))
		node.display_name = str(nd.get("name", node.id))
		node.node_type = SimTypes.node_type_from_string(str(nd.get("type", "JUNCTION")))
		node.owner = SimTypes.owner_from_string(str(nd.get("owner", "FRIENDLY")))
		node.position = Vector2(float(nd.get("x", 0.0)), float(nd.get("y", 0.0)))
		node.flank = str(nd.get("flank", ""))
		node.signature = float(nd.get("signature", 0.0))
		node.integrity = float(nd.get("integrity", 100.0))
		node.is_vulnerable = bool(nd.get("is_vulnerable", node.node_type == SimTypes.NodeType.DEPOT or node.node_type == SimTypes.NodeType.FIELD_DEPOT))
		node.signature_mult = float(nd.get("signature_mult", 0.75 if node.node_type == SimTypes.NodeType.FIELD_DEPOT else 1.0))
		node.loading_slots = int(nd.get("loading_slots", 2 if (node.node_type == SimTypes.NodeType.DEPOT or node.node_type == SimTypes.NodeType.FIELD_DEPOT) else 99))
		node.can_deploy_depot = bool(nd.get("can_deploy_depot", false))
		node.deploy_cost_parts = float(nd.get("deploy_cost_parts", 25.0))
		node.equipment_tier = clampi(int(nd.get("equipment_tier", 1)), 1, 2)
		node.fortified_resistance = maxf(1.0, float(nd.get("fortified_resistance", 1.0)))
		node.is_bridge = bool(nd.get("is_bridge", false))
		node.damaged = bool(nd.get("damaged", false))
		node.repair_cost_parts = float(nd.get("repair_cost_parts", 20.0))
		node.target_objective_id = str(nd.get("target_objective_id", ""))
		node.capture_progress = float(nd.get("capture_progress", 0.0))

		var stock_raw: Variant = nd.get("stock", {})
		if typeof(stock_raw) == TYPE_DICTIONARY:
			var stock_dict: Dictionary = stock_raw
			node.stock[SimTypes.ResourceType.FUEL] = float(stock_dict.get("FUEL", 0.0))
			node.stock[SimTypes.ResourceType.AMMO] = float(stock_dict.get("AMMO", 0.0))
			node.stock[SimTypes.ResourceType.PROVISIONS] = float(stock_dict.get("PROVISIONS", 0.0))
			node.stock[SimTypes.ResourceType.PARTS] = float(stock_dict.get("PARTS", 0.0))
			node.stock[SimTypes.ResourceType.EQUIPMENT] = float(stock_dict.get("EQUIPMENT", 0.0))

		var cap_raw: Variant = nd.get("capacity", {})
		if typeof(cap_raw) == TYPE_DICTIONARY:
			var cap_dict: Dictionary = cap_raw
			node.capacity[SimTypes.ResourceType.FUEL] = float(cap_dict.get("FUEL", 0.0))
			node.capacity[SimTypes.ResourceType.AMMO] = float(cap_dict.get("AMMO", 0.0))
			node.capacity[SimTypes.ResourceType.PROVISIONS] = float(cap_dict.get("PROVISIONS", 0.0))
			node.capacity[SimTypes.ResourceType.PARTS] = float(cap_dict.get("PARTS", 0.0))
			var default_eq_cap: float = 0.0
			if node.node_type == SimTypes.NodeType.RAILHEAD:
				default_eq_cap = 300.0
			elif node.node_type == SimTypes.NodeType.DEPOT or node.node_type == SimTypes.NodeType.FIELD_DEPOT:
				default_eq_cap = 60.0
			node.capacity[SimTypes.ResourceType.EQUIPMENT] = float(cap_dict.get("EQUIPMENT", default_eq_cap))

		graph.add_node(node)

	var edges_raw: Variant = data.get("edges", [])
	if typeof(edges_raw) != TYPE_ARRAY:
		res.error = "Scenario missing edges array"
		return res

	var edges_arr: Array = edges_raw
	for item: Variant in edges_arr:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var ed: Dictionary = item
		var edge: SimTypes.RoadEdge = SimTypes.RoadEdge.new()
		edge.id = str(ed.get("id", ""))
		edge.from_id = str(ed.get("from", ""))
		edge.to_id = str(ed.get("to", ""))
		edge.road_type = SimTypes.road_type_from_string(str(ed.get("road_type", "SECONDARY")))
		edge.distance_km = float(ed.get("distance_km", 10.0))
		edge.wear = float(ed.get("wear", 0.0))
		edge.mined = bool(ed.get("mined", false))
		edge.base_frontline_danger = bool(ed.get("frontline_danger", false))
		edge.frontline_danger = edge.base_frontline_danger
		graph.add_edge(edge)

	graph.finalize_metrics()

	var waves_raw: Variant = data.get("waves", [])
	if typeof(waves_raw) == TYPE_ARRAY:
		var waves_arr: Array = waves_raw
		for item: Variant in waves_arr:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var wd: Dictionary = item
			var wave: SimTypes.WaveEntry = SimTypes.WaveEntry.new()
			wave.start_hour = int(wd.get("start_hour", 0))
			wave.end_hour = int(wd.get("end_hour", 120))
			var sectors_raw: Variant = wd.get("sectors", {})
			if typeof(sectors_raw) == TYPE_DICTIONARY:
				var sectors_dict: Dictionary = sectors_raw
				for key_var: Variant in sectors_dict.keys():
					var sec_id: String = str(key_var)
					var inten_str: String = str(sectors_dict[key_var])
					wave.sector_intensities[sec_id] = SimTypes.intensity_from_string(inten_str)
			config.waves.append(wave)

	var weather_raw: Variant = data.get("weather_schedule", [])
	if typeof(weather_raw) == TYPE_ARRAY:
		var w_arr: Array = weather_raw
		for item: Variant in w_arr:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var wdict: Dictionary = item
			var we: SimTypes.WeatherEntry = SimTypes.WeatherEntry.new()
			we.start_hour = int(wdict.get("start_hour", 0))
			we.end_hour = int(wdict.get("end_hour", 120))
			we.weather = SimTypes.weather_from_string(str(wdict.get("weather", "CLEAR")))
			config.weather_schedule.append(we)

	var strikes_raw: Variant = data.get("bridge_strikes", [])
	if typeof(strikes_raw) == TYPE_ARRAY:
		var bs_arr: Array = strikes_raw
		for item: Variant in bs_arr:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var bdict: Dictionary = item
			var bs: SimTypes.BridgeStrikeEntry = SimTypes.BridgeStrikeEntry.new()
			bs.hour = int(bdict.get("hour", 24))
			bs.node_id = str(bdict.get("node_id", ""))
			config.bridge_strikes.append(bs)

	var rad_raw: Variant = data.get("radiograms", [])
	if typeof(rad_raw) == TYPE_ARRAY:
		var r_arr: Array = rad_raw
		for item: Variant in r_arr:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var rdict: Dictionary = item
			var rad: SimTypes.Radiogram = SimTypes.Radiogram.new()
			rad.id = str(rdict.get("id", ""))
			rad.hour = int(rdict.get("hour", 0))
			rad.sender = str(rdict.get("sender", "Штаб"))
			rad.node_id = str(rdict.get("node_id", ""))
			rad.text = str(rdict.get("text", ""))
			var sev_str: String = str(rdict.get("severity", "INFO")).to_upper()
			match sev_str:
				"WARNING":
					rad.severity = SimTypes.EventSeverity.WARNING
				"CRITICAL":
					rad.severity = SimTypes.EventSeverity.CRITICAL
				_:
					rad.severity = SimTypes.EventSeverity.INFO
			config.scheduled_radiograms.append(rad)

	if data.has("mission_mode"):
		var mode_str: String = str(data.get("mission_mode", "OFFENSIVE")).to_upper()
		config.mission_mode = SimTypes.MissionMode.DEFENSE if mode_str == "DEFENSE" else SimTypes.MissionMode.OFFENSIVE
	else:
		var has_obj: bool = not graph.get_nodes_by_type(SimTypes.NodeType.OBJECTIVE).is_empty()
		config.mission_mode = SimTypes.MissionMode.OFFENSIVE if has_obj else SimTypes.MissionMode.DEFENSE

	var sec_raw: Variant = data.get("secondary_objectives", [])
	if typeof(sec_raw) == TYPE_ARRAY:
		var sec_arr: Array = sec_raw
		for item: Variant in sec_arr:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var sdict: Dictionary = item
			var spec: SimTypes.SecondaryObjectiveSpec = SimTypes.SecondaryObjectiveSpec.new()
			spec.id = str(sdict.get("id", ""))
			spec.title = str(sdict.get("title", ""))
			spec.description = str(sdict.get("description", ""))
			spec.metric = str(sdict.get("metric", "")).to_upper()
			spec.target_value = float(sdict.get("target_value", 0.0))
			spec.bonus_cp = int(sdict.get("bonus_cp", 40))
			config.secondary_objectives.append(spec)

	res.ok = true
	res.config = config
	res.graph = graph
	return res
