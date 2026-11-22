@ConfigurationProperties(prefix="audio")
class_name ValidatedAudio
extends Resource

## Bound audio that satisfies every constraint. master is 0.8. music is town.
@Min(value=0.0)
@Max(value=1.0)
@export var master: float = 1.0
@NotEmpty
@export var music: String = ""
