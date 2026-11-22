@Configuration
class_name MarkerCodecConfig
extends RefCounted


@ConditionalOnProperty(key="serialize/codec", having_value="marker")
@Component
func marker_codec() -> MarkerCodec:
	return MarkerCodec.new()
