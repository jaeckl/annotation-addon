class_name SimplifyPath
extends Preparation

## Runs String.simplify_path on a String. Any other value is unchanged.


func apply(candidate: Variant) -> Variant:
	if not (candidate is String):
		return candidate
	return String(candidate).simplify_path()
