@Configuration
class_name RunConfig
extends RefCounted


@RunScope
@Component
func purse(log: RunLog) -> RunPurse:
	var made := RunPurse.new()
	made.log = log
	return made
