@ConfigurationProperties(prefix="td")
class_name TdSettings
extends RefCounted

## Tunables for the Annotation TD demo. Bound from game/td/config/td.cfg.

@Min(0)
@Max(9999)
var start_gold: int = 80

@Min(1)
@Max(99)
var start_lives: int = 20

@Min(16)
@Max(128)
var cell_size: int = 40

@Min(8)
@Max(64)
var grid_width: int = 16

@Min(8)
@Max(64)
var grid_height: int = 12

@Min(0.0)
@Max(30.0)
var wave_intro_seconds: float = 2.5

@Min(0.0)
@Max(30.0)
var wave_gap_seconds: float = 3.0

@Min(0.05)
@Max(5.0)
var spawn_interval_seconds: float = 0.55

@Min(4.0)
@Max(64.0)
var select_hit_radius: float = 18.0

@Min(40.0)
@Max(800.0)
var projectile_speed: float = 220.0


func cell_size_f() -> float:
	return float(cell_size)
