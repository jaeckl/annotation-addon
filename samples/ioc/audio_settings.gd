@ConfigurationProperties(prefix="audio")
class_name AudioSettings
extends Resource

## Bound from audio/* before the first scene. subtitle has no key, so the
## default stays. leaked is not @export, so the cfg value does not land.
@export var master: float = 1.0
@export var music: String = "silent"
@export var channels: int = 8
@export var subtitle: String = "none"
var leaked := "keep"
