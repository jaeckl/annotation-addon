class_name Eager
extends GDScriptAnnotation

## Builds the product when its scope opens. App products are built at the end
## of discover. Run products are built in Runs.start before RunStarted. Scene
## products are built when that scene opens. The mark sits on a class or on a
## factory method, next to @Component. It cannot sit with @Lazy or @Pooled.
