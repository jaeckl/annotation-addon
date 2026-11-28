class_name Lazy
extends GDScriptAnnotation

## Builds the product on its first resolve. Use this when IOCContainer.default_init
## is "eager" and this product should wait. The mark sits on a class or on a
## factory method, next to @Component. It cannot sit with @Eager or @Pooled.
