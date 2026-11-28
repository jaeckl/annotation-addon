extends GutTest


func _mapper() -> Mapper:
	var mapper := Mapper.new()
	mapper.codec = JsonCodec.new()
	return mapper


func test_common_godot_leaves_roundtrip_json() -> void:
	var mapper := _mapper()
	var bytes := mapper.write(SaveGeom.sample())
	assert_gt(bytes.size(), 0, "wrote bytes")
	var text := bytes.get_string_from_utf8()
	assert_ne(text.find("\"Vector2i\""), -1, "Vector2i leaf present")
	assert_ne(text.find("\"PackedInt32Array\""), -1, "packed leaf present")
	var loaded := mapper.read(SaveGeom, bytes) as SaveGeom
	assert_not_null(loaded, "read")
	var sample := SaveGeom.sample()
	assert_eq(loaded.cell, sample.cell, "Vector2i")
	assert_eq(loaded.voxel, sample.voxel, "Vector3i")
	assert_eq(loaded.hyper, sample.hyper, "Vector4")
	assert_eq(loaded.hyper_i, sample.hyper_i, "Vector4i")
	assert_eq(loaded.area, sample.area, "Rect2")
	assert_eq(loaded.area_i, sample.area_i, "Rect2i")
	assert_eq(loaded.box, sample.box, "AABB")
	assert_eq(loaded.floor_plane, sample.floor_plane, "Plane")
	assert_true(loaded.spin.is_equal_approx(sample.spin), "Quaternion")
	assert_true(loaded.axes.is_equal_approx(sample.axes), "Basis")
	assert_eq(loaded.xf2, sample.xf2, "Transform2D")
	assert_true(loaded.xf3.is_equal_approx(sample.xf3), "Transform3D")
	assert_eq(loaded.bytes, sample.bytes, "PackedByteArray")
	assert_eq(loaded.ints, sample.ints, "PackedInt32Array")
	assert_eq(loaded.floats, sample.floats, "PackedFloat32Array")
	assert_eq(loaded.words, sample.words, "PackedStringArray")
	assert_eq(loaded.points, sample.points, "PackedVector2Array")
	assert_eq(loaded.colors, sample.colors, "PackedColorArray")


func test_common_godot_leaves_roundtrip_xml_and_binary() -> void:
	for codec in [XmlCodec.new(), BinaryCodec.new()]:
		var mapper := Mapper.new()
		mapper.codec = codec
		var loaded := mapper.read(SaveGeom, mapper.write(SaveGeom.sample())) as SaveGeom
		assert_not_null(loaded, "%s read" % codec.get_class())
		assert_eq(loaded.cell, Vector2i(3, -4), "%s Vector2i" % codec.get_class())
		assert_eq(loaded.ints, PackedInt32Array([7, -3, 0]), "%s packed ints" % codec.get_class())
