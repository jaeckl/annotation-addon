@Configuration
class_name SerializeConfig
extends RefCounted

## Publishes JSON unless a Codec product already exists, plus the mapper and a
## memory sink. A game factory that returns another Codec wins.


@ConditionalOnMissingComponent(type_name="Codec")
@Component
func json_codec() -> JsonCodec:
	return JsonCodec.new()


@Component
func mapper(codec: Codec) -> Mapper:
	var created := Mapper.new()
	created.codec = codec
	return created


@ConditionalOnMissingComponent(type_name="Sink")
@Component
func memory_sink() -> MemorySink:
	return MemorySink.new()
