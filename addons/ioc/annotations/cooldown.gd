class_name Cooldown
extends GDScriptAnnotation

## Gate on a method. A call runs only when the window is open, then arms the
## window. The string is a delay like @Scheduled: 500ms, 1.5s, 10f, or 10pf.
## It is not a clock — pair it with @Process, an event, or a direct call.
var value: String = ""
