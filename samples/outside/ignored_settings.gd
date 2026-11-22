@ConfigurationProperties(prefix="combat")
class_name IgnoredSettings
extends RefCounted

## Outside the scan root, so the annotation alone does not register it.
@export var enabled: bool = false
