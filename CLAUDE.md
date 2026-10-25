# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Chem Lab: a Breaking Bad–inspired first-person 3D cooking sim in Godot 4.7 (Mobile renderer, GDScript only). Players take a customer's order at the van window, then cook a multi-step "crystal" recipe on a placemat before the round timer runs out. See `README.md` for the gameplay pitch.

## Running

There is no build, lint, or test tooling. Open the project in the Godot editor (`/Applications/Godot.app`; no `godot` on PATH) and run. The `mcp__godot__*` tools (launch_editor, run_project, get_debug_output) can also drive it. Entry scene is the title screen (`run/main_scene` in `project.godot`); gameplay is `Scenes/Gameplay/main.tscn`. `Scenes/Gameplay/enemy_test_world.tscn` and `Scenes/test.tscn` are sandboxes. Escape quits the game (handled in `Gamestate._process`).

`.godot/` is gitignored but some files in it show up as tracked/modified; ignore them in diffs.

## Architecture

**Autoloads** (`project.godot`): `Gamestate` (`Scripts/Gamestate.gd`) is the global blackboard: round timer, money, current cooking prompt, step scores, `recipe_active`/`in_dialogue` flags, and an `alert_requested` signal. `SceneTransition` handles scene changes (`SceneTransition.change_scene(path)`). Scripts communicate mostly by reading/writing `Gamestate` fields and signals rather than direct node references; the HUD polls them.

**Game flow**: title screen → `main.gd` plays a scripted camera intro pan (`INTRO_PAN`; skippable via `Gamestate.skip_van_intro`) and hands over to the player; `Gamestate.round` drives the HUD's intro text stages. `window_enemy.gd` is the customer at the van window (signals `arrived`, `order_taken`, `served`, `left`). `main.gd` adds a `CookingDirector` node at runtime.

**Cooking system** (the core, spans several files):
- `recipe.gd` (`Recipe.STEPS`) is pure data: an ordered list of steps, each with `type`, `instruction`, `required` item names, and `params`.
- `cooking_director.gd` runs those steps. It listens to the player's `item_placed/picked/swapped/returned` signals, tracks which named `Ingredients/*` rigid bodies are on the placemat, shows the instruction, and once all `required` items are placed, freezes the player, switches to a top-down cook camera, and instantiates the step UI. Items are matched by node name under the `Ingredients` node (see `ITEM_NAMES`); `originals`/`homes` let it reset or rebuild items. Scoring (speed bonus, payout, purity) is also computed here and written into `Gamestate`.
- Step UIs are `CanvasLayer` scripts mapped by `type` in `CookingDirector.STEP_UIS` (`pour_step`, `crush_step`, `combine_step`, `heat_step`, `drop_step`, `crystal_step`). Each exposes `start(step, items)` (items: name → node) and a `finished(score: float)` signal (0..1). `step_stub.gd` is a placeholder template. `step_util.gd` holds shared motion helpers (e.g. `tilt_over`); `step_meter.gd` is a shared meter widget.
- To add a step: add an entry to `Recipe.STEPS`, a script following the `start`/`finished` contract, register it in `STEP_UIS`, and add its label to `STEP_NAMES` (and any new item to `ITEM_NAMES` and the `Ingredients` node in `main.tscn`).

**Player/UI**: `player.gd` handles first-person movement, pickup/placement (emits the item signals above, `dish_served`), and `controls_locked`. `ui_style.gd` (`UIStyle`) centralizes label/theme styling used by all UI scripts; use it rather than ad-hoc styling. Input actions are defined in `project.godot` (`pick_up`=E, `click`, `space`, `sprint`, WASD/arrows, `escape`).

**Assets**: `Scenes/Models/*.tscn` are the lab-equipment props; shaders live in `Assets/Environment/`. Each `.gd` has a sibling `.gd.uid` file that must be committed with it.
