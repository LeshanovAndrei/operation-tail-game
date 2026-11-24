extends SceneTree

const DEFENSE_SCENARIO: String = "res://data/scenario_defense_01.json"
const OFFENSIVE_SCENARIO: String = "res://data/scenario_offensive.json"
const BREAKTHROUGH_SCENARIO: String = "res://data/scenario_breakthrough_03.json"

var _failures: int = 0


func _initialize() -> void:
	print("=== Stage 6 & 7 Headless Campaign, Modifiers & UI Smoke Test ===")
	_test_catalog_loading()
	_test_modifiers_effect()
	_test_defense_48h_operation()
	_test_offensive_stats_and_secondary()
	_test_breakthrough_120h_operation()
	_test_ui_scene_instantiation()

	if _failures > 0:
		printerr("FAILED assertions: %d" % _failures)
		quit(1)
		return

	print("ALL STAGE 6 & 7 CAMPAIGN & SCENE CHECKS PASSED.")
	quit(0)


func _test_catalog_loading() -> void:
	print("\n--- Test 1: Data-Driven Campaigns & Upgrades Catalog ---")
	var campaigns: Array[Dictionary] = CampaignData.load_campaigns_index()
	var upgrades: Array[Dictionary] = CampaignData.load_upgrades_catalog()
	_assert_true(campaigns.size() == 2, "Loaded 2 campaigns from campaigns_index.json")
	_assert_true(upgrades.size() == 7, "Loaded 7 upgrades from upgrades.json")

	var c1: Dictionary = campaigns[0]
	var ops: Array = c1.get("operations", [])
	_assert_true(str(c1.get("id", "")) == "eastern_front" and not bool(c1.get("coming_soon", true)), "Campaign 1 eastern_front is active")
	_assert_true(ops.size() == 3, "Campaign 1 has 3 operations (all 3 unlocked in sequence)")
	_assert_true(not bool((ops[2] as Dictionary).get("coming_soon", true)), "Operation 3 op_03_proryv is unlocked and playable")
	_assert_true(bool(campaigns[1].get("coming_soon", false)), "Campaign 2 winter_cauldron is marked coming_soon")


func _test_modifiers_effect() -> void:
	print("\n--- Test 2: Campaign Modifiers Apply to SimEngine ---")
	var upgrades: Array[Dictionary] = CampaignData.load_upgrades_catalog()
	var purchased: Array[String] = [
		"extra_cargo",
		"extra_tanker",
		"extra_engineer",
		"extra_armored",
		"extended_train",
		"camo_nets",
		"heavy_suspension",
	]
	var mods: SimTypes.CampaignModifiers = CampaignData.build_modifiers(purchased, upgrades)
	_assert_true(mods.bonus_cargo_convoys == 1 and mods.bonus_tanker_convoys == 1 and mods.bonus_engineer_convoys == 1 and mods.bonus_armored_convoys == 1, "Built +1/+1/+1/+1 fleet modifiers")
	_assert_true(mods.bonus_train_slots == 1, "Built +1 train slot modifier")
	_assert_true(is_equal_approx(mods.depot_signature_growth_mult, 0.80), "Built 0.80 signature growth mult")
	_assert_true(is_equal_approx(mods.dirt_mud_speed_mult, 1.15), "Built 1.15 dirt/mud speed mult")

	var base_eng: SimEngine = SimEngine.new()
	_assert_true(base_eng.load_scenario(DEFENSE_SCENARIO), "Loaded baseline defense scenario")

	var mod_eng: SimEngine = SimEngine.new()
	_assert_true(mod_eng.load_scenario(DEFENSE_SCENARIO, mods), "Loaded modified defense scenario")

	_assert_true(mod_eng.convoys.size() == base_eng.convoys.size() + 4, "Bonus fleet added +4 starting convoys (%d vs %d)" % [mod_eng.convoys.size(), base_eng.convoys.size()])
	_assert_true(mod_eng.get_effective_train_slots() == 7 and mod_eng.inbound_train_slots.size() == 7, "Extended train modifier grants 7 slots")

	# Verify signature reduction
	var b_bor: SimTypes.MapNode = base_eng.graph.get_node("depot_bor")
	var m_bor: SimTypes.MapNode = mod_eng.graph.get_node("depot_bor")
	b_bor.stock[SimTypes.ResourceType.AMMO] = 180.0
	m_bor.stock[SimTypes.ResourceType.AMMO] = 180.0
	for _t: int in range(18):
		base_eng.step_tick()
		mod_eng.step_tick()
	_assert_true(m_bor.signature < b_bor.signature, "Camo nets upgrade lowers depot signature (%.2f < %.2f)" % [m_bor.signature, b_bor.signature])

	# Verify dirt/mud road speed boost
	var dirt_edge: SimTypes.RoadEdge = null
	for e: SimTypes.RoadEdge in mod_eng.graph.edges:
		if e.road_type == SimTypes.RoadType.DIRT:
			dirt_edge = e
			break
	_assert_true(dirt_edge != null, "Found DIRT edge for speed test")
	var base_spd: float = base_eng.graph.get_edge_effective_speed_kmh(dirt_edge, SimTypes.Weather.MUD, SimTypes.ConvoyType.CARGO)
	var upg_spd: float = mod_eng.graph.get_edge_effective_speed_kmh(dirt_edge, SimTypes.Weather.MUD, SimTypes.ConvoyType.CARGO)
	_assert_true(upg_spd > base_spd, "Heavy suspension increases DIRT/MUD speed (%.2f > %.2f km/h)" % [upg_spd, base_spd])


func _test_defense_48h_operation() -> void:
	print("\n--- Test 3: Full 48h Defense Operation (scenario_defense_01.json) ---")
	var engine: SimEngine = SimEngine.new()
	_assert_true(engine.load_scenario(DEFENSE_SCENARIO), "Loaded scenario_defense_01.json")
	_assert_true(engine.graph.get_all_nodes().size() == 15, "Defense scenario has 15 nodes")
	_assert_true(engine.graph.get_nodes_by_type(SimTypes.NodeType.FRONT_SECTOR).size() == 4, "Defense scenario has 4 front sectors")
	_assert_true(engine.graph.get_nodes_by_type(SimTypes.NodeType.DEPOT).size() == 2, "Defense scenario has 2 depots")
	_assert_true(engine.config.mission_mode == SimTypes.MissionMode.DEFENSE, "Mission mode parsed as DEFENSE")

	# Camouflage both depots to stay safe from strikes
	engine.toggle_node_camouflage("depot_bor")
	engine.toggle_node_camouflage("depot_step")

	# Assign initial 9 convoys: 4 CARGO -> 4 front sectors (with medevac), 1 CARGO -> arty, 3 TANKER -> front_d1..d3 (4th rotated)
	engine.dispatch_idle_from_node("rail_stancia", "front_d1", int(SimTypes.ConvoyType.CARGO), SimTypes.CargoPreference.MIXED, SimTypes.OrderMode.LOOP, true)
	engine.dispatch_idle_from_node("rail_stancia", "front_d2", int(SimTypes.ConvoyType.CARGO), SimTypes.CargoPreference.MIXED, SimTypes.OrderMode.LOOP, true)
	engine.dispatch_idle_from_node("rail_stancia", "front_d3", int(SimTypes.ConvoyType.CARGO), SimTypes.CargoPreference.MIXED, SimTypes.OrderMode.LOOP, true)
	engine.dispatch_idle_from_node("rail_stancia", "front_d4", int(SimTypes.ConvoyType.CARGO), SimTypes.CargoPreference.MIXED, SimTypes.OrderMode.LOOP, true)
	engine.dispatch_idle_from_node("rail_stancia", "arty_div1", int(SimTypes.ConvoyType.CARGO), SimTypes.CargoPreference.AMMO, SimTypes.OrderMode.LOOP, false)

	engine.dispatch_idle_from_node("rail_stancia", "front_d1", int(SimTypes.ConvoyType.TANKER), SimTypes.CargoPreference.FUEL, SimTypes.OrderMode.LOOP, false)
	engine.dispatch_idle_from_node("rail_stancia", "front_d2", int(SimTypes.ConvoyType.TANKER), SimTypes.CargoPreference.FUEL, SimTypes.OrderMode.LOOP, false)
	engine.dispatch_idle_from_node("rail_stancia", "front_d3", int(SimTypes.ConvoyType.TANKER), SimTypes.CargoPreference.FUEL, SimTypes.OrderMode.LOOP, false)

	var seen_train_tag: bool = false
	var seen_assault_tag: bool = false
	var seen_strike_tag: bool = false
	var sent_bridge_repair: bool = false
	var d4_fuel_loop_started: bool = false

	var total_ticks: int = engine.config.duration_hours * SimEngine.TICKS_PER_HOUR
	for _t: int in range(total_ticks):
		engine.step_tick()
		for tag: SimTypes.AutoPauseTag in engine.last_tick_autopause_tags:
			if tag == SimTypes.AutoPauseTag.TRAIN_ARRIVED:
				seen_train_tag = true
			elif tag == SimTypes.AutoPauseTag.ASSAULT_STARTED:
				seen_assault_tag = true
			elif tag == SimTypes.AutoPauseTag.STRIKE_OR_DAMAGE:
				seen_strike_tag = true

		if engine.result != SimTypes.GameResult.RUNNING:
			break

		var br: SimTypes.MapNode = engine.graph.get_node("junc_most_sever")
		if br != null and br.damaged and not sent_bridge_repair:
			var ec: Convoy = engine.dispatch_idle_from_node(
				"rail_stancia", "junc_most_sever", int(SimTypes.ConvoyType.ENGINEER),
				SimTypes.CargoPreference.PARTS, SimTypes.OrderMode.ONE_WAY_RETURN
			)
			if ec != null:
				sent_bridge_repair = true

		# Rotate a tanker to front_d4 when front_d3 has plenty of fuel
		if not d4_fuel_loop_started:
			var fd4: SimTypes.MapNode = engine.graph.get_node("front_d4")
			if fd4 != null and fd4.get_stock(SimTypes.ResourceType.FUEL) < 18.0:
				for c: Convoy in engine.convoys:
					if c.convoy_type == SimTypes.ConvoyType.TANKER and c.destination_node_id == "front_d3" and c.loop:
						c.stop_loop()
						break
				var idle_t: Convoy = engine.dispatch_idle_from_node(
					"rail_stancia", "front_d4", int(SimTypes.ConvoyType.TANKER),
					SimTypes.CargoPreference.FUEL, SimTypes.OrderMode.LOOP, false
				)
				if idle_t != null:
					d4_fuel_loop_started = true

	var stats: SimTypes.SimStats = engine.get_operation_stats()
	var sec_res: Array[Dictionary] = engine.evaluate_secondary_objectives()
	print("  Defense stats: Hours=%.1f | Delivered=%.0fт | Wounded=%.0f/%.0f (%.0f%%) | Strikes=%d | BridgesRepaired=%d" % [
		stats.elapsed_hours,
		stats.total_delivered_tons,
		stats.wounded_evacuated,
		stats.wounded_evacuated + stats.wounded_remaining,
		stats.wounded_evac_ratio * 100.0,
		stats.depot_strikes,
		stats.bridges_repaired,
	])

	_assert_true(engine.result == SimTypes.GameResult.VICTORY, "Defense operation achieved VICTORY")
	_assert_true(seen_train_tag and seen_assault_tag and seen_strike_tag, "All 3 autopause event tags fired during defense")
	_assert_true(stats.bridges_repaired >= 1, "Repaired Мост Сосновый during defense")
	_assert_true(stats.depot_strikes == 0, "Zero depot strikes during defense")
	_assert_true(stats.wounded_evac_ratio >= 0.80, "Evacuated >= 80%% wounded (%.0f%%)" % (stats.wounded_evac_ratio * 100.0))
	_assert_true(sec_res.size() == 2 and bool(sec_res[0].get("completed", false)) and bool(sec_res[1].get("completed", false)), "Both defense secondary objectives completed")


func _test_offensive_stats_and_secondary() -> void:
	print("\n--- Test 4: Offensive Secondary Objectives & Upgraded Victory ---")
	var upgrades: Array[Dictionary] = CampaignData.load_upgrades_catalog()
	var mods: SimTypes.CampaignModifiers = CampaignData.build_modifiers(["extra_cargo", "camo_nets", "heavy_suspension"], upgrades)
	var engine: SimEngine = SimEngine.new()
	_assert_true(engine.load_scenario(OFFENSIVE_SCENARIO, mods), "Loaded scenario_offensive.json with campaign modifiers")

	engine.toggle_node_camouflage("depot_lipki")
	engine.toggle_node_camouflage("depot_krasny_yar")
	engine.dispatch_idle_from_node("rail_zapadnaya", "front_n1", int(SimTypes.ConvoyType.CARGO), SimTypes.CargoPreference.MIXED, SimTypes.OrderMode.LOOP, true)
	engine.dispatch_idle_from_node("rail_zapadnaya", "front_n2", int(SimTypes.ConvoyType.CARGO), SimTypes.CargoPreference.MIXED, SimTypes.OrderMode.LOOP, true)
	engine.dispatch_idle_from_node("rail_zapadnaya", "front_n3", int(SimTypes.ConvoyType.CARGO), SimTypes.CargoPreference.MIXED, SimTypes.OrderMode.LOOP, true)
	engine.dispatch_idle_from_node("rail_zapadnaya", "front_s2", int(SimTypes.ConvoyType.CARGO), SimTypes.CargoPreference.MIXED, SimTypes.OrderMode.LOOP, true)
	engine.dispatch_idle_from_node("rail_zapadnaya", "front_s3", int(SimTypes.ConvoyType.CARGO), SimTypes.CargoPreference.MIXED, SimTypes.OrderMode.LOOP, true)
	engine.dispatch_idle_from_node("rail_zapadnaya", "arty_north", int(SimTypes.ConvoyType.CARGO), SimTypes.CargoPreference.AMMO, SimTypes.OrderMode.LOOP, false)
	engine.dispatch_idle_from_node("rail_zapadnaya", "arty_south", int(SimTypes.ConvoyType.CARGO), SimTypes.CargoPreference.AMMO, SimTypes.OrderMode.LOOP, false)

	engine.dispatch_idle_from_node("rail_zapadnaya", "front_n1", int(SimTypes.ConvoyType.TANKER), SimTypes.CargoPreference.FUEL, SimTypes.OrderMode.LOOP, false)
	engine.dispatch_idle_from_node("rail_zapadnaya", "front_n2", int(SimTypes.ConvoyType.TANKER), SimTypes.CargoPreference.FUEL, SimTypes.OrderMode.LOOP, false)
	engine.dispatch_idle_from_node("rail_zapadnaya", "front_s2", int(SimTypes.ConvoyType.TANKER), SimTypes.CargoPreference.FUEL, SimTypes.OrderMode.LOOP, false)
	engine.dispatch_idle_from_node("rail_zapadnaya", "front_s3", int(SimTypes.ConvoyType.TANKER), SimTypes.CargoPreference.FUEL, SimTypes.OrderMode.LOOP, false)

	engine.dispatch_idle_from_node("rail_uzlovaya", "front_s1", int(SimTypes.ConvoyType.CARGO), SimTypes.CargoPreference.MIXED, SimTypes.OrderMode.LOOP, true)
	engine.dispatch_idle_from_node("rail_uzlovaya", "front_s1", int(SimTypes.ConvoyType.TANKER), SimTypes.CargoPreference.FUEL, SimTypes.OrderMode.LOOP, false)
	engine.dispatch_idle_from_node("rail_zapadnaya", "front_n2", int(SimTypes.ConvoyType.ENGINEER), SimTypes.CargoPreference.PARTS, SimTypes.OrderMode.LOOP, false)

	var sent_kam: bool = false
	var redirected_captured: Dictionary[String, bool] = {}
	var total_ticks: int = engine.config.duration_hours * SimEngine.TICKS_PER_HOUR
	for _t: int in range(total_ticks):
		engine.step_tick()
		if engine.result != SimTypes.GameResult.RUNNING:
			break
		if not engine.is_inbound_train_locked():
			engine.set_train_target_railhead("rail_uzlovaya" if engine.trains_arrived % 2 == 1 else "rail_zapadnaya")
		if engine.phase == SimTypes.OperationPhase.OFFENSIVE:
			for c: Convoy in engine.convoys:
				if c.convoy_type == SimTypes.ConvoyType.CARGO and c.destination_node_id in ["front_n1", "front_n2"]:
					var fn: SimTypes.MapNode = engine.graph.get_node(c.destination_node_id)
					if fn != null and fn.get_stock(SimTypes.ResourceType.PROVISIONS) < 15.0:
						c.set_cargo_preference(SimTypes.CargoPreference.MIXED)
					elif fn != null and fn.get_stock(SimTypes.ResourceType.AMMO) < 40.0:
						c.set_cargo_preference(SimTypes.CargoPreference.AMMO)
		for c: Convoy in engine.convoys:
			var dest_n: SimTypes.MapNode = engine.graph.get_node(c.destination_node_id)
			if dest_n != null and not dest_n.target_objective_id.is_empty():
				var obj_n: SimTypes.MapNode = engine.graph.get_node(dest_n.target_objective_id)
				if obj_n != null and obj_n.owner == SimTypes.Owner.FRIENDLY and c.loop and dest_n.get_stock(SimTypes.ResourceType.AMMO) > 50.0:
					c.stop_loop()
					redirected_captured[c.id] = true
			if c.state == SimTypes.ConvoyState.IDLE and redirected_captured.get(c.id, false):
				if c.convoy_type == SimTypes.ConvoyType.CARGO:
					engine.dispatch_convoy(c.id, "front_n2", SimTypes.CargoPreference.AMMO, SimTypes.OrderMode.LOOP, true)
					redirected_captured[c.id] = false
		var kam: SimTypes.MapNode = engine.graph.get_node("junc_kamenka")
		if kam != null and kam.damaged and not sent_kam:
			var rc: Convoy = engine.dispatch_idle_from_node("rail_zapadnaya", "junc_kamenka", int(SimTypes.ConvoyType.ENGINEER), SimTypes.CargoPreference.PARTS, SimTypes.OrderMode.ONE_WAY_RETURN)
			if rc != null:
				sent_kam = true

	var stats: SimTypes.SimStats = engine.get_operation_stats()
	var sec_res: Array[Dictionary] = engine.evaluate_secondary_objectives()
	print("  Offensive stats: Hours=%.1f | Delivered=%.0fт | MinIntegrity=%.1f%%" % [stats.elapsed_hours, stats.total_delivered_tons, stats.min_sector_integrity])
	_assert_true(engine.result == SimTypes.GameResult.VICTORY, "Offensive operation achieved VICTORY")
	_assert_true(sec_res.size() == 2 and bool(sec_res[0].get("completed", false)) and bool(sec_res[1].get("completed", false)), "Both offensive secondary objectives completed")


func _test_breakthrough_120h_operation() -> void:
	print("\n--- Test 5: Operation 3 «Прорыв» (scenario_breakthrough_03.json, 120h) ---")
	var upgrades: Array[Dictionary] = CampaignData.load_upgrades_catalog()
	var mods: SimTypes.CampaignModifiers = CampaignData.build_modifiers([
		"extra_cargo", "extra_tanker", "extra_engineer", "extra_armored", "camo_nets", "heavy_suspension"
	], upgrades)
	var engine: SimEngine = SimEngine.new()
	_assert_true(engine.load_scenario(BREAKTHROUGH_SCENARIO, mods), "Loaded scenario_breakthrough_03.json with campaign upgrades")
	_assert_true(engine.graph.get_all_nodes().size() == 26, "Breakthrough has 26 nodes")
	_assert_true(engine.graph.get_nodes_by_type(SimTypes.NodeType.DEPOT).is_empty(), "Breakthrough starts with 0 pre-built forward depots")

	var deploy_sites: int = 0
	for n: SimTypes.MapNode in engine.graph.get_all_nodes():
		if n.can_deploy_depot:
			deploy_sites += 1
	_assert_true(deploy_sites == 5, "Breakthrough has 5 can_deploy_depot sites")

	# 1. Deploy 2 field depots right away with engineers
	engine.request_deploy_field_depot("site_lesnoye")
	engine.request_deploy_field_depot("site_klenovka")

	# 2. Initial dispatches: keep all 6 front sectors + artillery supplied using ONE_WAY_RETURN for dynamic routing & ARMORED on last mile
	engine.dispatch_idle_from_node("rail_glavnaya", "front_b1", int(SimTypes.ConvoyType.CARGO), SimTypes.CargoPreference.MIXED, SimTypes.OrderMode.ONE_WAY_RETURN, true, false)
	engine.dispatch_idle_from_node("rail_glavnaya", "front_b2", int(SimTypes.ConvoyType.CARGO), SimTypes.CargoPreference.EQUIPMENT, SimTypes.OrderMode.ONE_WAY_RETURN, false, false)
	engine.dispatch_idle_from_node("rail_glavnaya", "front_b3", int(SimTypes.ConvoyType.CARGO), SimTypes.CargoPreference.MIXED, SimTypes.OrderMode.ONE_WAY_RETURN, true, false)
	engine.dispatch_idle_from_node("rail_glavnaya", "front_b4", int(SimTypes.ConvoyType.CARGO), SimTypes.CargoPreference.MIXED, SimTypes.OrderMode.ONE_WAY_RETURN, true, false)

	engine.dispatch_idle_from_node("rail_glavnaya", "front_b1", int(SimTypes.ConvoyType.TANKER), SimTypes.CargoPreference.FUEL, SimTypes.OrderMode.ONE_WAY_RETURN, false, false)
	engine.dispatch_idle_from_node("rail_glavnaya", "front_b3", int(SimTypes.ConvoyType.TANKER), SimTypes.CargoPreference.FUEL, SimTypes.OrderMode.ONE_WAY_RETURN, false, false)
	engine.dispatch_idle_from_node("rail_glavnaya", "front_b5", int(SimTypes.ConvoyType.TANKER), SimTypes.CargoPreference.FUEL, SimTypes.OrderMode.ONE_WAY_RETURN, false, false)

	engine.dispatch_idle_from_node("rail_pereval", "front_b5", int(SimTypes.ConvoyType.ARMORED), SimTypes.CargoPreference.EQUIPMENT, SimTypes.OrderMode.ONE_WAY_RETURN, true, false)
	engine.dispatch_idle_from_node("rail_pereval", "front_b6", int(SimTypes.ConvoyType.ARMORED), SimTypes.CargoPreference.MIXED, SimTypes.OrderMode.ONE_WAY_RETURN, true, false)
	engine.dispatch_idle_from_node("rail_glavnaya", "front_b2", int(SimTypes.ConvoyType.ARMORED), SimTypes.CargoPreference.MIXED, SimTypes.OrderMode.ONE_WAY_RETURN, true, false)

	var eq_sent_b5: int = 1
	var bridge_sent: bool = false
	var eq_targets: Array[String] = ["front_b2", "front_b5", "front_b4", "front_b1"]
	var demined_objs: Dictionary[String, bool] = {}

	var total_ticks: int = engine.config.duration_hours * SimEngine.TICKS_PER_HOUR
	for _t: int in range(total_ticks):
		engine.step_tick()
		if engine.result != SimTypes.GameResult.RUNNING:
			break

		if not engine.is_inbound_train_locked():
			engine.set_train_target_railhead("rail_pereval" if engine.trains_arrived % 2 == 1 else "rail_glavnaya")
			if engine.units_modernized < 2 and not engine.has_equipment_platform_in_slots(engine.get_editable_train_slots()):
				engine.toggle_equipment_platform_order()
			if engine.truck_order_cooldown_ticks <= 0 and not engine.has_truck_convoy_in_slots(engine.get_editable_train_slots()):
				engine.set_truck_convoy_order(SimTypes.ConvoyType.ARMORED)

		# Send idle engineers to bridge repair or objective demining
		var sev_br: SimTypes.MapNode = engine.graph.get_node("junc_most_sev")
		if sev_br != null and sev_br.damaged and not bridge_sent:
			var rc: Convoy = engine.dispatch_idle_from_node("rail_glavnaya", "junc_most_sev", int(SimTypes.ConvoyType.ENGINEER), SimTypes.CargoPreference.PARTS, SimTypes.OrderMode.ONE_WAY_RETURN)
			if rc != null:
				bridge_sent = true

		for obj: SimTypes.MapNode in engine.graph.get_nodes_by_type(SimTypes.NodeType.OBJECTIVE):
			if obj.owner == SimTypes.Owner.FRIENDLY and not demined_objs.get(obj.id, false):
				var dc: Convoy = engine.dispatch_idle_from_node("rail_glavnaya", obj.id, int(SimTypes.ConvoyType.ENGINEER), SimTypes.CargoPreference.PARTS, SimTypes.OrderMode.ONE_WAY_RETURN)
				if dc != null:
					demined_objs[obj.id] = true

		# Reassign idle convoys cleanly using hub-and-spoke + ARMORED last mile
		for c: Convoy in engine.get_all_idle_convoys():
			if c.convoy_type == SimTypes.ConvoyType.CARGO:
				var gl_eq: float = engine.graph.get_node("rail_glavnaya").get_stock(SimTypes.ResourceType.EQUIPMENT)
				if c.current_node_id == "rail_glavnaya" and gl_eq >= 30.0 and engine.units_modernized < 2:
					var tgt_eq: String = ""
					for tid: String in eq_targets:
						var tn: SimTypes.MapNode = engine.graph.get_node(tid)
						if tn != null and tn.equipment_tier < 2 and tn.reequip_progress < 29.0:
							tgt_eq = tid
							break
					if not tgt_eq.is_empty():
						engine.dispatch_convoy(c.id, tgt_eq, SimTypes.CargoPreference.EQUIPMENT, SimTypes.OrderMode.ONE_WAY_RETURN, false, engine.phase == SimTypes.OperationPhase.OFFENSIVE)
						continue
				# Keep deployed field depots stocked safely 24/7 (max 1 inbound per depot)
				var les_n: SimTypes.MapNode = engine.graph.get_node("site_lesnoye")
				var kle_n: SimTypes.MapNode = engine.graph.get_node("site_klenovka")
				if c.current_node_id == "rail_glavnaya" and les_n != null and les_n.node_type == SimTypes.NodeType.FIELD_DEPOT and les_n.get_stock(SimTypes.ResourceType.AMMO) < 95.0 and _count_inbound(engine, "site_lesnoye", SimTypes.ConvoyType.CARGO) == 0:
					engine.dispatch_convoy(c.id, "site_lesnoye", SimTypes.CargoPreference.MIXED, SimTypes.OrderMode.ONE_WAY_RETURN, false, false)
					continue
				if c.current_node_id == "rail_glavnaya" and kle_n != null and kle_n.node_type == SimTypes.NodeType.FIELD_DEPOT and kle_n.get_stock(SimTypes.ResourceType.AMMO) < 95.0 and _count_inbound(engine, "site_klenovka", SimTypes.ConvoyType.CARGO) == 0:
					engine.dispatch_convoy(c.id, "site_klenovka", SimTypes.CargoPreference.MIXED, SimTypes.OrderMode.ONE_WAY_RETURN, false, false)
					continue
				# Top up artillery only if below 70t AMMO and no cargo already inbound
				var an: SimTypes.MapNode = engine.graph.get_node("arty_north")
				var as_n: SimTypes.MapNode = engine.graph.get_node("arty_south")
				if an != null and an.get_stock(SimTypes.ResourceType.AMMO) < 70.0 and _count_inbound(engine, "arty_north", SimTypes.ConvoyType.CARGO) == 0:
					engine.dispatch_convoy(c.id, "arty_north", SimTypes.CargoPreference.AMMO, SimTypes.OrderMode.ONE_WAY_RETURN, false, false)
					continue
				if as_n != null and as_n.get_stock(SimTypes.ResourceType.AMMO) < 70.0 and _count_inbound(engine, "arty_south", SimTypes.ConvoyType.CARGO) == 0:
					engine.dispatch_convoy(c.id, "arty_south", SimTypes.CargoPreference.AMMO, SimTypes.OrderMode.ONE_WAY_RETURN, false, false)
					continue
				var low_sec: String = _pick_neediest_sector(engine)
				var sn: SimTypes.MapNode = engine.graph.get_node(low_sec)
				var need_mix: bool = (sn == null or sn.get_stock(SimTypes.ResourceType.PROVISIONS) < 22.0 or sn.get_stock(SimTypes.ResourceType.PARTS) < 10.0)
				var pref: SimTypes.CargoPreference = SimTypes.CargoPreference.AMMO if (not need_mix and sn.get_stock(SimTypes.ResourceType.AMMO) < 55.0) else SimTypes.CargoPreference.MIXED
				var night_flag: bool = (c.hp < 65.0)
				engine.dispatch_convoy(c.id, low_sec, pref, SimTypes.OrderMode.ONE_WAY_RETURN, true, night_flag)
			elif c.convoy_type == SimTypes.ConvoyType.ARMORED:
				if c.current_node_id == "rail_pereval" and eq_sent_b5 < 3 and engine.graph.get_node("rail_pereval").get_stock(SimTypes.ResourceType.EQUIPMENT) >= 12.0:
					engine.dispatch_convoy(c.id, "front_b5", SimTypes.CargoPreference.EQUIPMENT, SimTypes.OrderMode.ONE_WAY_RETURN, true, false)
					eq_sent_b5 += 1
				else:
					# Stage ARMORED forward to FIELD_DEPOT if deployed and currently in rear
					var kle_a: SimTypes.MapNode = engine.graph.get_node("site_klenovka")
					if (c.current_node_id == "rail_glavnaya" or c.current_node_id == "rail_pereval") and kle_a != null and kle_a.node_type == SimTypes.NodeType.FIELD_DEPOT and kle_a.get_stock(SimTypes.ResourceType.AMMO) >= 40.0:
						engine.dispatch_convoy(c.id, "site_klenovka", SimTypes.CargoPreference.EMPTY, SimTypes.OrderMode.REDEPLOY, false, false)
						continue
					var low_sec_a: String = _pick_neediest_sector(engine)
					var sn_a: SimTypes.MapNode = engine.graph.get_node(low_sec_a)
					var need_mix_a: bool = (sn_a == null or sn_a.get_stock(SimTypes.ResourceType.PROVISIONS) < 18.0 or sn_a.get_stock(SimTypes.ResourceType.PARTS) < 8.0)
					var pref_a: SimTypes.CargoPreference = SimTypes.CargoPreference.AMMO if (not need_mix_a and sn_a.get_stock(SimTypes.ResourceType.AMMO) < 42.0) else SimTypes.CargoPreference.MIXED
					engine.dispatch_convoy(c.id, low_sec_a, pref_a, SimTypes.OrderMode.ONE_WAY_RETURN, true, false)
			elif c.convoy_type == SimTypes.ConvoyType.TANKER:
				var les_t: SimTypes.MapNode = engine.graph.get_node("site_lesnoye")
				if c.current_node_id == "rail_glavnaya" and les_t != null and les_t.node_type == SimTypes.NodeType.FIELD_DEPOT and les_t.get_stock(SimTypes.ResourceType.FUEL) < 80.0 and _count_inbound(engine, "site_lesnoye", SimTypes.ConvoyType.TANKER) == 0:
					engine.dispatch_convoy(c.id, "site_lesnoye", SimTypes.CargoPreference.FUEL, SimTypes.OrderMode.ONE_WAY_RETURN, false, false)
					continue
				var low_fuel_sec: String = _pick_lowest_fuel_sector(engine)
				var night_t: bool = (engine.phase == SimTypes.OperationPhase.OFFENSIVE and c.hp < 75.0)
				engine.dispatch_convoy(c.id, low_fuel_sec, SimTypes.CargoPreference.FUEL, SimTypes.OrderMode.ONE_WAY_RETURN, false, night_t)

	var stats: SimTypes.SimStats = engine.get_operation_stats()
	var sec_res: Array[Dictionary] = engine.evaluate_secondary_objectives()
	print("  Breakthrough stats: Hours=%.1f | Objectives=%d/3 | Modernized=%d | FieldDepots=%d | Disabled=%d | Delivered=%.0fт | Reason=%s" % [
		stats.elapsed_hours,
		stats.objectives_captured,
		stats.units_modernized,
		stats.field_depots_deployed,
		stats.convoys_disabled_count,
		stats.total_delivered_tons,
		engine.result_reason,
	])
	if engine.result != SimTypes.GameResult.VICTORY:
		for s_dbg: SimTypes.MapNode in engine.graph.get_nodes_by_type(SimTypes.NodeType.FRONT_SECTOR):
			var obj_dbg: SimTypes.MapNode = engine.graph.get_node(s_dbg.target_objective_id)
			print("    Sector %s: int=%.1f A=%.1f F=%.1f P=%.1f Pt=%.1f W=%.1f obj=%s(%d, %.0f%%)" % [
				s_dbg.id, s_dbg.integrity,
				s_dbg.get_stock(SimTypes.ResourceType.AMMO),
				s_dbg.get_stock(SimTypes.ResourceType.FUEL),
				s_dbg.get_stock(SimTypes.ResourceType.PROVISIONS),
				s_dbg.get_stock(SimTypes.ResourceType.PARTS),
				s_dbg.wounded,
				s_dbg.target_objective_id,
				obj_dbg.owner if obj_dbg != null else -1,
				obj_dbg.capture_progress if obj_dbg != null else 0.0,
			])
	_assert_true(engine.result == SimTypes.GameResult.VICTORY, "Operation 3 Прорыв achieved VICTORY")
	_assert_true(stats.units_modernized >= 2, "Modernized >= 2 units to Tier II (%d)" % stats.units_modernized)
	_assert_true(stats.field_depots_deployed >= 2, "Deployed >= 2 field depots (%d)" % stats.field_depots_deployed)
	_assert_true(sec_res.size() == 2, "Breakthrough evaluated 2 secondary objectives")


func _count_inbound(engine: SimEngine, node_id: String, convoy_type_filter: int = -1) -> int:
	var count: int = 0
	for c: Convoy in engine.convoys:
		if c.destination_node_id != node_id or c.is_returning:
			continue
		if c.state == SimTypes.ConvoyState.IDLE:
			continue
		if convoy_type_filter >= 0 and int(c.convoy_type) != convoy_type_filter:
			continue
		count += 1
	return count


func _pick_neediest_sector(engine: SimEngine) -> String:
	var best_id: String = "front_b2"
	var best_score: float = 999999.0
	for s: SimTypes.MapNode in engine.graph.get_nodes_by_type(SimTypes.NodeType.FRONT_SECTOR):
		var obj: SimTypes.MapNode = engine.graph.get_node(s.target_objective_id)
		var is_safe_captured: bool = (obj != null and obj.owner == SimTypes.Owner.FRIENDLY and s.integrity >= 75.0 and s.get_stock(SimTypes.ResourceType.AMMO) >= 15.0 and s.get_stock(SimTypes.ResourceType.PROVISIONS) >= 10.0)
		var captured_bonus: float = 40.0 if is_safe_captured else 0.0
		var critical_supply: float = minf(s.get_stock(SimTypes.ResourceType.AMMO), s.get_stock(SimTypes.ResourceType.PROVISIONS) * 3.0)
		var inbound_cargo: float = float(_count_inbound(engine, s.id, SimTypes.ConvoyType.CARGO) + _count_inbound(engine, s.id, SimTypes.ConvoyType.ARMORED)) * 22.0
		var low_int_penalty: float = -60.0 if s.integrity < 65.0 else 0.0
		var score: float = critical_supply + inbound_cargo + s.integrity * 0.4 + captured_bonus + low_int_penalty
		if score < best_score:
			best_score = score
			best_id = s.id
	return best_id


func _pick_lowest_fuel_sector(engine: SimEngine) -> String:
	var best_id: String = "front_b2"
	var best_fuel: float = 999999.0
	for s: SimTypes.MapNode in engine.graph.get_nodes_by_type(SimTypes.NodeType.FRONT_SECTOR):
		var obj: SimTypes.MapNode = engine.graph.get_node(s.target_objective_id)
		var is_safe_captured: bool = (obj != null and obj.owner == SimTypes.Owner.FRIENDLY and s.integrity >= 75.0 and s.get_stock(SimTypes.ResourceType.FUEL) >= 12.0)
		var captured_bonus: float = 40.0 if is_safe_captured else 0.0
		var inbound_fuel: float = float(_count_inbound(engine, s.id, SimTypes.ConvoyType.TANKER)) * 30.0
		var low_int_penalty: float = -30.0 if s.integrity < 65.0 else 0.0
		var score: float = s.get_stock(SimTypes.ResourceType.FUEL) + inbound_fuel + captured_bonus + low_int_penalty
		if score < best_fuel:
			best_fuel = score
			best_id = s.id
	return best_id


func _test_ui_scene_instantiation() -> void:
	print("\n--- Test 5: Smoke Instantiate All Shell & Battle Scenes ---")
	var scene_paths: Array[String] = [
		"res://scenes/main_menu.tscn",
		"res://scenes/settings_menu.tscn",
		"res://scenes/campaign_select.tscn",
		"res://scenes/campaign_hub.tscn",
		"res://scenes/main.tscn",
	]
	for sp: String in scene_paths:
		var packed: PackedScene = load(sp) as PackedScene
		_assert_true(packed != null, "Loaded scene: %s" % sp)
		if packed != null:
			var inst: Node = packed.instantiate()
			_assert_true(inst != null, "Instantiated scene: %s" % sp)
			if inst != null:
				inst.free()


func _assert_true(cond: bool, label: String) -> void:
	if not cond:
		_failures += 1
		printerr("  [FAIL] %s" % label)
	else:
		print("  [PASS] %s" % label)
