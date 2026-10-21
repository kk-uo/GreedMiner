extends Node

## Every character in the Chinese translation must be in the shipped font
## subset. If this fails, regenerate it: python3 tools/fonts/subset_cjk_font.py


func _ready() -> void:
	var errors: Array[String] = []
	var theme := load("res://Resources/UI/greedminer_theme.tres") as Theme
	var font: Font = theme.default_font if theme != null else null
	if font == null:
		errors.append("Theme has no default font")
	var file := FileAccess.open("res://Translations/zh_CN.po", FileAccess.READ)
	if file == null:
		errors.append("zh_CN.po could not be opened")
	elif font != null:
		var missing: Dictionary = {}
		for line in file.get_as_text().split("\n"):
			if not line.begins_with("msgstr") and not line.begins_with("\""):
				continue
			for index in range(line.length()):
				var code: int = line.unicode_at(index)
				if code < 0x2000:
					continue
				if not font.has_char(code):
					missing[char(code)] = true
		if not missing.is_empty():
			errors.append("Font subset is missing %d characters: %s (run tools/fonts/subset_cjk_font.py)" % [missing.size(), "".join(PackedStringArray(missing.keys()))])
	if errors.is_empty():
		print("FONT_COVERAGE_TEST: PASS")
		get_tree().quit(0)
	else:
		for error in errors:
			push_error("FONT_COVERAGE_TEST FAIL: " + error)
		get_tree().quit(1)
