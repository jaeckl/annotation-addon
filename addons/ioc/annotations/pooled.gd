class_name Pooled
extends GDScriptAnnotation

## Many instances of one component. resolve does not return one. Gameplay
## borrows an instance from InstancePools and releases it. The container
## builds it with new(), or instantiates its @Scene, injects once, and parks it.
## The first argument is the most instances one scene may hold. 0 is no cap.
var limit: int = 0
