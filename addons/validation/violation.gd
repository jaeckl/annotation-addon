class_name Violation
extends RefCounted

## One constraint that did not match. member is the field name, or
## _init/parameter for a constructor argument.
var member: String = ""
var constraint_name: String = ""
var message: String = ""


func _init(member_name: String = "", constraint: String = "", text: String = "") -> void:
	member = member_name
	constraint_name = constraint
	message = text
