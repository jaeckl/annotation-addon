class_name OnBeforeSerialization
extends GDScriptAnnotation

## Marks a zero-arg method. Mapper calls it on that object before reading
## @Serialize fields for a write (including nested documents). Return ignored.
## Do not await.
