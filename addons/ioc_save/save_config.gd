@Configuration
class_name SaveConfig
extends RefCounted

## Publishes SaveSlots unless a game product already exists. PersistHook is a
## component of its own, so discovery loads it with the other products.


@ConditionalOnMissingComponent(type_name="SaveSlots")
@Component
func save_slots() -> SaveSlots:
	return SaveSlots.new()
