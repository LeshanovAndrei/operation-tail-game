extends SceneTree

const SCENARIO_PATH: String = "res://data/scenario_offensive.json"

var _failures: int = 0


func _initialize() -> void:
	print("=== Operation Rubezh / Stage 7 Headless Simulation Test ===")
	_test_stage5_mechanics()
	_test_stage7_mechanics()
	_test_full_120h_offensive()

	if _failures > 0:
		printerr("FAILED assertions: %d" % _failures)
		quit(1)
		return

	print("ALL STAGE 5 & STAGE 7 HEADLESS SIMULATION CHECKS PASSED.")
	quit(0)


func _test_stage5_mechanics() -> void:
	print("\n--- Test 1: JUNCTION Guardrails, Night-Only Mode, Camouflage & Signature Breakdown ---")
	var engine: SimEngine = SimEngine.new()
	_assert_true(engine.load_scenario(SCENARIO_PATH), "Loaded scenario_offensive.json")
	_assert_true(engine.convoys.size() == 14, "Has 14 starting convoys (+1 CARGO, +1 TANKER)")

	# 1. JUNCTION unload guardrail
	var val_bad: Dictionary = engine.validate_dispatch(
		"rail_zapadnaya", "junc_berezniki", SimTypes.ConvoyType.CARGO,
		SimTypes.CargoPreference.AMMO, SimTypes.OrderMode.ONE_WAY_RETURN
	)
	_assert_true(not bool(val_bad.get("ok", true)), "JUNCTION rejects regular AMMO supply")
	var bad_junc: Convoy = engine.dispatch_idle_from_node(
		"rail_zapadnaya", "junc_berezniki", int(SimTypes.ConvoyType.CARGO),
		SimTypes.CargoPreference.AMMO, SimTypes.OrderMode.ONE_WAY_RETURN
	)
	_assert_true(bad_junc == null, "dispatch_idle_from_node refuses AMMO to JUNCTION")

	var red_junc: Convoy = engine.dispatch_idle_from_node(
		"rail_zapadnaya", "junc_berezniki", int(SimTypes.ConvoyType.CARGO),
		SimTypes.CargoPreference.EMPTY, SimTypes.OrderMode.REDEPLOY
	)
	_assert_true(red_junc != null, "JUNCTION allows empty REDEPLOY staging")

	# 2. Night-only waiting mode (starts at 06:00, waits until 20:00 = 84 ticks)
	var night_c: Convoy = engine.dispatch_idle_from_node(
		"rail_zapadnaya", "depot_sosnovka", int(SimTypes.ConvoyType.CARGO),
		SimTypes.CargoPreference.AMMO, SimTypes.OrderMode.ONE_WAY_RETURN, false, true
	)
	_assert_true(night_c != null, "Dispatched night-only convoy at 06:00")
	for _t: int in range(6):
		engine.step_tick()
	_assert_true(night_c.is_waiting_night and night_c.state == SimTypes.ConvoyState.LOADING, "Night-only convoy waits at origin during daytime")

	# Advance to 20:00 (tick 84)
	while engine.current_tick < 85:
		engine.step_tick()
	_assert_true(not night_c.is_waiting_night and night_c.state == SimTypes.ConvoyState.MOVING, "Night-only convoy departed at nightfall (20:00)")

	# Live edit route toggle
	_assert_true(engine.toggle_convoy_night_only(night_c.id) and not night_c.night_only, "Live-toggled night_only off on active convoy")
	_assert_true(engine.toggle_convoy_evac_wounded(night_c.id) and night_c.evacuate_wounded, "Live-toggled evac_wounded on active convoy")

	# 3. Camouflage effect on signature & load time
	var eng2: SimEngine = SimEngine.new()
	eng2.load_scenario(SCENARIO_PATH)
	_assert_true(eng2.toggle_node_camouflage("depot_sosnovka"), "Enabled camouflage on depot_sosnovka")
	var sos: SimTypes.MapNode = eng2.graph.get_node("depot_sosnovka")
	var rud: SimTypes.MapNode = eng2.graph.get_node("depot_rudnoye")
	sos.signature = 30.0
	rud.signature = 30.0
	for _k: int in range(24):
		eng2.step_tick()
	_assert_true(sos.signature < rud.signature, "Camouflaged depot cools faster / gains less signature (%.1f < %.1f)" % [sos.signature, rud.signature])

	var bd: Dictionary = eng2.get_signature_rate_breakdown("depot_sosnovka")
	_assert_true(bd.has("net_per_h") and bd.has("decay_per_h"), "Signature breakdown exposes per-hour rates")


func _test_stage7_mechanics() -> void:
	print("\n--- Test 1B: Stage 7 Mechanics (Interdiction, Field Depots, Re-Equipment) ---")
	var bt_path: String = "res://data/scenario_breakthrough_03.json"

	# 1. Field depot deployment and packing
	var eng_dep: SimEngine = SimEngine.new()
	_assert_true(eng_dep.load_scenario(bt_path), "Loaded scenario_breakthrough_03.json for Stage 7 unit tests")
	var dep_res: Dictionary = eng_dep.request_deploy_field_depot("site_lesnoye")
	_assert_true(bool(dep_res.get("ok", false)) and not str(dep_res.get("dispatched_callsign", "")).is_empty(), "Auto-dispatched engineer to deploy FIELD_DEPOT at site_lesnoye")

	var les: SimTypes.MapNode = eng_dep.graph.get_node("site_lesnoye")
	for _t: int in range(60):
		eng_dep.step_tick()
		if les.node_type == SimTypes.NodeType.FIELD_DEPOT:
			break
	_assert_true(les.node_type == SimTypes.NodeType.FIELD_DEPOT, "site_lesnoye transformed into FIELD_DEPOT")
	_assert_true(is_equal_approx(les.get_capacity(SimTypes.ResourceType.FUEL), 180.0), "FIELD_DEPOT has 180t FUEL capacity")
	_assert_true(is_equal_approx(les.signature_mult, 0.75) and les.is_vulnerable, "FIELD_DEPOT has -25%% base signature multiplier")

	_assert_true(eng_dep.request_pack_field_depot("site_lesnoye"), "Requested pack of FIELD_DEPOT")
	for _t2: int in range(24):
		eng_dep.step_tick()
		if les.node_type == SimTypes.NodeType.JUNCTION:
			break
	_assert_true(les.node_type == SimTypes.NodeType.JUNCTION and les.can_deploy_depot, "Packed FIELD_DEPOT reverted cleanly to JUNCTION staging site")

	# 2. Equipment train platform & battalion Tier II modernization
	var eng_eq: SimEngine = SimEngine.new()
	_assert_true(eng_eq.load_scenario(bt_path), "Loaded scenario_breakthrough_03.json for EQUIPMENT test")
	_assert_true(eng_eq.toggle_equipment_platform_order(), "Added EQUIPMENT_PLATFORM (2 slots) to train")
	_assert_true(eng_eq.has_equipment_platform_in_slots(eng_eq.get_editable_train_slots()), "Editable train slots contain EQUIPMENT_PLATFORM")

	var gl_node: SimTypes.MapNode = eng_eq.graph.get_node("rail_glavnaya")
	var prev_eq: float = gl_node.get_stock(SimTypes.ResourceType.EQUIPMENT)
	for _t3: int in range(48):
		eng_eq.step_tick()
	_assert_true(gl_node.get_stock(SimTypes.ResourceType.EQUIPMENT) >= prev_eq + 29.0, "Train delivered +30t EQUIPMENT platform")

	var eq_conv: Convoy = eng_eq.dispatch_idle_from_node(
		"rail_glavnaya", "front_b1", int(SimTypes.ConvoyType.CARGO),
		SimTypes.CargoPreference.EQUIPMENT, SimTypes.OrderMode.ONE_WAY_RETURN
	)
	_assert_true(eq_conv != null, "Dispatched CARGO convoy with EQUIPMENT to front_b1")
	var fb1: SimTypes.MapNode = eng_eq.graph.get_node("front_b1")
	for _t4: int in range(90):
		eng_eq.step_tick()
		if fb1.equipment_tier >= 2:
			break
	_assert_true(fb1.equipment_tier == 2 and eng_eq.units_modernized >= 1, "front_b1 modernized to Equipment Tier II after 30t + 3h")

	# 3. Frontline road danger: CARGO takes heavier damage than ARMORED
	var eng_hit: SimEngine = SimEngine.new()
	_assert_true(eng_hit.load_scenario(bt_path), "Loaded scenario_breakthrough_03.json for interdiction test")
	eng_hit.config.waves.clear()
	eng_hit.graph.get_node("front_b2").intensity = SimTypes.Intensity.HIGH
	eng_hit.graph.get_node("front_b5").intensity = SimTypes.Intensity.HIGH
	var cargo_c: Convoy = eng_hit.dispatch_idle_from_node(
		"rail_glavnaya", "front_b2", int(SimTypes.ConvoyType.CARGO),
		SimTypes.CargoPreference.AMMO, SimTypes.OrderMode.LOOP
	)
	var cargo_c2: Convoy = eng_hit.dispatch_idle_from_node(
		"rail_glavnaya", "front_b2", int(SimTypes.ConvoyType.CARGO),
		SimTypes.CargoPreference.MIXED, SimTypes.OrderMode.LOOP
	)
	var arm_c: Convoy = eng_hit.dispatch_idle_from_node(
		"rail_pereval", "front_b5", int(SimTypes.ConvoyType.ARMORED),
		SimTypes.CargoPreference.AMMO, SimTypes.OrderMode.LOOP
	)
	_assert_true(cargo_c != null and cargo_c2 != null and arm_c != null, "Dispatched CARGO and ARMORED onto frontline_danger routes")
	var min_cargo_hp: float = 100.0
	var min_arm_hp: float = 100.0
	for _t5: int in range(220):
		eng_hit.step_tick()
		min_cargo_hp = minf(min_cargo_hp, minf(cargo_c.hp, cargo_c2.hp))
		min_arm_hp = minf(min_arm_hp, arm_c.hp)
	_assert_true(min_cargo_hp < 80.0 and eng_hit.convoys_damaged_hits > 0, "Unarmored CARGO suffered artillery interdiction on danger road (min HP=%.1f%%)" % min_cargo_hp)
	_assert_true(min_arm_hp >= 85.0, "ARMORED retained >= 85%% HP on danger road (min HP=%.1f%%)" % min_arm_hp)


func _test_full_120h_offensive() -> void:
	print("\n--- Test 2: Full 120h 2-Phase Offensive Simulation (Rebalanced Economy) ---")
	var engine: SimEngine = SimEngine.new()
	_assert_true(engine.load_scenario(SCENARIO_PATH), "Loaded scenario_offensive.json for 120h run")
	_assert_true(engine.set_truck_convoy_order(SimTypes.ConvoyType.CARGO), "Ordered extra CARGO convoy via train")

	# Enable camouflage on busy central forward depots
	engine.toggle_node_camouflage("depot_lipki")
	engine.toggle_node_camouflage("depot_krasny_yar")

	# Dispatch initial 14 convoys cleanly across all 6 front sectors + artillery
	engine.dispatch_idle_from_node("rail_zapadnaya", "front_n1", int(SimTypes.ConvoyType.CARGO), SimTypes.CargoPreference.MIXED, SimTypes.OrderMode.LOOP, true)
	engine.dispatch_idle_from_node("rail_zapadnaya", "front_n2", int(SimTypes.ConvoyType.CARGO), SimTypes.CargoPreference.MIXED, SimTypes.OrderMode.LOOP, true)
	engine.dispatch_idle_from_node("rail_zapadnaya", "front_n3", int(SimTypes.ConvoyType.CARGO), SimTypes.CargoPreference.MIXED, SimTypes.OrderMode.LOOP, true)
	engine.dispatch_idle_from_node("rail_zapadnaya", "front_s2", int(SimTypes.ConvoyType.CARGO), SimTypes.CargoPreference.MIXED, SimTypes.OrderMode.LOOP, true)
	engine.dispatch_idle_from_node("rail_zapadnaya", "front_s3", int(SimTypes.ConvoyType.CARGO), SimTypes.CargoPreference.MIXED, SimTypes.OrderMode.LOOP, true)
	engine.dispatch_idle_from_node("rail_zapadnaya", "arty_north", int(SimTypes.ConvoyType.CARGO), SimTypes.CargoPreference.AMMO, SimTypes.OrderMode.LOOP, false)

	engine.dispatch_idle_from_node("rail_zapadnaya", "front_n1", int(SimTypes.ConvoyType.TANKER), SimTypes.CargoPreference.FUEL, SimTypes.OrderMode.LOOP, false)
	engine.dispatch_idle_from_node("rail_zapadnaya", "front_n2", int(SimTypes.ConvoyType.TANKER), SimTypes.CargoPreference.FUEL, SimTypes.OrderMode.LOOP, false)
	engine.dispatch_idle_from_node("rail_zapadnaya", "front_s2", int(SimTypes.ConvoyType.TANKER), SimTypes.CargoPreference.FUEL, SimTypes.OrderMode.LOOP, false)
	engine.dispatch_idle_from_node("rail_zapadnaya", "front_s3", int(SimTypes.ConvoyType.TANKER), SimTypes.CargoPreference.FUEL, SimTypes.OrderMode.LOOP, false)

	engine.dispatch_idle_from_node("rail_uzlovaya", "front_s1", int(SimTypes.ConvoyType.CARGO), SimTypes.CargoPreference.MIXED, SimTypes.OrderMode.LOOP, true)
	engine.dispatch_idle_from_node("rail_uzlovaya", "front_s1", int(SimTypes.ConvoyType.TANKER), SimTypes.CargoPreference.FUEL, SimTypes.OrderMode.LOOP, false)

	# 1 engineer maintains front_n2, 1 stays at rail_zapadnaya for Kamenka bridge
	engine.dispatch_idle_from_node("rail_zapadnaya", "front_n2", int(SimTypes.ConvoyType.ENGINEER), SimTypes.CargoPreference.PARTS, SimTypes.OrderMode.LOOP, false)

	var sent_kamenka_repair: bool = false
	var sent_arty_south: bool = false
	var demine_dispatched: Dictionary[String, bool] = {}
	var redirected_captured: Dictionary[String, bool] = {}

	var total_ticks: int = engine.config.duration_hours * SimEngine.TICKS_PER_HOUR
	for _t: int in range(total_ticks):
		engine.step_tick()
		if engine.result != SimTypes.GameResult.RUNNING:
			break

		if not engine.is_inbound_train_locked():
			var want_target: String = "rail_uzlovaya" if engine.trains_arrived % 2 == 1 else "rail_zapadnaya"
			engine.set_train_target_railhead(want_target)

		# Switch north cargo convoys to AMMO if front sector is low on AMMO during offensive
		if engine.phase == SimTypes.OperationPhase.OFFENSIVE:
			for c: Convoy in engine.convoys:
				if c.convoy_type == SimTypes.ConvoyType.CARGO and c.destination_node_id in ["front_n1", "front_n2"]:
					var fn: SimTypes.MapNode = engine.graph.get_node(c.destination_node_id)
					if fn != null and fn.get_stock(SimTypes.ResourceType.PROVISIONS) < 15.0:
						c.set_cargo_preference(SimTypes.CargoPreference.MIXED)
					elif fn != null and fn.get_stock(SimTypes.ResourceType.AMMO) < 40.0:
						c.set_cargo_preference(SimTypes.CargoPreference.AMMO)

		# Redirect southern cargo convoys once their objective is captured and they have reserve
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
		if kam != null and kam.damaged and not sent_kamenka_repair:
			var rc: Convoy = engine.dispatch_idle_from_node(
				"rail_zapadnaya", "junc_kamenka", int(SimTypes.ConvoyType.ENGINEER),
				SimTypes.CargoPreference.PARTS, SimTypes.OrderMode.ONE_WAY_RETURN
			)
			if rc != null:
				sent_kamenka_repair = true

		if not sent_arty_south and engine.convoys_spawned_by_train >= 1:
			var ac: Convoy = engine.dispatch_idle_from_node(
				"rail_zapadnaya", "arty_south", int(SimTypes.ConvoyType.CARGO),
				SimTypes.CargoPreference.AMMO, SimTypes.OrderMode.LOOP, false
			)
			if ac == null:
				ac = engine.dispatch_idle_from_node(
					"rail_uzlovaya", "arty_south", int(SimTypes.ConvoyType.CARGO),
					SimTypes.CargoPreference.AMMO, SimTypes.OrderMode.LOOP, false
				)
			if ac != null:
				sent_arty_south = true

		for obj: SimTypes.MapNode in engine.graph.get_nodes_by_type(SimTypes.NodeType.OBJECTIVE):
			if obj.owner == SimTypes.Owner.FRIENDLY and not demine_dispatched.get(obj.id, false):
				var dc: Convoy = engine.dispatch_idle_from_node(
					"rail_zapadnaya", obj.id, int(SimTypes.ConvoyType.ENGINEER),
					SimTypes.CargoPreference.PARTS, SimTypes.OrderMode.ONE_WAY_RETURN
				)
				if dc != null:
					demine_dispatched[obj.id] = true

	for sec: SimTypes.MapNode in engine.graph.get_nodes_by_type(SimTypes.NodeType.FRONT_SECTOR):
		print("  %s: integrity=%.1f%%, FUEL=%.1f, AMMO=%.1f, PROV=%.1f" % [
			sec.id, sec.integrity,
			sec.get_stock(SimTypes.ResourceType.FUEL),
			sec.get_stock(SimTypes.ResourceType.AMMO),
			sec.get_stock(SimTypes.ResourceType.PROVISIONS),
		])
		_assert_true(sec.integrity > 0.0, "%s survived operation" % sec.id)

	print("  Tick=%d (%.1fh) | Phase1Ready=%.0f%% | Objectives=%d/3 | Demined=%d | BridgesRepaired=%d | Convoys=%d | Events=%d" % [
		engine.current_tick,
		engine.get_elapsed_hours(),
		engine.phase1_readiness_achieved * 100.0,
		engine.objectives_captured,
		engine.roads_demined,
		engine.bridges_repaired,
		engine.convoys.size(),
		engine.event_log.size(),
	])
	print("  Result: %s" % engine.result_reason)

	_assert_true(engine.phase == SimTypes.OperationPhase.OFFENSIVE, "Transitioned to Phase 2 OFFENSIVE")
	_assert_true(engine.phase1_readiness_achieved >= 0.85, "Phase 1 buildup achieved >= 85% readiness")
	_assert_true(engine.result == SimTypes.GameResult.VICTORY, "Achieved VICTORY")
	_assert_true(engine.bridges_repaired >= 1, "Repaired damaged Kamenka bridge")
	_assert_true(engine.roads_demined >= 1, "Demined approach roads")
	_assert_true(engine.convoys_spawned_by_train >= 1, "Train requisition spawned extra convoy")


func _assert_true(cond: bool, label: String) -> void:
	if not cond:
		_failures += 1
		printerr("  [FAIL] %s" % label)
	else:
		print("  [PASS] %s" % label)
