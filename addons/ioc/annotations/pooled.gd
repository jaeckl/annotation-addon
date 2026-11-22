class_name Pooled
extends GDScriptAnnotation

## Many instances of one component. resolve does not return one. Gameplay
## borrows an instance from InstancePools and releases it. The container
## builds it with new(), injects once, and parks it for the scene.
