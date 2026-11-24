class_name WorldGraph
extends RefCounted

var nodes: Dictionary[String, SimTypes.MapNode] = {}
var node_order: Array[String] = []
var edges: Array[SimTypes.RoadEdge] = []

var _adjacency: Dictionary = {}
var _min_km_per_px: float = 0.03
var dirt_mud_speed_mult: float = 1.0


func add_node(node: SimTypes.MapNode) -> void:
	nodes[node.id] = node
	if not node_order.has(node.id):
		node_order.append(node.id)
	if not _adjacency.has(node.id):
		var empty_list: Array[SimTypes.RoadEdge] = []
		_adjacency[node.id] = empty_list


func add_edge(edge: SimTypes.RoadEdge) -> void:
	edges.append(edge)
	if not _adjacency.has(edge.from_id):
		var list_a: Array[SimTypes.RoadEdge] = []
		_adjacency[edge.from_id] = list_a
	if not _adjacency.has(edge.to_id):
		var list_b: Array[SimTypes.RoadEdge] = []
		_adjacency[edge.to_id] = list_b
	var adj_from: Array[SimTypes.RoadEdge] = _adjacency[edge.from_id]
	var adj_to: Array[SimTypes.RoadEdge] = _adjacency[edge.to_id]
	adj_from.append(edge)
	adj_to.append(edge)


func finalize_metrics() -> void:
	var min_ratio: float = INF
	for edge: SimTypes.RoadEdge in edges:
		var node_a: SimTypes.MapNode = get_node(edge.from_id)
		var node_b: SimTypes.MapNode = get_node(edge.to_id)
		if node_a == null or node_b == null:
			continue
		var px_dist: float = node_a.position.distance_to(node_b.position)
		if px_dist > 1.0:
			var ratio: float = edge.distance_km / px_dist
			if ratio < min_ratio:
				min_ratio = ratio
	if min_ratio == INF:
		_min_km_per_px = 0.0
	else:
		_min_km_per_px = min_ratio


func get_node(node_id: String) -> SimTypes.MapNode:
	if nodes.has(node_id):
		return nodes[node_id]
	return null


func get_all_nodes() -> Array[SimTypes.MapNode]:
	var result: Array[SimTypes.MapNode] = []
	for node_id: String in node_order:
		if nodes.has(node_id):
			result.append(nodes[node_id])
	return result


func get_nodes_by_type(node_type: SimTypes.NodeType) -> Array[SimTypes.MapNode]:
	var result: Array[SimTypes.MapNode] = []
	for node_id: String in node_order:
		var node: SimTypes.MapNode = nodes[node_id]
		if node.node_type == node_type:
			result.append(node)
	return result


func get_edges_for(node_id: String) -> Array[SimTypes.RoadEdge]:
	if _adjacency.has(node_id):
		var list: Array[SimTypes.RoadEdge] = _adjacency[node_id]
		return list
	var empty_list: Array[SimTypes.RoadEdge] = []
	return empty_list


func get_edge_between(node_a: String, node_b: String) -> SimTypes.RoadEdge:
	var list: Array[SimTypes.RoadEdge] = get_edges_for(node_a)
	for edge: SimTypes.RoadEdge in list:
		if edge.get_other_node(node_a) == node_b:
			return edge
	return null


func get_edge_midpoint(edge: SimTypes.RoadEdge) -> Vector2:
	if edge == null:
		return Vector2.ZERO
	var na: SimTypes.MapNode = get_node(edge.from_id)
	var nb: SimTypes.MapNode = get_node(edge.to_id)
	if na == null or nb == null:
		return Vector2.ZERO
	return (na.position + nb.position) * 0.5


func junction_needs_engineer(node_id: String) -> bool:
	var node: SimTypes.MapNode = get_node(node_id)
	if node == null or node.node_type != SimTypes.NodeType.JUNCTION:
		return false
	if node.is_bridge and node.damaged:
		return true
	if node.can_deploy_depot and node.deploy_build_ticks_remaining <= 0 and node.deploy_progress_parts < node.deploy_cost_parts - 0.01:
		return true
	for edge: SimTypes.RoadEdge in get_edges_for(node_id):
		if not is_edge_passable(edge):
			continue
		if edge.mined or edge.wear >= 0.25:
			return true
	return false


func is_edge_passable(edge: SimTypes.RoadEdge) -> bool:
	if edge == null:
		return false
	var na: SimTypes.MapNode = get_node(edge.from_id)
	var nb: SimTypes.MapNode = get_node(edge.to_id)
	if na == null or nb == null:
		return false
	return na.owner == SimTypes.Owner.FRIENDLY and nb.owner == SimTypes.Owner.FRIENDLY


func is_edge_bridge_damaged(edge: SimTypes.RoadEdge) -> bool:
	if edge == null:
		return false
	var na: SimTypes.MapNode = get_node(edge.from_id)
	var nb: SimTypes.MapNode = get_node(edge.to_id)
	if na != null and na.is_bridge and na.damaged:
		return true
	if nb != null and nb.is_bridge and nb.damaged:
		return true
	return false


func get_edge_effective_speed_kmh(
	edge: SimTypes.RoadEdge,
	weather: SimTypes.Weather = SimTypes.Weather.CLEAR,
	convoy_type: SimTypes.ConvoyType = SimTypes.ConvoyType.CARGO
) -> float:
	if edge == null:
		return 20.0
	return edge.get_effective_speed_kmh(weather, is_edge_bridge_damaged(edge), convoy_type, dirt_mud_speed_mult)


func get_edge_travel_time_hours(
	edge: SimTypes.RoadEdge,
	weather: SimTypes.Weather = SimTypes.Weather.CLEAR,
	convoy_type: SimTypes.ConvoyType = SimTypes.ConvoyType.CARGO
) -> float:
	if edge == null:
		return INF
	return edge.get_travel_time_hours(weather, is_edge_bridge_damaged(edge), convoy_type, dirt_mud_speed_mult)


func apply_wear(edge: SimTypes.RoadEdge, distance_km: float, weather: SimTypes.Weather = SimTypes.Weather.CLEAR) -> void:
	if edge == null or distance_km <= 0.0:
		return
	edge.wear = clampf(edge.wear + distance_km * edge.get_wear_rate_per_km(weather), 0.0, 1.0)


func step_road_recovery(base_recovery: float = 0.0015, parts_boost: float = 0.0030) -> void:
	for edge: SimTypes.RoadEdge in edges:
		if edge.wear <= 0.0:
			continue
		var rec: float = base_recovery
		var na: SimTypes.MapNode = get_node(edge.from_id)
		var nb: SimTypes.MapNode = get_node(edge.to_id)
		var repaired_with_parts: bool = false
		if na != null and na.get_stock(SimTypes.ResourceType.PARTS) >= 0.03:
			na.take_stock(SimTypes.ResourceType.PARTS, 0.03)
			repaired_with_parts = true
		elif nb != null and nb.get_stock(SimTypes.ResourceType.PARTS) >= 0.03:
			nb.take_stock(SimTypes.ResourceType.PARTS, 0.03)
			repaired_with_parts = true
		if repaired_with_parts:
			rec += parts_boost
		edge.wear = maxf(0.0, edge.wear - rec)


func find_path(
	from_id: String,
	to_id: String,
	weather: SimTypes.Weather = SimTypes.Weather.CLEAR,
	convoy_type: SimTypes.ConvoyType = SimTypes.ConvoyType.CARGO
) -> Array[String]:
	var empty_path: Array[String] = []
	if not nodes.has(from_id) or not nodes.has(to_id):
		return empty_path
	var dest_node: SimTypes.MapNode = get_node(to_id)
	if dest_node == null or dest_node.owner != SimTypes.Owner.FRIENDLY:
		return empty_path
	if from_id == to_id:
		var single: Array[String] = [from_id]
		return single

	var open_set: Array[String] = [from_id]
	var closed_set: Dictionary[String, bool] = {}
	var came_from: Dictionary[String, String] = {}
	var g_score: Dictionary[String, float] = {}
	var f_score: Dictionary[String, float] = {}

	g_score[from_id] = 0.0
	f_score[from_id] = _heuristic_hours(from_id, to_id)

	while not open_set.is_empty():
		var best_idx: int = 0
		var current: String = open_set[0]
		var best_f: float = f_score.get(current, INF)
		for i: int in range(1, open_set.size()):
			var candidate: String = open_set[i]
			var candidate_f: float = f_score.get(candidate, INF)
			if candidate_f < best_f:
				best_f = candidate_f
				current = candidate
				best_idx = i

		if current == to_id:
			return _reconstruct_path(came_from, current)

		open_set.remove_at(best_idx)
		closed_set[current] = true

		var current_g: float = g_score.get(current, INF)
		var incident_edges: Array[SimTypes.RoadEdge] = get_edges_for(current)
		for edge: SimTypes.RoadEdge in incident_edges:
			if not is_edge_passable(edge):
				continue
			var neighbor: String = edge.get_other_node(current)
			if neighbor.is_empty() or closed_set.get(neighbor, false):
				continue
			var tentative_g: float = current_g + get_edge_travel_time_hours(edge, weather, convoy_type)
			if tentative_g < g_score.get(neighbor, INF):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + _heuristic_hours(neighbor, to_id)
				if not open_set.has(neighbor):
					open_set.append(neighbor)

	return empty_path


func compute_path_time_hours(
	path: Array[String],
	weather: SimTypes.Weather = SimTypes.Weather.CLEAR,
	convoy_type: SimTypes.ConvoyType = SimTypes.ConvoyType.CARGO
) -> float:
	if path.size() < 2:
		return 0.0
	var total: float = 0.0
	for i: int in range(path.size() - 1):
		var edge: SimTypes.RoadEdge = get_edge_between(path[i], path[i + 1])
		if edge == null:
			return INF
		total += get_edge_travel_time_hours(edge, weather, convoy_type)
	return total


func compute_path_distance_km(path: Array[String]) -> float:
	if path.size() < 2:
		return 0.0
	var total: float = 0.0
	for i: int in range(path.size() - 1):
		var edge: SimTypes.RoadEdge = get_edge_between(path[i], path[i + 1])
		if edge == null:
			return INF
		total += edge.distance_km
	return total


func path_has_warnings(path: Array[String], weather: SimTypes.Weather = SimTypes.Weather.CLEAR) -> Dictionary:
	var has_damaged_bridge: bool = false
	var has_bad_dirt: bool = false
	var has_mined_road: bool = false
	var has_frontline_danger: bool = false
	var max_w: float = 0.0
	for i: int in range(path.size() - 1):
		var edge: SimTypes.RoadEdge = get_edge_between(path[i], path[i + 1])
		if edge == null:
			continue
		if is_edge_bridge_damaged(edge):
			has_damaged_bridge = true
		if edge.mined:
			has_mined_road = true
		if edge.frontline_danger:
			has_frontline_danger = true
		if edge.wear > max_w:
			max_w = edge.wear
		if edge.wear >= 0.35 or (edge.road_type == SimTypes.RoadType.DIRT and weather != SimTypes.Weather.CLEAR):
			has_bad_dirt = true
	return {
		"has_damaged_bridge": has_damaged_bridge,
		"has_bad_dirt": has_bad_dirt,
		"has_mined_road": has_mined_road,
		"has_frontline_danger": has_frontline_danger,
		"max_wear": max_w,
	}


func get_max_wear() -> float:
	var max_w: float = 0.0
	for edge: SimTypes.RoadEdge in edges:
		if edge.wear > max_w:
			max_w = edge.wear
	return max_w


func _heuristic_hours(from_id: String, to_id: String) -> float:
	var node_a: SimTypes.MapNode = get_node(from_id)
	var node_b: SimTypes.MapNode = get_node(to_id)
	if node_a == null or node_b == null:
		return 0.0
	var min_km: float = node_a.position.distance_to(node_b.position) * _min_km_per_px
	return min_km / (68.75 * maxf(1.0, dirt_mud_speed_mult))


func _reconstruct_path(came_from: Dictionary[String, String], current: String) -> Array[String]:
	var path: Array[String] = [current]
	var cursor: String = current
	while came_from.has(cursor):
		cursor = came_from[cursor]
		path.push_front(cursor)
	return path
