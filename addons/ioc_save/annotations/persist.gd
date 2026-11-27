class_name Persist
extends GDScriptAnnotation

## Marks a run product that SaveSlots may write and load. Fields still opt in
## with @Serialize. Only already-built instances are saved. On load the product
## is filled after inject and before @Ready.
