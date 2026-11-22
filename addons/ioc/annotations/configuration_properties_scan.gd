class_name ConfigurationPropertiesScan
extends GDScriptAnnotation

## On a @Configuration class. root is a res:// directory. Every global class
## under that directory with @ConfigurationProperties is bound and published
## at the end of discover. Without this annotation, @ConfigurationProperties
## registers nothing.
var root: String = ""
