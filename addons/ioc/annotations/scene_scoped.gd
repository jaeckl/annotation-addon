class_name SceneScoped
extends GDScriptAnnotation

## One instance per open sub-scene root. The mark sits next to @Component, on a
## class or on a factory method. The product is built on the first resolve
## inside that scene, or earlier when it is @Eager, and leaves when the root
## leaves. An app product cannot inject it. The class_name is SceneScoped
## because SceneScope is the handler.
