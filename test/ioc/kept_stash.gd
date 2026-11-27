@Persist
@RunScope
@Component
class_name KeptStash
extends RefCounted

## Persist fixture. coins avoids the suite-wide MvcMarkAdvisor on gold.

@Serialize var coins := 0
@Serialize var note := ""
var ready_coins := -1


@Ready
func boot() -> void:
	ready_coins = coins
