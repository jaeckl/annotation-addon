@Component
@Model
class_name MvcBadHandler
extends RefCounted


@ValidationErrorHandler
func rejected(violation: Violation) -> void:
	pass
