class_name Qualifier
extends GDScriptAnnotation

## Selects one product when several match a type. value is an ordinary
## attribute. A user qualifier extends this class and adds its own attributes.
## @Qualifier("brute") sets value. @Rank(kind="boss") sets the subclass attribute.
var value: String = ""
