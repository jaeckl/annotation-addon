@Lazy
@RunScope
@Component
class_name RunGrabber
extends RefCounted

## Lazy so a container with default_init "eager" does not build it at start.
## It asks for a scene product, which a run product cannot hold.
@Inject var scene: LifeScene
