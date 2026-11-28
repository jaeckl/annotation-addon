class_name OnAnim
extends GDScriptAnnotation

## Connects a method on a Node component to AnimationPlayer started or
## finished. player is get_node from the component. Set on_finished or
## on_started (not both). animation filters by name; empty hears every
## animation. Repeatable.
var player: NodePath = NodePath()
var on_finished: bool = false
var on_started: bool = false
var animation: String = ""
const repeatable := true
