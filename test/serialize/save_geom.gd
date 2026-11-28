@Serialize
class_name SaveGeom
extends RefCounted

## Fixture for Mapper leaf types beyond the original Vector2/3/Color set.

var cell := Vector2i.ZERO
var voxel := Vector3i.ZERO
var hyper := Vector4(1, 2, 3, 4)
var hyper_i := Vector4i(1, 2, 3, 4)
var area := Rect2(Vector2(1, 2), Vector2(3, 4))
var area_i := Rect2i(Vector2i(1, 2), Vector2i(3, 4))
var box := AABB(Vector3(0, 1, 2), Vector3(3, 4, 5))
var floor_plane := Plane(Vector3.UP, 2.5)
var spin := Quaternion(0.0, 0.0, 0.0, 1.0)
var axes := Basis.IDENTITY
var xf2 := Transform2D.IDENTITY
var xf3 := Transform3D.IDENTITY
var bytes := PackedByteArray()
var ints := PackedInt32Array()
var floats := PackedFloat32Array()
var words := PackedStringArray()
var points := PackedVector2Array()
var colors := PackedColorArray()


static func sample() -> SaveGeom:
	var geom := SaveGeom.new()
	geom.cell = Vector2i(3, -4)
	geom.voxel = Vector3i(1, 2, 3)
	geom.hyper = Vector4(0.5, 1.5, 2.5, 3.5)
	geom.hyper_i = Vector4i(4, 5, 6, 7)
	geom.area = Rect2(Vector2(1.25, -2), Vector2(10, 20))
	geom.area_i = Rect2i(Vector2i(2, 3), Vector2i(4, 5))
	geom.box = AABB(Vector3(0.5, 1.0, 1.5), Vector3(2, 3, 4))
	geom.floor_plane = Plane(Vector3.UP, 3.0)
	geom.spin = Quaternion(0.0, 0.70710677, 0.0, 0.70710677)
	geom.axes = Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0))
	geom.xf2 = Transform2D(Vector2(1, 0), Vector2(0, 1), Vector2(8, 9))
	geom.xf3 = Transform3D(geom.axes, Vector3(1, 2, 3))
	geom.bytes = PackedByteArray([1, 2, 255])
	geom.ints = PackedInt32Array([7, -3, 0])
	geom.floats = PackedFloat32Array([1.5, -2.25])
	geom.words = PackedStringArray(["a", "b"])
	geom.points = PackedVector2Array([Vector2(1, 2), Vector2(3, 4)])
	geom.colors = PackedColorArray([Color(1, 0, 0, 1), Color(0, 1, 0, 0.5)])
	return geom
