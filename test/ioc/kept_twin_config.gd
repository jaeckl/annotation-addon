@Configuration
class_name KeptTwinConfig
extends RefCounted

## Two run products of the same persist class.


@Qualifier("alpha")
@RunScope
@Component
func alpha() -> KeptTwin:
	return KeptTwin.new()


@Qualifier("beta")
@RunScope
@Component
func beta() -> KeptTwin:
	return KeptTwin.new()
