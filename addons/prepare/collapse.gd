class_name Collapse
extends Preparation

## Trims a String and turns each inner run of whitespace into one space.
## Any other value is unchanged.


func apply(candidate: Variant) -> Variant:
	if not (candidate is String):
		return candidate
	var text := String(candidate).strip_edges()
	var collapsed := ""
	var pending_space := false
	for index in text.length():
		var character := text.substr(index, 1)
		if character == " " or character == "\t" or character == "\n" or character == "\r":
			pending_space = not collapsed.is_empty()
			continue
		if pending_space:
			collapsed += " "
			pending_space = false
		collapsed += character
	return collapsed
