class_name ManualGold
extends RefCounted

var gold: int = 2:
	set(next):
		gold = next
		PropNotify.changed(self, &"gold", next)
	get:
		PropNotify.read(self, &"gold")
		return gold
