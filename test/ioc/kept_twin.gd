@Persist
class_name KeptTwin
extends RefCounted

## Returned by two run factory methods so write can refuse a duplicate class.

@Serialize var coins := 0
