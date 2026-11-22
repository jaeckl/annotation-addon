class_name Trim
extends Preparation

## Strips the edges of a String. Any other value is unchanged.


func apply(candidate: Variant) -> Variant:
	if not (candidate is String):
		return candidate
	return String(candidate).strip_edges()
