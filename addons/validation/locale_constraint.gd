class_name Locale
extends Constraint

## Matches the project fallback, the active locale, or a loaded locale.
## en matches en_US. Null matches, so NotNull stays a separate constraint.
const repeatable := true


func is_valid(candidate: Variant) -> bool:
	if candidate == null:
		return true
	var named := _named(candidate)
	if named.is_empty():
		return false
	var fallback := String(ProjectSettings.get_setting("internationalization/locale/fallback", "en"))
	if _matches_locale(named, fallback):
		return true
	if _matches_locale(named, TranslationServer.get_locale()):
		return true
	for locale in TranslationServer.get_loaded_locales():
		if _matches_locale(named, String(locale)):
			return true
	return false


func _matches_locale(candidate: String, known: String) -> bool:
	# compare_locales returns 10 for the same locale and 0 when the language differs.
	return TranslationServer.compare_locales(candidate, known) > 0


func violation_message(_candidate: Variant) -> String:
	return "must be a known locale"


func _named(candidate: Variant) -> String:
	if not (candidate is String):
		return ""
	return String(candidate).strip_edges()
