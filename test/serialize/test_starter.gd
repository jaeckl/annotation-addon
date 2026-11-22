extends GutTest

var box: IOCContainer


func before_each() -> void:
	ProjectSettings.set_setting("serialize/codec", "")
	box = IOCContainer.new()
	box.setup(get_tree())
	box.discover()


func after_each() -> void:
	ProjectSettings.set_setting("serialize/codec", "")
	if box != null:
		box.shutdown()
	box = null


func test_the_starter_publishes_json_and_a_memory_sink() -> void:
	var codec := box.resolve(Codec)
	assert_true(codec is JsonCodec, "JSON is the codec")
	var mapper := box.resolve(Mapper) as Mapper
	assert_not_null(mapper, "the mapper is a product")
	assert_eq(mapper.codec, codec, "the mapper uses the published codec")
	var loaded := mapper.read(SaveHero, mapper.write(SaveHero.sample())) as SaveHero
	assert_eq(loaded.name_label, "Bea", "the published mapper roundtrips")
	var sink := box.resolve(Sink) as MemorySink
	assert_not_null(sink, "the memory sink is the Sink product")
	sink.write("ok".to_utf8_buffer())
	assert_eq(sink.read().get_string_from_utf8(), "ok", "the sink keeps bytes")


func test_a_game_codec_replaces_json() -> void:
	box.shutdown()
	box = null
	ProjectSettings.set_setting("serialize/codec", "marker")
	var local := IOCContainer.new()
	local.setup(get_tree())
	local.discover()
	for err in get_errors():
		err.handled = true
	var codec := local.resolve(Codec)
	assert_true(codec is MarkerCodec, "the game codec is the one product")
	var mapper := local.resolve(Mapper) as Mapper
	assert_eq(mapper.codec, codec, "the mapper uses the game codec")
	var loaded := mapper.read(SaveNote, mapper.write(SaveNote.new())) as SaveNote
	assert_eq(loaded.text, "hi", "the replacement codec still roundtrips")
	local.shutdown()
	ProjectSettings.set_setting("serialize/codec", "")
