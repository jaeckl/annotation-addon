@abstract
class_name Event
extends RefCounted

## Base type for a published event. A listener method takes one parameter
## whose type is Event or a subclass. The class is abstract, so it is not
## constructed, and it is not a @Component.
