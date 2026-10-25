extends Node


func _ready() -> void:
	var errors: Array[String] = []
	TranslationServer.set_locale("zh_CN")
	var expected_names := {
		&"scatter_machine_gun": "散射机枪",
		&"knockback_machine_gun": "击退机枪",
		&"laser_machine_gun": "激光机枪",
		&"sawblade_machine_gun": "电锯机枪",
		&"flame_machine_gun": "火焰机枪",
		&"laser_chainsaw": "激光电锯",
		&"heavy_laser": "超粗激光",
		&"automatic_cannon": "自动加农炮",
		&"siege_cannon": "攻城加农炮",
		&"knockback_cannon": "远程击退加农炮",
		&"flame_cannon": "火焰加农炮",
		&"knockback_laser": "击退激光",
		&"flame_laser": "火焰激光",
	}
	for entry in ModuleCatalog.ENTRIES:
		if not bool(entry.get("fusion_only", false)):
			continue
		var weapon_id: StringName = entry["id"]
		if TranslationServer.translate(String(entry["name"])) != expected_names.get(weapon_id, ""):
			errors.append("Missing translated weapon name: %s" % weapon_id)
		var definition := ResearchManager.get_weapon_research_definition(weapon_id)
		if definition == null or TranslationServer.translate(definition.description) == definition.description:
			errors.append("Missing translated research tooltip: %s" % weapon_id)
	if TranslationServer.translate("FUSING  ·  %s") % "超粗激光" != "合成中  ·  超粗激光":
		errors.append("Fusion progress text is not translated")
	if TranslationServer.translate("FUSION COMPLETE  ·  %s") % "超粗激光" != "合成完成  ·  超粗激光":
		errors.append("Fusion completion text is not translated")
	if errors.is_empty():
		print("FUSION_WEAPON_LOCALIZATION_TEST: PASS")
		get_tree().quit(0)
	else:
		for error in errors:
			push_error("FUSION_WEAPON_LOCALIZATION_TEST: " + error)
		get_tree().quit(1)
