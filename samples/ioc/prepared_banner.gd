@ConfigurationProperties(prefix="banner")
class_name PreparedBanner
extends Resource

## Defaults are prepared before validation. "  Town  " becomes "town",
## which is one of the allowed titles. 1.5 is clamped into the range.
@Trim
@Lower
@OneOf(values=["town", "radio"])
@export var title: String = "  Town  "
@Clamp(minimum=0.0, maximum=1.0)
@ValueRange(minimum=0.0, maximum=1.0)
@export var volume: float = 1.5
