class_name ScheduleSpec
extends RefCounted

## One parsed @Scheduled string. error is empty when the string is a schedule.
const TIME := 0
const FRAME := 1
const PHYSICS_FRAME := 2
const CRON := 3

var kind := TIME
var period := 0.0
var frames := 0
var fields: Array = []
var error := ""


static func parse(text: String) -> ScheduleSpec:
	var spec := ScheduleSpec.new()
	var body := text.strip_edges()
	if body == "":
		spec.error = "empty"
		return spec
	if _is_delay(body):
		_parse_delay(spec, body)
		return spec
	_parse_cron(spec, body)
	return spec


func matches(now: Dictionary) -> bool:
	if kind != CRON or fields.size() != 6:
		return false
	if not _hit(fields[0], int(now.get("second", -1))):
		return false
	if not _hit(fields[1], int(now.get("minute", -1))):
		return false
	if not _hit(fields[2], int(now.get("hour", -1))):
		return false
	if not _hit(fields[4], int(now.get("month", -1))):
		return false
	var dom_star := bool(fields[3].get("star", false))
	var dow_star := bool(fields[5].get("star", false))
	var dom := _hit(fields[3], int(now.get("day", -1)))
	var dow := _hit(fields[5], int(now.get("weekday", -1)))
	if dom_star and dow_star:
		return true
	if dom_star:
		return dow
	if dow_star:
		return dom
	return dom or dow


static func _is_delay(body: String) -> bool:
	if body.find(" ") != -1:
		return false
	return body.ends_with("ms") or body.ends_with("pf") or body.ends_with("s") or body.ends_with("f")


static func _parse_delay(spec: ScheduleSpec, body: String) -> void:
	var unit := ""
	var number_text := ""
	if body.ends_with("ms"):
		unit = "ms"
		number_text = body.substr(0, body.length() - 2)
	elif body.ends_with("pf"):
		unit = "pf"
		number_text = body.substr(0, body.length() - 2)
	elif body.ends_with("s"):
		unit = "s"
		number_text = body.substr(0, body.length() - 1)
	elif body.ends_with("f"):
		unit = "f"
		number_text = body.substr(0, body.length() - 1)
	if number_text == "" or not number_text.is_valid_float():
		spec.error = "bad"
		return
	var number := number_text.to_float()
	if number <= 0.0:
		spec.error = "zero"
		return
	if unit == "f" or unit == "pf":
		if not is_equal_approx(number, round(number)):
			spec.error = "fraction"
			return
		spec.kind = PHYSICS_FRAME if unit == "pf" else FRAME
		spec.frames = int(round(number))
		return
	spec.kind = TIME
	spec.period = number / 1000.0 if unit == "ms" else number


static func _parse_cron(spec: ScheduleSpec, body: String) -> void:
	var parts: PackedStringArray = body.split(" ", false)
	if parts.size() != 6:
		spec.error = "bad"
		return
	var limits := [[0, 59], [0, 59], [0, 23], [1, 31], [1, 12], [0, 7]]
	var parsed: Array = []
	for index in parts.size():
		var field: Variant = _parse_field(parts[index], int(limits[index][0]), int(limits[index][1]), index == 5)
		if field == null:
			spec.error = "bad"
			return
		parsed.append(field)
	spec.kind = CRON
	spec.fields = parsed


static func _parse_field(text: String, low: int, high: int, sunday: bool) -> Variant:
	if text == "*":
		return {"star": true, "values": {}}
	var values := {}
	for part in text.split(",", true):
		if part == "":
			return null
		var step := 1
		var span := part
		if part.find("/") != -1:
			var bits := part.split("/", true)
			if bits.size() != 2 or bits[0] == "" or not bits[1].is_valid_int():
				return null
			span = bits[0]
			step = int(bits[1])
			if step <= 0:
				return null
		var start := low
		var ending := high
		if span == "*":
			start = low
			ending = high
		elif span.find("-") != -1:
			var range_bits := span.split("-", true)
			if range_bits.size() != 2 or not range_bits[0].is_valid_int() or not range_bits[1].is_valid_int():
				return null
			start = int(range_bits[0])
			ending = int(range_bits[1])
		else:
			if not span.is_valid_int():
				return null
			start = int(span)
			ending = start
		if start < low or ending > high or start > ending:
			return null
		var cursor := start
		while cursor <= ending:
			var stored := 0 if sunday and cursor == 7 else cursor
			values[stored] = true
			cursor += step
	return {"star": false, "values": values}


func _hit(field: Dictionary, value: int) -> bool:
	if bool(field.get("star", false)):
		return true
	var values: Dictionary = field.get("values", {})
	return values.has(value)
