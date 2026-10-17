# Void Journal

A native macOS journal where your words slowly disappear as you write. Your newest thought
stays on screen, older words let go with a calm animation, and nothing is ever saved.

- **Two themes, each in light and dark mode.** In Dissolve, letters break into drifting
  particles. In Void, words fade into slowly moving purple gradients.
- **Paced to your writing.** Words disappear faster while you type quickly and slower when
  you pause. Your current sentence always stays visible.
- **Made for full screen,** with a short introduction on first launch.

## Requirements

- macOS 14 or later
- The Swift toolchain. The Xcode Command Line Tools are enough, and Xcode itself is not
  needed. To install them, run:

  ```bash
  xcode-select --install
  ```

## Build and run

```bash
make run
```

This builds a release version of `build/Void Journal.app` and opens it.

| Command            | What it does                                              |
| ------------------ | --------------------------------------------------------- |
| `make app`         | Build `build/Void Journal.app` (release)                  |
| `make debug`       | Build the app in debug configuration                      |
| `make run`         | Build and open the app                                    |
| `make install`     | Build and copy the app to `/Applications`                 |
| `make reset-intro` | Show the first-launch introduction again on next launch   |
| `make clean`       | Remove build output                                       |

To compile without bundling the app, run `swift build`. To replay the introduction while
the app is running, use **Help ▸ Show Introduction**.

## Format and lint

The code is formatted with `swift format`, which ships with the Swift toolchain. The rules
are in [`.swift-format`](.swift-format).

```bash
make format   # rewrite all Swift files in place
make lint     # check formatting and style without changing files
```

Run `make format` before committing. `make lint` should pass with no warnings.

## Project layout

```
Sources/VoidJournal/
  App/        App entry point, menus, preferences
  Engine/     Text model, word wrapping and pacing of disappearing words
  Rendering/  Drawing of text, particles and fades
  Views/      Main window, input handling, backgrounds, intro, settings
  Debug/      Offscreen snapshot rendering
scripts/      App bundling and app icon generation
Resources/    Info.plist and app icon
```

See [CLAUDE.md](CLAUDE.md) for the full product spec and architecture notes.
