class_name Shout
extends Preparation

## Example preparation that always returns text. On a float field the
## result cannot be stored.


func apply(_candidate: Variant) -> Variant:
	return "LOUD"
