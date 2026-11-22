# IOC architecture

Working plan for `addons/ioc` in this project. It uses the user-annotation APIs on Godot branch `cursor/gdscript-user-annotations-8b9e`.

The current stubs still have `Configuration` extending `Component`, and `IOCMainLoop` extending `MainLoop` with no `class_name`. This plan replaces that.

## Decisions

`@Configuration` is a factory. It does not extend `@Component`. The scanner instantiates each configuration class once, at app scope, and treats that object as the factory.

`@Component` is the only product mark.

- On a class, the product is that class. The container calls `new()` on the script.
- On a method, the product is the method's return value. The container calls the method on the factory. This is the factory method. There is no separate `@Bean`.

`@Component` is not an injection mark. A later annotation owns parameters and fields.

Conditions and profiles are their own annotations. The factory reads every annotation on the class or the method before it registers a definition. `@Profile` means a run mode (client, dedicated server, editor, or a project feature tag). `@ConditionalOn*` means a yes-or-no check against a setting, a registered type, or a node present in the active scope. Those annotations are not folded into `@Component`.

Two scopes:

- **App.** One instance for the process. A `Node` is parented to the scene-tree root. A `RefCounted` is held by the container.
- **Scene.** One instance per instanced scene root, keyed by that root's instance id. Not one instance per `PackedScene` resource.

The scene tree owns one container. The tree owns node lifetime. The container is the lookup index. It holds `RefCounted` instances itself. It does not parent nodes, and it does not keep a second owning reference to a node.

`IOCMainLoop` is a `SceneTree` with a `class_name`, selected by `application/run/main_loop_type`. `_initialize` calls `super()` first, then discovers definitions.

Discovery uses `ProjectSettings.get_global_class_list()`, then `AnnotationUtils` on each script. There is no project-wide annotation index. Scripts with no `class_name`, and inner classes, are out of this scan.

## Context

```mermaid
flowchart LR
    player[Player]
    author[Script author]
    tree[IOCMainLoop SceneTree]
    container[IOCContainer]
    scripts[Global class scripts]

    player -->|runs the game| tree
    author -->|writes annotations| scripts
    tree -->|owns| container
    container -->|reads annotations| scripts
    tree -->|parents Node products| tree
```

## Modules

Allowed dependency: annotations depend on nothing in this addon. The container depends on annotations only through `AnnotationUtils` at runtime. The main loop depends on the container. Sample game scripts depend on the annotations. They do not depend on the container type.

```mermaid
flowchart TD
    annotations["addons/ioc/annotations"]
    container["addons/ioc/core/IOCContainer"]
    mainloop["addons/ioc/core/IOCMainLoop"]
    samples["game scripts"]

    mainloop --> container
    container --> annotations
    samples --> annotations
```

## Classes

```mermaid
classDiagram
    class GDScriptAnnotation
    class Component {
        +scope: Scope
    }
    class Configuration
    class Condition
    class Profile {
        +mode: String
    }
    class IOCMainLoop {
        +container: IOCContainer
        +_initialize()
        +_finalize()
    }
    class IOCContainer {
        +register(definition)
        +resolve(type, fromNode)
        +open_scene(root)
        +close_scene(root)
    }
    class ComponentDefinition {
        +type: Script
        +scope: Scope
        +producer: Callable
        +factory: Object
    }
    class Scope {
        <<enumeration>>
        APP
        SCENE
    }
    class AppScope {
        +instances: Dictionary
    }
    class SceneScope {
        +root: Node
        +instances: Dictionary
    }

    GDScriptAnnotation <|-- Component
    GDScriptAnnotation <|-- Configuration
    GDScriptAnnotation <|-- Condition
    GDScriptAnnotation <|-- Profile
    SceneTree <|-- IOCMainLoop
    IOCMainLoop *-- IOCContainer
    IOCContainer *-- AppScope
    IOCContainer o-- SceneScope
    IOCContainer --> ComponentDefinition
    ComponentDefinition --> Scope
    Component --> Scope
    SceneScope --> Node
```

`Configuration` and `Component` are siblings. A component query does not match a configuration. A configuration class can still expose products, because those products are `@Component` methods, not the configuration annotation itself.

`Condition` is the base for later checks (`ConditionalOnSetting`, `ConditionalOnType`, `ConditionalOnNode`). The container does not special-case each name. It asks each condition annotation on the target whether the definition may be registered.

## Registration

```mermaid
sequenceDiagram
    participant Loop as IOCMainLoop
    participant Tree as SceneTree
    participant Scan as Global class list
    participant Utils as AnnotationUtils
    participant Box as IOCContainer
    participant Factory as Configuration instance

    Loop->>Tree: super()._initialize()
    Loop->>Box: new IOCContainer
    Loop->>Scan: get_global_class_list()
    loop each GDScript
        Loop->>Utils: has_annotation(script, Configuration)
        alt configuration class
            Loop->>Factory: script.new()
            Loop->>Utils: for_each_annotation_initialized(Component, script)
            Utils-->>Loop: annotation, FunctionInfo or ScriptInfo
            Loop->>Loop: read Condition and Profile on that target
            alt conditions pass
                Loop->>Box: register(ComponentDefinition)
            end
        else class-level Component
            Loop->>Utils: has_annotation(script, Component)
            Loop->>Loop: read Condition and Profile on the class
            alt conditions pass
                Loop->>Box: register(producer = script.new)
            end
        end
    end
```

Class-level `@Component` on a `@Configuration` class is ignored. The configuration object is the factory, created above, not a second product.

Method-level `@Component` is valid only on a configuration class. On any other class the scanner skips it.

## Resolve

```mermaid
sequenceDiagram
    participant Node as Caller node
    participant Box as IOCContainer
    participant Scene as Scene root
    participant App as App scope
    participant Producer as producer Callable

    Node->>Box: resolve(Type, fromNode)
    Box->>Scene: walk parents to scene root
    alt scope is Scene and this root has an instance
        Box-->>Node: existing instance
    else scope is Scene and this root has none
        Box->>Producer: call()
        Box->>Scene: parent Node under the scene root
        Box-->>Node: instance
    else scope is App and an instance exists
        Box-->>Node: existing instance
    else scope is App and none exists
        Box->>Producer: call()
        Box->>App: parent Node under the tree root, or hold RefCounted
        Box-->>Node: instance
    end
```

The caller passes the node it is running on. Scene scope walks parents to the instanced scene root. App scope ignores that root. A scene-scoped `Node` is parented under the scene root. An app-scoped `Node` is parented under the tree root. A `RefCounted` is stored in the scope map and is not parented.

## Scope lifecycle

```mermaid
stateDiagram-v2
    [*] --> AppOpen: _initialize after super()
    AppOpen --> SceneOpen: scene root enters tree
    SceneOpen --> SceneOpen: resolve scene-scoped type
    SceneOpen --> AppOpen: scene root exits tree
    AppOpen --> [*]: _finalize
```

`close_scene` drops that root's map. Node products under the root are freed by the tree. The container does not free them again. `RefCounted` products for that scene are released with the map.

## What the container stores

| Kind | App | Scene |
| --- | --- | --- |
| Node | Child of the tree root. Container stores the lookup. | Child of the scene root. Container stores the lookup. |
| RefCounted | Held in the app map. | Held in the scene map until the root exits. |

## Out of this plan

Injection annotations, inner-class scan, scripts without `class_name`, and more scopes than App and Scene. Conditions and profiles are named here so the factory has a place to read them. Their concrete checks are the next design pass.
