class_name Upper
extends Preparation

## Uppercases a String. Any other value is unchanged.


func apply(candidate: Variant) -> Variant:
	if not (candidate is String):
		return candidate
	return String(candidate).to_upper()
