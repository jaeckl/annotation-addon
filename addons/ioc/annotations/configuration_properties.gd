class_name ConfigurationProperties
extends GDScriptAnnotation

## Marks a settings object. prefix plus the @export name is the property key,
## as in prefix "audio" and field master -> audio/master. A game settings
## class is registered when a @Configuration carries @ConfigurationPropertiesScan
## and the script path is under that root. IocProperties is bound by the
## container itself, without that scan.
var prefix: String = ""
