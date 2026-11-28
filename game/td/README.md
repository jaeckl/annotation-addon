# Annotation TD

Local tower-defense dogfood for the IoC / annotation stack.

## Run on your PC

1. Open this repo in Godot **4.8** with the custom user-annotations build.
2. Project already uses `IOCMainLoop`.
3. Set **Project → Project Settings → Application → Run → Main Scene** to  
   `res://game/td/td_main.tscn`  
   (or open that scene and press Play Scene / F6).
4. Play.

CI / addon demos keep `res://samples/ioc/demo.tscn` as the default main scene in `project.godot` so GUT stays undisturbed. Switch main scene locally when you want the TD.

## Controls

| Input | Action |
| --- | --- |
| 1 / 2 / 3 | Select Arrow / Cannon / Slow |
| Left click empty cell | Buy selected tower (costs gold) |
| Left click tower twice (or **U** / Upgrade) | Spend gold to upgrade (3 levels) |
| Esc | Pause / resume |
| Pause → Save | Write slot `td1` |
| Menu Continue | Load slot `td1` |

## Economy

Kill creeps → gold → buy towers → upgrade towers (no sell).

## Framework surfaces used

`@RunScope`, `@Persist` / `SaveSlots`, `@Pooled`, `@Process`, `@EventListener`, FSM (`TdMatchFlow`), `@Logged`, `@ConfigurationProperties`, `@Inject` on the battle scene root, `@Cooldown`-style gates via per-tower timers (catalog cooldowns), `@OnRelease`.
