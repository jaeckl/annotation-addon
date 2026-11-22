class_name UnhandledInput
extends GDScriptAnnotation

## Marks a method on a published product that is not a Node. The container's
## input node calls it from _unhandled_input. The method takes one InputEvent.
## An empty action receives every leftover event. An action receives events
## bound to that input-map action. pressed keeps the press and ignores echo.
## released keeps the release. The annotation may be repeated.
var action: String = ""
var pressed: bool = false
var released: bool = false
const repeatable := true
