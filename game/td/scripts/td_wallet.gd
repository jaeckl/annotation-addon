@Persist
@RunScope
@Eager
@Component
class_name TdWallet
extends RefCounted

## Gold and lives for one run. Kill creeps to earn; spend to buy/upgrade towers.

@Inject var settings: TdSettings
@Inject var events: EventPublisher

@Serialize
@Required
var gold: int = 0
@Serialize
@Required
var lives: int = 0

@Transient var _from_save := false


@OnAfterDeserialization
func mark_loaded() -> void:
	_from_save = true


@Ready
func boot() -> void:
	if settings == null:
		return
	if _from_save:
		return
	if gold == 0 and lives == 0:
		gold = settings.start_gold
		lives = settings.start_lives


func credit(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount


func try_spend(amount: int) -> bool:
	if amount < 0 or gold < amount:
		return false
	gold -= amount
	return true


@EventListener
func on_creep_died(event: TdCreepDied) -> void:
	credit(event.bounty)


@EventListener
func on_base_hit(event: TdBaseHit) -> void:
	lives = maxi(0, lives - maxi(1, event.damage))
	if lives <= 0 and events != null:
		var over := TdRunOver.new()
		over.won = false
		events.publish(over)
