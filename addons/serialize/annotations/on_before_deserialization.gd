class_name OnBeforeDeserialization
extends GDScriptAnnotation

## Marks a zero-arg method. Mapper calls it on that object before filling
## @Serialize fields on a read / read_into (including nested documents).
## Return ignored. Do not await.
