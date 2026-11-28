class_name ComponentDefinition
extends RefCounted

## One registered product. type is the class, or the factory method's declared
## return type. qualifiers are the Qualifier annotations on that class or method.
var type: GDScript
var qualifiers: Array = []
var label: String = ""
var owner_script: GDScript
var factory: Object
var method: StringName = &""
var parameters: Array = []
var fields: Array = []
var packed: PackedScene
## True for a @RunScope product. The instance lives in the open run.
var run := false
## Explicit init mark. &"" uses IOCContainer.default_init. &"eager" builds when
## the scope opens. &"lazy" waits for the first resolve.
var init_mode: StringName = &""
## True when the class or factory method carries @Primary. The default
## CandidateSelector keeps only primary products when several still match.
var primary := false
