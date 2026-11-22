@Scheduled("1f")
@Component
class_name ScheduleBad
extends RefCounted

@Scheduled("1f") var label := ""


@Scheduled
func empty() -> void:
	pass


@Scheduled("0ms")
func zero() -> void:
	pass


@Scheduled("-2s")
func negative() -> void:
	pass


@Scheduled("1.5f")
func fraction() -> void:
	pass


@Scheduled("nope")
func garbage() -> void:
	pass


@Scheduled("60 * * * * *")
func bad_cron() -> void:
	pass


@Scheduled("1f")
static func parked() -> void:
	pass


@Scheduled("1f")
func takes(_n: int) -> void:
	pass


func marked_param(@Scheduled("1f") _n: int) -> void:
	pass
