class_name Scheduled
extends GDScriptAnnotation

## Marks a method on a published product that is not a Node. The frame node
## calls it on a cadence. The string is 500ms, 1.5s, 10f, 10pf, or a cron
## expression with the second first. The method takes nothing. The annotation
## may be repeated.
var value: String = ""
const repeatable := true
