class_name Async
extends GDScriptAnnotation

## Lets an @EventListener await. publish returns before the method finishes.
## A returned Event is published when the method finishes, on the same node.
## This stays on the main thread. It does not start a worker.
