@Configuration
class_name MvcConfig
extends RefCounted

## Publishes the screen host unless a game host already exists. MvcHook is a
## component of its own, so discovery loads it with the other products.


@ConditionalOnMissingComponent(type_name="ScreenHost")
@Component
func screen_host() -> ScreenHost:
	return ScreenHost.new()
