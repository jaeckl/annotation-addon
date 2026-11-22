class_name Lower
extends Preparation

## Lowercases a String. Any other value is unchanged.


func apply(candidate: Variant) -> Variant:
	if not (candidate is String):
		return candidate
	return String(candidate).to_lower()
