@Persist
@RunScope
@Component
class_name KeptVault
extends RefCounted

## Built only when a test resolves it. write must skip it otherwise.

@Serialize var coins := 0
