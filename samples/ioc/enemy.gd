class_name Enemy
extends RefCounted

## Parent type. It is not a @Component. Subclasses that are components
## satisfy a dependency typed as Enemy.
func label() -> String:
	return "enemy"
