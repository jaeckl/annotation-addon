@ConfigurationProperties(prefix="banner")
class_name RejectedBanner
extends Resource

## Shout returns text for a float, so preparation fails and this stays unpublished.
@Shout
@export var volume: float = 0.5
