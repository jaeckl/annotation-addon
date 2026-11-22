class_name BrokenGain
extends RefCounted

## step 0 is a broken annotation. The value stays 1.0.
@RoundTo(step=0.0)
var gain: float = 1.0
