class_name RunScope
extends GDScriptAnnotation

## One instance per run. A run is one playthrough. Runs opens it and ends it.
## The mark sits next to @Component, on a class or on a factory method. The
## product is built on the first resolve inside the open run and is dropped
## when that run ends. An app product cannot inject it.
