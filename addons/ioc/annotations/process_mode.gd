class_name ProcessMode
extends GDScriptAnnotation

## Sets process_mode on a Node @Component when the container parents it, and
## again when a pooled node is borrowed. The first argument is a
## Node.ProcessMode value (for example Node.PROCESS_MODE_WHEN_PAUSED).
var value: int = -1
