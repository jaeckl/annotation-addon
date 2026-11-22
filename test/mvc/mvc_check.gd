@Component
@Controller
class_name MvcCheck
extends RefCounted

@Inject var view: MvcShopView
@Inject var model: MvcChecked
@Inject var screens: ScreenHost

@Bind var error_label: Label
@Bind(^"Header/title_label") var title_label: Label

var hits: Array = []
var trap := false


@ValidationErrorHandler
func rejected(violation: Violation) -> void:
	hits.append(String(violation.member))
	if trap and String(violation.member) == "gold":
		trap = false
		model.gold = 3


@Ready
func arm() -> void:
	var title_text := Bindings.text(title_label)
	title_text.from(model.title)
	var problem := Bindings.error(error_label)
	problem.from(model.gold)
	screens.show(view)
