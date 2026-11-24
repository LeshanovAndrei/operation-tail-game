class_name CampaignData
extends RefCounted


static func load_campaigns_index(path: String = "res://data/campaigns/campaigns_index.json") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var parsed: Variant = _load_json(path)
	if typeof(parsed) != TYPE_DICTIONARY:
		return result
	var root: Dictionary = parsed
	var raw_campaigns: Variant = root.get("campaigns", [])
	if typeof(raw_campaigns) != TYPE_ARRAY:
		return result
	var arr: Array = raw_campaigns
	for item: Variant in arr:
		if typeof(item) == TYPE_DICTIONARY:
			result.append(item)
	return result


static func load_upgrades_catalog(path: String = "res://data/campaigns/upgrades.json") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var parsed: Variant = _load_json(path)
	if typeof(parsed) != TYPE_DICTIONARY:
		return result
	var root: Dictionary = parsed
	var raw_upgrades: Variant = root.get("upgrades", [])
	if typeof(raw_upgrades) != TYPE_ARRAY:
		return result
	var arr: Array = raw_upgrades
	for item: Variant in arr:
		if typeof(item) == TYPE_DICTIONARY:
			result.append(item)
	return result


static func build_modifiers(purchased_ids: Array[String], upgrades_catalog: Array[Dictionary]) -> SimTypes.CampaignModifiers:
	var mods: SimTypes.CampaignModifiers = SimTypes.CampaignModifiers.new()
	for u: Dictionary in upgrades_catalog:
		var uid: String = str(u.get("id", ""))
		if not purchased_ids.has(uid):
			continue
		var eff_raw: Variant = u.get("effects", {})
		if typeof(eff_raw) != TYPE_DICTIONARY:
			continue
		var eff: Dictionary = eff_raw
		mods.bonus_cargo_convoys += int(eff.get("bonus_cargo_convoys", 0))
		mods.bonus_tanker_convoys += int(eff.get("bonus_tanker_convoys", 0))
		mods.bonus_engineer_convoys += int(eff.get("bonus_engineer_convoys", 0))
		mods.bonus_armored_convoys += int(eff.get("bonus_armored_convoys", 0))
		mods.bonus_train_slots += int(eff.get("bonus_train_slots", 0))
		if eff.has("depot_signature_growth_mult"):
			mods.depot_signature_growth_mult *= float(eff["depot_signature_growth_mult"])
		if eff.has("dirt_mud_speed_mult"):
			mods.dirt_mud_speed_mult *= float(eff["dirt_mud_speed_mult"])
	return mods


static func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("CampaignData: file not found: %s" % path)
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("CampaignData: failed to open: %s" % path)
		return null
	var text: String = file.get_as_text()
	file.close()
	return JSON.parse_string(text)
