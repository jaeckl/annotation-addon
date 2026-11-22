class_name PreparedCard
extends RefCounted

## Scalar preparations. label shows trim, then collapse, then lower.
@Trim
@Collapse
@Lower
var label: String = "  Too   Loud  "
@RoundTo(step=0.5)
var gain: float = 1.2
@RoundTo(step=2.0)
var pace: int = 3
@SimplifyPath
var scene: String = "res://samples/ioc/../ioc/demo.tscn"
@Clamp(minimum=0.0, maximum=1.0)
var volume: float = 1.5
@Upper
var code: String = "town"


func _init(@Trim @Lower @Bracket title: String = "") -> void:
	pass
