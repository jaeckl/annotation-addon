@Serialize
class_name SavePlayer
extends RefCounted

var hp := 10
@Serialize("title")
var name_label := "Ada"
@Transient
var secret := "no"
var weapon: SaveWeapon
var flags: Array = []
var spot := Vector2.ZERO
var meta: Dictionary = {}
var ratio: float = 0.0
var tint := Color(0, 0, 0, 1)
var where := Vector3.ZERO
var path := NodePath()
var tag: StringName = &""
