@Component
@Controller
class_name MvcShop
extends RefCounted

@Inject var view: MvcShopView
@Inject var stash: MvcStash
@Inject var screens: ScreenHost

@Bind var gold_label: Label
@Bind var add_button: Button
@Bind(^"Header/title_label") var title_label: Label

var clicks := 0


@Ready
func arm() -> void:
	var gold_text := Bindings.text(gold_label)
	gold_text.from(stash.gold)
	var title_text := Bindings.text(title_label)
	title_text.from(stash.title)
	Bindings.on(add_button.pressed).to(add)
	screens.show(view)


func add() -> void:
	clicks += 1
	stash.gold += 1


func close() -> void:
	screens.hide(view)
