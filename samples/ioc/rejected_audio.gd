@ConfigurationProperties(prefix="audio")
class_name RejectedAudio
extends Resource

## master is 0.8, which is below the minimum, so this product is not published.
@Min(value=2.0)
@export var master: float = 1.0
