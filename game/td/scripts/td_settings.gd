@ConfigurationProperties(prefix="td")
class_name TdSettings
extends RefCounted

@Min(0)
@Max(9999)
var start_gold: int = 80

@Min(1)
@Max(99)
var start_lives: int = 20

@Min(16)
@Max(128)
var cell_size: int = 40
