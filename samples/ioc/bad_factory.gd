@Configuration
class_name BadFactory
extends RefCounted

## Registered as a factory, then rejected: a factory method without a GDScript
## return type is not a product.


@Component
func missing_return_type():
	return null
