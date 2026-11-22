class_name ConfigurationProperties
extends GDScriptAnnotation

## Marks a settings object. prefix plus the @export name is the property key,
## as in prefix "audio" and field master -> audio/master. The class is not
## registered unless a @Configuration carries @ConfigurationPropertiesScan
## and the script path is under that root.
var prefix: String = ""
