extends Node


func _ready() -> void:
	var errors: Array[String] = []
	if not LanguageManager.set_language(&"en"):
		errors.append("English preference could not be saved")
	if TranslationServer.translate("SETTINGS") != "SETTINGS":
		errors.append("English translation is not the default text")
	if not LanguageManager.set_language(&"zh_CN"):
		errors.append("Chinese preference could not be saved")
	if TranslationServer.translate("SETTINGS") != "设置":
		errors.append("Chinese translation did not load")
	if TranslationServer.translate("WAVE  %d / %d") % [3, 10] != "波次  3 / 10":
		errors.append("Dynamic wave text was not translated correctly")
	if TranslationServer.translate("UPGRADE TO LEVEL %d — ◆ %s ORE") % [10, "1,800"] != "升级至 10 级 — ◆ 1,800 矿石":
		errors.append("Dynamic research cost was not translated correctly")
	if TranslationServer.translate("Angry Stone") != "愤怒的石头":
		errors.append("Artifact name was not translated")
	var chip_visual := preload("res://Scripts/UI/Chips/ChipVisual.gd")
	if chip_visual.get_display_name(&"damage_chip") != "伤害芯片":
		errors.append("Drawn chip name was not translated")
	if chip_visual.get_effect_text(&"damage_chip") != "+20% 伤害":
		errors.append("Drawn chip effect was not translated")
	if TranslationServer.translate("GET READY  %d") % 3 != "准备  3":
		errors.append("Dynamic mining QTE text was not translated")
	if TranslationServer.translate("Unlock All Magic Artifacts") != "解锁全部魔法道具":
		errors.append("Developer action labels were not translated")
	if TranslationServer.translate("Granted %d Ore.") % 1000 != "已发放 1000 矿石。":
		errors.append("Developer result messages were not translated")
	if TranslationServer.translate("Battle speed: %.0f×") % 2.0 != "战斗速度：2×":
		errors.append("Developer battle speed was not translated")
	var developer_panel := preload("res://Scenes/UI/developer_panel.tscn").instantiate() as DeveloperPanel
	add_child(developer_panel)
	await get_tree().process_frame
	if developer_panel.get_node("%UnlockWeaponsButton").text != "解锁全部武器":
		errors.append("Developer scene controls did not auto-translate")
	if developer_panel.get_node("%AmountInput").placeholder_text != "输入非负整数":
		errors.append("Developer amount placeholder did not auto-translate")
	developer_panel._show_result({
		"ok": true,
		"message": "Granted 1000 Ore.",
		"message_key": "Granted %d Ore.",
		"message_args": [1000],
	})
	if developer_panel.get_node("%StatusLabel").text != "已发放 1000 矿石。":
		errors.append("Developer runtime result did not use its translation key")
	developer_panel.queue_free()
	var theme := load("res://Resources/UI/greedminer_theme.tres") as Theme
	var font: Font = theme.default_font if theme != null else null
	if font == null or not font.has_char(0x8bbe):
		errors.append("Project font does not support Chinese glyphs")
	var menu := SettingsMenu.new()
	menu.align_right = true
	add_child(menu)
	var choices := _find_language_choice(menu)
	if choices == null or choices.selected != 1:
		errors.append("Settings language selector did not reflect Chinese")
	else:
		choices.select(0)
		choices.item_selected.emit(0)
		if not TranslationServer.get_locale().begins_with("zh"):
			errors.append("Language changed before fade to black")
		await get_tree().create_timer(0.55, true).timeout
		if not TranslationServer.get_locale().begins_with("en"):
			errors.append("Settings selector did not switch to English")
	var saved := ConfigFile.new()
	if saved.load(LanguageManager.SETTINGS_PATH) != OK or saved.get_value("language", "locale", "") != "en":
		errors.append("Language preference did not persist")
	menu.queue_free()
	if errors.is_empty():
		print("LANGUAGE_SETTINGS_TEST: PASS")
		get_tree().quit(0)
	else:
		for error in errors:
			push_error("LANGUAGE_SETTINGS_TEST: " + error)
		get_tree().quit(1)


func _find_language_choice(node: Node) -> OptionButton:
	if node is OptionButton:
		return node as OptionButton
	for child in node.get_children():
		var found := _find_language_choice(child)
		if found != null:
			return found
	return null
