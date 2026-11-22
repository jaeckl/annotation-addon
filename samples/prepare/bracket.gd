class_name Bracket
extends Preparation

## Example preparation. Wraps a String in brackets. Paired with Trim and
## Lower, source order decides whether the spaces are still inside.


func apply(candidate: Variant) -> Variant:
	if not (candidate is String):
		return candidate
	return "[%s]" % String(candidate)
