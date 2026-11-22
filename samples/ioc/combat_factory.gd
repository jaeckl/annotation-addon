@Configuration
class_name CombatFactory
extends RefCounted

## Factory. The container keeps one instance and calls the @Component methods.
## made shows that the methods share that instance. camp() instances a
## scene. The container does not construct the children. They receive @Inject
## when they enter the tree.
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


@Component
func camp() -> Camp:
	made += 1
	return preload("res://samples/ioc/camp.tscn").instantiate()
