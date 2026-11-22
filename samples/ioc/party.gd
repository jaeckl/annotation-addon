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
@Inject var enemies: Array[Enemy]
@Offline
@Inject var offline_pack: Array[Enemy]
@Rank(kind = "boss")
@Inject var bosses: Array[Enemy]
@Qualifier("nobody")
@Inject var nobody: Array[Enemy]
@Inject var audio: AudioSettings
@Inject var combat_options: CombatOptions
