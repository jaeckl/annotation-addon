@ConfigurationProperties(prefix="ioc")
class_name IocProperties
extends RefCounted

## Framework settings. The container binds this from the property environment
## during discover, without a @ConfigurationPropertiesScan. Games may also
## @Inject it. default_init is "lazy" or "eager" and feeds IOCContainer.default_init
## before eager products are built. cfg key ioc/default_init, ProjectSettings
## ioc/default_init, IOC_DEFAULT_INIT, or --ioc/default_init=eager.
@export var default_init: String = "lazy"
