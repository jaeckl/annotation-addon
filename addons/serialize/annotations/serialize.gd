class_name Serialize
extends GDScriptAnnotation

## On a class, every script field on that class and its bases is saved, and
## object values are walked the same way. On a field, only that field is saved.
## The first argument is the dictionary key. Empty uses the field name.
var value: String = ""
