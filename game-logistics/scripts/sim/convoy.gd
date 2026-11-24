class_name Convoy
extends RefCounted

var id: String = ""
var callsign: String = ""
var convoy_type: SimTypes.ConvoyType = SimTypes.ConvoyType.CARGO

var cargo_capacity: float = 30.0
var fuel_tank_capacity: float = 7.0
var fuel_tank: float = 7.0
var fuel_burn_per_km: float = 0.008
var load_time_ticks: int = 2

var state: SimTypes.ConvoyState = SimTypes.ConvoyState.IDLE
var order_mode: SimTypes.OrderMode = SimTypes.OrderMode.LOOP
var current_node_id: String = ""
var origin_node_id: String = ""
var destination_node_id: String = ""
var cargo_preference: SimTypes.CargoPreference = SimTypes.CargoPreference.MIXED
var cargo: Dictionary[SimTypes.ResourceType, float] = {
	SimTypes.ResourceType.FUEL: 0.0,
	SimTypes.ResourceType.AMMO: 0.0,
	SimTypes.ResourceType.PROVISIONS: 0.0,
	SimTypes.ResourceType.PARTS: 0.0,
	SimTypes.ResourceType.EQUIPMENT: 0.0,
}

var hp: float = 100.0
var max_hp: float = 100.0
var disabled_ticks_remaining: int = 0

var loop: bool = false
var evacuate_wounded: bool = false
var night_only: bool = false
var is_waiting_night: bool = false
var is_returning: bool = false
var is_queued: bool = false
var route_nodes: Array[String] = []
var route_segment_index: int = 0
var segment_progress_km: float = 0.0
var action_ticks_remaining: int = 0

var carried_wounded: float = 0.0
var _wounded_loaded_this_trip: bool = false

var total_delivered: Dictionary[SimTypes.ResourceType, float] = {
	SimTypes.ResourceType.FUEL: 0.0,
	SimTypes.ResourceType.AMMO: 0.0,
	SimTypes.ResourceType.PROVISIONS: 0.0,
	SimTypes.ResourceType.PARTS: 0.0,
	SimTypes.ResourceType.EQUIPMENT: 0.0,
}
var total_fuel_burned: float = 0.0
var total_distance_km: float = 0.0
var total_wounded_evacuated: float = 0.0
var trips_completed: int = 0


func is_disabled() -> bool:
	return disabled_ticks_remaining > 0


func configure_for_type(ctype: SimTypes.ConvoyType, base_fuel_tank: float, base_burn: float, base_load_ticks: int) -> void:
	convoy_type = ctype
	fuel_tank_capacity = base_fuel_tank
	fuel_tank = base_fuel_tank
	fuel_burn_per_km = base_burn
	hp = 100.0
	max_hp = 100.0
	disabled_ticks_remaining = 0
	match ctype:
		SimTypes.ConvoyType.CARGO:
			cargo_capacity = 30.0
			load_time_ticks = maxi(1, base_load_ticks)
		SimTypes.ConvoyType.TANKER:
			cargo_capacity = 40.0
			load_time_ticks = 1
		SimTypes.ConvoyType.ENGINEER:
			cargo_capacity = 26.0
			load_time_ticks = maxi(1, base_load_ticks)
		SimTypes.ConvoyType.ARMORED:
			cargo_capacity = 12.0
			load_time_ticks = 1


func can_accept_cargo_pref(pref: SimTypes.CargoPreference) -> bool:
	if pref == SimTypes.CargoPreference.EMPTY:
		return true
	match convoy_type:
		SimTypes.ConvoyType.TANKER:
			return pref == SimTypes.CargoPreference.FUEL or pref == SimTypes.CargoPreference.MIXED
		SimTypes.ConvoyType.ENGINEER:
			return pref == SimTypes.CargoPreference.PARTS or pref == SimTypes.CargoPreference.EQUIPMENT or pref == SimTypes.CargoPreference.MIXED
		SimTypes.ConvoyType.CARGO, SimTypes.ConvoyType.ARMORED:
			return true
	return true


func assign_order(
	dest_id: String,
	pref: SimTypes.CargoPreference,
	mode: SimTypes.OrderMode,
	graph: WorldGraph,
	weather: SimTypes.Weather = SimTypes.Weather.CLEAR,
	evac_wounded: bool = false,
	is_night_only: bool = false
) -> bool:
	if state != SimTypes.ConvoyState.IDLE or is_disabled():
		return false
	if current_node_id.is_empty() or dest_id == current_node_id:
		return false
	if mode != SimTypes.OrderMode.REDEPLOY and not can_accept_cargo_pref(pref):
		return false

	var dest_node: SimTypes.MapNode = graph.get_node(dest_id)
	if dest_node == null or dest_node.owner != SimTypes.Owner.FRIENDLY:
		return false

	# JUNCTION guardrail: no regular supply deliveries; only REDEPLOY or ENGINEER with PARTS for damaged bridge/roads
	if dest_node.node_type == SimTypes.NodeType.JUNCTION and mode != SimTypes.OrderMode.REDEPLOY:
		var is_eng_parts: bool = (
			convoy_type == SimTypes.ConvoyType.ENGINEER
			and (pref == SimTypes.CargoPreference.PARTS or pref == SimTypes.CargoPreference.MIXED)
		)
		if not is_eng_parts or not graph.junction_needs_engineer(dest_id):
			return false

	var path: Array[String] = graph.find_path(current_node_id, dest_id, weather, convoy_type)
	if path.size() < 2:
		return false

	origin_node_id = current_node_id
	destination_node_id = dest_id
	order_mode = mode
	loop = (mode == SimTypes.OrderMode.LOOP)
	evacuate_wounded = evac_wounded
	night_only = is_night_only
	is_waiting_night = false
	is_returning = false
	is_queued = false
	_wounded_loaded_this_trip = false

	if mode == SimTypes.OrderMode.REDEPLOY:
		cargo_preference = SimTypes.CargoPreference.EMPTY
		if night_only:
			route_nodes.clear()
			route_segment_index = 0
			segment_progress_km = 0.0
			state = SimTypes.ConvoyState.LOADING
			action_ticks_remaining = 0
			is_waiting_night = true
			return true
		route_nodes = path
		route_segment_index = 0
		segment_progress_km = 0.0
		state = SimTypes.ConvoyState.MOVING
		action_ticks_remaining = 0
		return true

	cargo_preference = pref
	route_nodes.clear()
	route_segment_index = 0
	segment_progress_km = 0.0
	state = SimTypes.ConvoyState.LOADING
	action_ticks_remaining = _get_effective_load_ticks(graph.get_node(current_node_id))
	return true


func set_cargo_preference(pref: SimTypes.CargoPreference) -> bool:
	if not can_accept_cargo_pref(pref):
		return false
	cargo_preference = pref
	return true


func set_night_only(enabled: bool) -> void:
	night_only = enabled
	if not enabled:
		is_waiting_night = false


func set_evacuate_wounded(enabled: bool) -> void:
	evacuate_wounded = enabled


func stop_loop() -> void:
	loop = false
	if order_mode == SimTypes.OrderMode.LOOP:
		order_mode = SimTypes.OrderMode.ONE_WAY_RETURN


func get_total_cargo() -> float:
	var total: float = 0.0
	for res: SimTypes.ResourceType in SimTypes.all_resources():
		total += cargo.get(res, 0.0)
	return total


func get_cargo_amount(res: SimTypes.ResourceType) -> float:
	return cargo.get(res, 0.0)


func get_world_position(graph: WorldGraph) -> Vector2:
	if state == SimTypes.ConvoyState.MOVING and route_segment_index >= 0 and route_segment_index < route_nodes.size() - 1:
		var from_id: String = route_nodes[route_segment_index]
		var to_id: String = route_nodes[route_segment_index + 1]
		var node_a: SimTypes.MapNode = graph.get_node(from_id)
		var node_b: SimTypes.MapNode = graph.get_node(to_id)
		var edge: SimTypes.RoadEdge = graph.get_edge_between(from_id, to_id)
		if node_a != null and node_b != null and edge != null and edge.distance_km > 0.0:
			var t: float = clampf(segment_progress_km / edge.distance_km, 0.0, 1.0)
			return node_a.position.lerp(node_b.position, t)
	var cur_node: SimTypes.MapNode = graph.get_node(current_node_id)
	if cur_node != null:
		return cur_node.position
	return Vector2.ZERO


func get_heading_vector(graph: WorldGraph) -> Vector2:
	if state == SimTypes.ConvoyState.MOVING and route_segment_index >= 0 and route_segment_index < route_nodes.size() - 1:
		var node_a: SimTypes.MapNode = graph.get_node(route_nodes[route_segment_index])
		var node_b: SimTypes.MapNode = graph.get_node(route_nodes[route_segment_index + 1])
		if node_a != null and node_b != null:
			var dir: Vector2 = node_b.position - node_a.position
			if dir.length_squared() > 0.001:
				return dir.normalized()
	return Vector2.RIGHT


func step_tick(
	graph: WorldGraph,
	is_night: bool,
	tick_hours: float,
	weather: SimTypes.Weather = SimTypes.Weather.CLEAR,
	can_use_slot: bool = true
) -> Dictionary:
	var visited_vulns: Array[String] = []
	var demined_edges: Array[String] = []
	var traversed_danger_edges: Array[String] = []
	var queued_at: String = ""
	var recovered_from_repair: bool = false
	is_queued = false

	if disabled_ticks_remaining > 0:
		disabled_ticks_remaining -= 1
		if disabled_ticks_remaining == 0:
			hp = max_hp
			recovered_from_repair = true
		return {
			"visited_vulns": visited_vulns,
			"demined_edges": demined_edges,
			"traversed_danger_edges": traversed_danger_edges,
			"queued_at": queued_at,
			"recovered_from_repair": recovered_from_repair,
		}

	match state:
		SimTypes.ConvoyState.IDLE:
			is_waiting_night = false
			var idle_n: SimTypes.MapNode = graph.get_node(current_node_id)
			_refuel_at_node(idle_n)
			_repair_at_node(idle_n)
		SimTypes.ConvoyState.LOADING:
			_repair_at_node(graph.get_node(current_node_id))
			if can_use_slot:
				_step_loading(graph, is_night, weather, visited_vulns)
			else:
				is_queued = true
				queued_at = current_node_id
		SimTypes.ConvoyState.MOVING:
			is_waiting_night = false
			_step_moving(graph, is_night, tick_hours, weather, visited_vulns, demined_edges, traversed_danger_edges)
		SimTypes.ConvoyState.UNLOADING:
			_repair_at_node(graph.get_node(current_node_id))
			if can_use_slot:
				_step_unloading(graph, is_night, weather, visited_vulns, demined_edges)
			else:
				is_queued = true
				queued_at = current_node_id

	return {
		"visited_vulns": visited_vulns,
		"demined_edges": demined_edges,
		"traversed_danger_edges": traversed_danger_edges,
		"queued_at": queued_at,
		"recovered_from_repair": recovered_from_repair,
	}


func apply_artillery_hit(dmg: float, cargo_loss_ratio: float) -> Dictionary:
	var prev_hp: float = hp
	hp = maxf(0.0, hp - dmg)
	var lost_tons: float = 0.0
	if cargo_loss_ratio > 0.0:
		for res: SimTypes.ResourceType in SimTypes.all_resources():
			var amt: float = cargo.get(res, 0.0)
			if amt > 0.0:
				var lost: float = amt * clampf(cargo_loss_ratio, 0.0, 1.0)
				cargo[res] = amt - lost
				lost_tons += lost
	return {
		"hp_lost": prev_hp - hp,
		"cargo_lost": lost_tons,
	}


func _repair_at_node(node: SimTypes.MapNode) -> void:
	if node == null or hp >= max_hp - 0.01:
		return
	if node.node_type == SimTypes.NodeType.RAILHEAD:
		hp = minf(max_hp, hp + 12.0)
	elif node.node_type == SimTypes.NodeType.DEPOT or node.node_type == SimTypes.NodeType.FIELD_DEPOT:
		if node.take_stock(SimTypes.ResourceType.PARTS, 0.5) >= 0.25:
			hp = minf(max_hp, hp + 8.0)


func _get_effective_load_ticks(node: SimTypes.MapNode) -> int:
	var base_t: int = maxi(1, load_time_ticks)
	if node != null and node.camouflaged:
		return int(ceil(float(base_t) * 1.4))
	return base_t


func _step_loading(graph: WorldGraph, is_night: bool, weather: SimTypes.Weather, visited_vulns: Array[String]) -> void:
	var node: SimTypes.MapNode = graph.get_node(current_node_id)
	if node == null:
		state = SimTypes.ConvoyState.IDLE
		return
	_refuel_at_node(node)
	_offload_wounded_at_node(node)

	if action_ticks_remaining > 0:
		action_ticks_remaining -= 1
	if action_ticks_remaining > 0:
		return

	if order_mode != SimTypes.OrderMode.REDEPLOY:
		_load_cargo_from_node(node)
		if order_mode == SimTypes.OrderMode.LOOP and get_total_cargo() < 0.5:
			action_ticks_remaining = 1
			return

	if night_only and not is_night:
		is_waiting_night = true
		action_ticks_remaining = 0
		return
	is_waiting_night = false

	var path: Array[String] = graph.find_path(current_node_id, destination_node_id, weather, convoy_type)
	if path.size() < 2:
		state = SimTypes.ConvoyState.IDLE
		return

	route_nodes = path
	route_segment_index = 0
	segment_progress_km = 0.0
	is_returning = false
	_wounded_loaded_this_trip = false
	state = SimTypes.ConvoyState.MOVING
	_record_vuln_visit(node, visited_vulns)


func _step_moving(
	graph: WorldGraph,
	is_night: bool,
	tick_hours: float,
	weather: SimTypes.Weather,
	visited_vulns: Array[String],
	demined_edges: Array[String],
	traversed_danger_edges: Array[String]
) -> void:
	var remaining_hours: float = tick_hours
	var safety_iters: int = 0
	var is_redeploy: bool = (order_mode == SimTypes.OrderMode.REDEPLOY)

	while remaining_hours > 0.0001 and safety_iters < 16:
		safety_iters += 1
		if route_segment_index >= route_nodes.size() - 1:
			_finish_leg(graph)
			return

		var from_id: String = route_nodes[route_segment_index]
		var to_id: String = route_nodes[route_segment_index + 1]
		var edge: SimTypes.RoadEdge = graph.get_edge_between(from_id, to_id)
		if edge == null:
			state = SimTypes.ConvoyState.IDLE
			return

		if edge.frontline_danger and not traversed_danger_edges.has(edge.id):
			traversed_danger_edges.append(edge.id)

		if convoy_type == SimTypes.ConvoyType.ENGINEER:
			if edge.mined and graph.is_edge_passable(edge):
				edge.mined = false
				if not demined_edges.has(edge.id):
					demined_edges.append(edge.id)
			if edge.wear > 0.25 and get_cargo_amount(SimTypes.ResourceType.PARTS) >= 2.0:
				cargo[SimTypes.ResourceType.PARTS] = get_cargo_amount(SimTypes.ResourceType.PARTS) - 2.0
				edge.wear = maxf(0.0, edge.wear - 0.50)

		var speed_kmh: float = graph.get_edge_effective_speed_kmh(edge, weather, convoy_type)
		if is_redeploy:
			speed_kmh *= 1.25
		if is_night:
			speed_kmh *= 0.75
		if fuel_tank <= 0.0001:
			speed_kmh *= 0.15

		var dist_remaining_on_edge: float = maxf(0.0, edge.distance_km - segment_progress_km)
		var max_dist_this_step: float = speed_kmh * remaining_hours

		if max_dist_this_step < dist_remaining_on_edge:
			_consume_travel(graph, edge, max_dist_this_step, weather, is_redeploy)
			segment_progress_km += max_dist_this_step
			remaining_hours = 0.0
		else:
			_consume_travel(graph, edge, dist_remaining_on_edge, weather, is_redeploy)
			var time_used: float = dist_remaining_on_edge / maxf(0.01, speed_kmh)
			remaining_hours = maxf(0.0, remaining_hours - time_used)
			route_segment_index += 1
			segment_progress_km = 0.0
			current_node_id = to_id

			var arrived_node: SimTypes.MapNode = graph.get_node(current_node_id)
			_refuel_at_node(arrived_node)
			_record_vuln_visit(arrived_node, visited_vulns)

			if route_segment_index >= route_nodes.size() - 1:
				_finish_leg(graph)
				return


func _step_unloading(
	graph: WorldGraph,
	is_night: bool,
	weather: SimTypes.Weather,
	visited_vulns: Array[String],
	demined_edges: Array[String]
) -> void:
	var node: SimTypes.MapNode = graph.get_node(current_node_id)
	if node == null:
		state = SimTypes.ConvoyState.IDLE
		return
	_refuel_at_node(node)

	if action_ticks_remaining > 0:
		action_ticks_remaining -= 1
	if action_ticks_remaining > 0:
		return

	_unload_cargo_to_node(node)

	if convoy_type == SimTypes.ConvoyType.ENGINEER:
		for edge: SimTypes.RoadEdge in graph.get_edges_for(node.id):
			if edge.mined and graph.is_edge_passable(edge):
				edge.mined = false
				if not demined_edges.has(edge.id):
					demined_edges.append(edge.id)

	if evacuate_wounded and not _wounded_loaded_this_trip and node.node_type == SimTypes.NodeType.FRONT_SECTOR and node.wounded >= 1.0:
		var pickup: float = minf(16.0, node.wounded)
		node.wounded -= pickup
		carried_wounded += pickup
		_wounded_loaded_this_trip = true
		action_ticks_remaining = 1 if convoy_type == SimTypes.ConvoyType.ARMORED else 2
		return

	var should_return: bool = (
		order_mode == SimTypes.OrderMode.LOOP
		or order_mode == SimTypes.OrderMode.ONE_WAY_RETURN
		or carried_wounded > 0.01
	)
	if should_return and origin_node_id != current_node_id:
		if night_only and not is_night:
			is_waiting_night = true
			action_ticks_remaining = 0
			return
		is_waiting_night = false

		var return_path: Array[String] = graph.find_path(current_node_id, origin_node_id, weather, convoy_type)
		if return_path.size() >= 2:
			trips_completed += 1
			route_nodes = return_path
			route_segment_index = 0
			segment_progress_km = 0.0
			is_returning = true
			state = SimTypes.ConvoyState.MOVING
			_record_vuln_visit(node, visited_vulns)
			return

	trips_completed += 1
	is_waiting_night = false
	state = SimTypes.ConvoyState.IDLE
	is_returning = false
	route_nodes.clear()
	route_segment_index = 0
	segment_progress_km = 0.0


func _finish_leg(graph: WorldGraph) -> void:
	var cur_node: SimTypes.MapNode = graph.get_node(current_node_id)
	if order_mode == SimTypes.OrderMode.REDEPLOY:
		_offload_wounded_at_node(cur_node)
		is_returning = false
		is_waiting_night = false
		route_nodes.clear()
		route_segment_index = 0
		segment_progress_km = 0.0
		state = SimTypes.ConvoyState.IDLE
		return

	if is_returning:
		_offload_wounded_at_node(cur_node)
		is_returning = false
		route_nodes.clear()
		route_segment_index = 0
		segment_progress_km = 0.0
		if order_mode == SimTypes.OrderMode.LOOP:
			state = SimTypes.ConvoyState.LOADING
			action_ticks_remaining = _get_effective_load_ticks(cur_node)
		else:
			is_waiting_night = false
			state = SimTypes.ConvoyState.IDLE
	else:
		state = SimTypes.ConvoyState.UNLOADING
		action_ticks_remaining = _get_effective_load_ticks(cur_node)


func _offload_wounded_at_node(node: SimTypes.MapNode) -> void:
	if node == null or carried_wounded <= 0.0:
		return
	if node.node_type == SimTypes.NodeType.RAILHEAD or node.node_type == SimTypes.NodeType.DEPOT or node.node_type == SimTypes.NodeType.FIELD_DEPOT:
		total_wounded_evacuated += carried_wounded
		carried_wounded = 0.0


func _consume_travel(
	graph: WorldGraph,
	edge: SimTypes.RoadEdge,
	dist_km: float,
	weather: SimTypes.Weather,
	is_redeploy: bool
) -> void:
	if dist_km <= 0.0:
		return
	var burn_mult: float = 0.50 if is_redeploy else 1.0
	var burn: float = dist_km * fuel_burn_per_km * burn_mult
	var actual_burn: float = minf(fuel_tank, burn)
	fuel_tank = maxf(0.0, fuel_tank - actual_burn)
	total_fuel_burned += actual_burn
	total_distance_km += dist_km
	graph.apply_wear(edge, dist_km, weather)


func _refuel_at_node(node: SimTypes.MapNode) -> void:
	if node == null:
		return
	var needed: float = maxf(0.0, fuel_tank_capacity - fuel_tank)
	if needed <= 0.001:
		return
	var taken: float = node.take_stock(SimTypes.ResourceType.FUEL, needed)
	fuel_tank += taken


func _load_cargo_from_node(node: SimTypes.MapNode) -> void:
	var free_space: float = maxf(0.0, cargo_capacity - get_total_cargo())
	if free_space <= 0.001:
		return

	if convoy_type == SimTypes.ConvoyType.TANKER:
		_take_into_cargo(node, SimTypes.ResourceType.FUEL, free_space)
		return
	if convoy_type == SimTypes.ConvoyType.ENGINEER:
		if cargo_preference == SimTypes.CargoPreference.EQUIPMENT:
			_take_into_cargo(node, SimTypes.ResourceType.EQUIPMENT, free_space)
		else:
			_take_into_cargo(node, SimTypes.ResourceType.PARTS, free_space)
		return
	if convoy_type == SimTypes.ConvoyType.ARMORED:
		match cargo_preference:
			SimTypes.CargoPreference.FUEL:
				_take_into_cargo(node, SimTypes.ResourceType.FUEL, free_space)
			SimTypes.CargoPreference.AMMO:
				_take_into_cargo(node, SimTypes.ResourceType.AMMO, free_space)
			SimTypes.CargoPreference.PROVISIONS:
				_take_into_cargo(node, SimTypes.ResourceType.PROVISIONS, free_space)
			SimTypes.CargoPreference.PARTS:
				_take_into_cargo(node, SimTypes.ResourceType.PARTS, free_space)
			SimTypes.CargoPreference.EQUIPMENT:
				_take_into_cargo(node, SimTypes.ResourceType.EQUIPMENT, free_space)
			SimTypes.CargoPreference.MIXED:
				_take_into_cargo(node, SimTypes.ResourceType.AMMO, free_space * 0.35)
				_take_into_cargo(node, SimTypes.ResourceType.FUEL, free_space * 0.25)
				_take_into_cargo(node, SimTypes.ResourceType.PROVISIONS, free_space * 0.20)
				_take_into_cargo(node, SimTypes.ResourceType.PARTS, free_space * 0.20)
				for res: SimTypes.ResourceType in SimTypes.base_resources():
					var rem_arm: float = maxf(0.0, cargo_capacity - get_total_cargo())
					if rem_arm <= 0.01:
						break
					_take_into_cargo(node, res, rem_arm)
		return

	match cargo_preference:
		SimTypes.CargoPreference.FUEL:
			var max_barrels: float = maxf(0.0, 10.0 - get_cargo_amount(SimTypes.ResourceType.FUEL))
			_take_into_cargo(node, SimTypes.ResourceType.FUEL, minf(free_space, max_barrels))
		SimTypes.CargoPreference.AMMO:
			_take_into_cargo(node, SimTypes.ResourceType.AMMO, free_space)
		SimTypes.CargoPreference.PROVISIONS:
			_take_into_cargo(node, SimTypes.ResourceType.PROVISIONS, free_space)
		SimTypes.CargoPreference.PARTS:
			_take_into_cargo(node, SimTypes.ResourceType.PARTS, free_space)
		SimTypes.CargoPreference.EQUIPMENT:
			_take_into_cargo(node, SimTypes.ResourceType.EQUIPMENT, free_space)
		SimTypes.CargoPreference.MIXED:
			_take_into_cargo(node, SimTypes.ResourceType.AMMO, free_space * 0.50)
			_take_into_cargo(node, SimTypes.ResourceType.PROVISIONS, free_space * 0.20)
			_take_into_cargo(node, SimTypes.ResourceType.PARTS, free_space * 0.15)
			var fuel_cap_left: float = maxf(0.0, 10.0 - get_cargo_amount(SimTypes.ResourceType.FUEL))
			_take_into_cargo(node, SimTypes.ResourceType.FUEL, minf(free_space * 0.15, fuel_cap_left))
			var fallback_order: Array[SimTypes.ResourceType] = [
				SimTypes.ResourceType.AMMO,
				SimTypes.ResourceType.PROVISIONS,
				SimTypes.ResourceType.PARTS,
			]
			for res: SimTypes.ResourceType in fallback_order:
				var rem: float = maxf(0.0, cargo_capacity - get_total_cargo())
				if rem <= 0.01:
					break
				_take_into_cargo(node, res, rem)


func _take_into_cargo(node: SimTypes.MapNode, res: SimTypes.ResourceType, amount: float) -> void:
	if amount <= 0.001:
		return
	var got: float = node.take_stock(res, amount)
	cargo[res] = get_cargo_amount(res) + got


func _unload_cargo_to_node(node: SimTypes.MapNode) -> void:
	var is_eng: bool = (convoy_type == SimTypes.ConvoyType.ENGINEER)
	for res: SimTypes.ResourceType in SimTypes.all_resources():
		var carried: float = get_cargo_amount(res)
		if carried <= 0.0:
			continue
		var added: float = node.add_stock(res, carried, is_eng)
		cargo[res] = carried - added
		total_delivered[res] = total_delivered.get(res, 0.0) + added


func _record_vuln_visit(node: SimTypes.MapNode, visited_vulns: Array[String]) -> void:
	if node != null and node.is_vulnerable:
		if not visited_vulns.has(node.id):
			visited_vulns.append(node.id)
