@Serialize
class_name SaveHookBad
extends RefCounted

var hp := 1


@OnBeforeSerialization
var not_a_method := 0
