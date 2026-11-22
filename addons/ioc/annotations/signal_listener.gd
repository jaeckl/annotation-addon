class_name SignalListener
extends GDScriptAnnotation

## Connects a signal on a published Node component to this method. The signal
## name is the first argument. An empty path is the component. A path is
## get_node on that component after _ready. A returned Event is published.
## The annotation may be repeated.
var signal_name: String = ""
var path: NodePath = NodePath()
const repeatable := true
