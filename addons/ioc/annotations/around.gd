class_name Around
extends GDScriptAnnotation

## Wraps a method that carries the named annotation. The method takes one
## ProceedingJoinPoint and calls proceed to run the rest of the chain.
## Skipping proceed skips the target method. pointcut is that annotation class.
var pointcut: GDScript
