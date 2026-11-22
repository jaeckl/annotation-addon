class_name SampleNote
extends GDScriptAnnotation

## true allows a second SampleNote on the same target. This sample uses that once, on the script.
const repeatable := true

## Dictionary attribute copied onto the annotation object. Applying @SampleNote does not call _init.
var note: Dictionary = {}
