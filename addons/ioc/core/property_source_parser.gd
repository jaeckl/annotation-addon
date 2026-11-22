class_name PropertySourceParser
extends RefCounted

## Turns a file path into a PropertySource. handles picks the parser by
## extension. A custom format is another subclass. The first parser that
## handles the path is the one that reads it.


func handles(_path: String) -> bool:
	return false


func parse(_path: String) -> PropertySource:
	return null
