class_name Scene
extends GDScriptAnnotation

## The PackedScene this component is built from. The argument is the resource
## path. The scene root's script is this class. resolve still returns the one
## instance. A @Pooled class is instantiated from this scene when borrow has
## nothing parked.
var path: String = ""
