class_name Violation
extends RefCounted

## One constraint that did not match. member is the field name, or
## _init/parameter for a constructor argument. value is the candidate that
## failed. The field still holds the previous value.
var member: String = ""
var constraint_name: String = ""
var message: String = ""
var value: Variant = null


func _init(member_name: String = "", constraint: String = "", text: String = "", rejected: Variant = null) -> void:
	member = member_name
	constraint_name = constraint
	message = text
	value = rejected
