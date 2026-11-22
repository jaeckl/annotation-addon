@ConfigurationProperties(prefix="stage")
class_name RejectedStage
extends Resource

## volume 4 is outside 0..1, and no stage/volume key overrides it.
@ValueRange(minimum=0.0, maximum=1.0)
@export var volume: float = 4.0
