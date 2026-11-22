@Component
class_name Party
extends RefCounted

## Fields are filled after new() and before the instance is published.
@Inject var clock: GameClock
@Inject var weapon: Weapon
@Inject var escort: Escort
@Inject var roster: Roster
@Qualifier("brute")
@Inject var bruiser: Enemy
@Rank(kind="boss")
@Inject var boss: Enemy
@Offline
@Inject var stalker: Enemy
