@Configuration
class_name CombatFactory
extends RefCounted

## Factory. The container keeps one instance and calls the @Component methods.
## made shows that both methods share that instance.
var made := 0


@Component
func sword(@Inject clock: GameClock) -> Weapon:
	made += 1
	var weapon := Weapon.new()
	weapon.clock = clock
	return weapon


@Qualifier("brute")
@Component
func escort(@Inject @Qualifier("brute") bruiser: Enemy) -> Escort:
	made += 1
	var formed := Escort.new()
	formed.bruiser = bruiser
	return formed
