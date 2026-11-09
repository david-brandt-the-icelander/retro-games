# Desktop build

> Status marks: [knowledge-driven development](https://github.com/david-brandt-the-icelander/knowledge-driven-development)

**Written for:** the engineer who builds and releases LodeStar.

## What it is

LodeStar ships as a native desktop game: the Godot 4.7.2 runtime, the exported game data, and `liblodestar_godot`, the Rust library this crate builds, which registers the sim's classes with Godot through `lodestar.gdextension`. There is no web build and no server.

## The boundary

On one side is Godot 4.7.2 (official builds and export templates), loading the library by the paths in `lodestar.gdextension`; on the other, godot-rust (`godot` 0.5.5), which this crate is built with. godot-rust 0.5.5 builds against Godot's 4.6 API and runs on the 4.7.2 runtime; the two are upgraded together.

## Behaviors

- ✅ `cargo build` in `games/lodestar/` builds the library, and Godot 4.7.2 loads it on Linux x86-64: in the editor, headless, and in an exported release build.
- ✅ The Linux export preset produces a runnable build, `build/linux/lodestar.x86_64`, with the game pack and the library beside it.
- ✅ Ship GLBs import through `src/presentation/ships/ship_import.gd`: their rig extras become node metadata, textures baked on the second UV set move to the first, and the ship turns to Godot's −Z forward.
- ⚠️ The Windows preset produces a runnable build with `lodestar_godot.dll` beside the executable.
- ⚠️⛔ The Windows library is built on Windows or by a CI runner with the Windows Rust target; this Linux machine has neither.
- ⚠️ The macOS preset produces a signed universal app with `liblodestar_godot.dylib` inside it.
- ⚠️⛔ The macOS library is built and signed on a Mac or by a macOS CI runner; this Linux machine has neither.
- ⚠️ Every pull request runs `cargo test` and a headless start of each platform's export.
- ⚠️⛔ The repository has no CI. A GitHub Actions workflow with Linux, Windows and macOS runners would unblock this.

## How it fails

| Symptom | Cause | What it looks like from outside | What an operator does | Status |
| --- | --- | --- | --- | --- |
| The scene fails to load with an unknown `SimHost` | The library has not been built | Godot reports a missing class and an empty window | Run `cargo build` (or `--release` for an export) | ⚠️ |
| A ship renders black | Its textures are on a UV set Godot does not read | A dark silhouette with glowing lights | Re-import the GLB so the import script moves the UV set | ✅ |

## Verified only against fakes

Rendering has been checked only with Mesa's software OpenGL renderer (llvmpipe) under Xvfb, where Godot falls back from Forward+ to its Compatibility renderer and glow is weaker. Forward+ on a real GPU, and Windows and macOS at all, have not been seen yet.

## Operating it

From `games/lodestar/`:

```bash
cargo test
cargo build --release
godot --headless --path . --export-release "Linux" build/linux/lodestar.x86_64
```
