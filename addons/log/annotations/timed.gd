class_name Timed
extends GDScriptAnnotation

## Marks a method for elapsed-time logging. value is the threshold in
## milliseconds; 0 logs every call. Calls at or over the threshold are logged.
var value: float = 0.0
