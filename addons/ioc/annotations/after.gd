class_name After
extends GDScriptAnnotation

## Runs after the around chain returns. The method takes one JoinPoint.
## join.result is the value the chain returned. pointcut is the annotation
## class on the target method, not a string.
var pointcut: GDScript
