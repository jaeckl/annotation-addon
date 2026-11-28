# Annotation TD

Local tower-defense dogfood for the IoC / annotation stack.

## Run on your PC

1. Open this repo in Godot **4.8** with the custom user-annotations build.
2. Project already uses `IOCMainLoop`.
3. Set **Project → Project Settings → Application → Run → Main Scene** to  
   `res://game/td/td_main.tscn`  
   (or open that scene and press Play Scene / F6).
4. First open needs an import so `IOCMainLoop` lands in the global class cache  
   (`godot --path . --headless --import --quit`).
5. Play.

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

## Config

`game/td/config/td.cfg` → `TdSettings` (`@ConfigurationProperties`): gold, lives, `cell_size`, `grid_width` / `grid_height`, wave cadence, select radius, projectile speed. No parallel hardcodes for those knobs.

## Framework surfaces used

| Mark / lib | TD use |
| --- | --- |
| `IOCMainLoop` | Boot + discover |
| `@ConfigurationProperties` | `TdSettings` from `td.cfg` |
| `@RunScope` / `Runs` | Wallet, towers, waves, match flow, HUD model |
| `@Persist` / `@Serialize` / `SaveSlots` | Mid-run save; Continue loads in battle with `body_parent` so nested `@Pooled` `TdTower` rows borrow into the world |
| `@Pooled` / `@OnRelease` | Creeps, towers, shots |
| `@Process` | Waves, match flow, HUD sync |
| `@EventListener` | Kills, leaks, run over |
| FSM (`@StateMachine`, `@OnEnter`) | `TdMatchFlow` |
| MVC (`@Model` / `@View` / `@Controller` / `@Bind` / `@Property`) | HUD |
| `@UnhandledInput` + `@OncePer` | Play clicks / hotkeys |
| `@TweenPlay` | Tower place pop |
| `@Logged` / `@Timed` | Wave finish / creep move hotspot |
| `@Inject` / `@SceneScoped` / `@Eager` | Battle wiring |
| Catalog cooldown | Per-tower fire (data-driven; not a fixed `@Cooldown` string) |
