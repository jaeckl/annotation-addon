@ConditionalOnProperty(key="ioc/eager_fixtures", having_value="yes")
@Eager
@Component
class_name EagerApp
extends RefCounted

## Built at discover. Uses its own flag so it does not share RunLog with
## other suite fixtures.
static var booted := false


@Ready
func boot() -> void:
	booted = true
