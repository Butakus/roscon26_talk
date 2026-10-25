# Pixi: one lockfile, three operating systems

> **Persona:** the corporate developer stuck on Windows without admin rights, and the
> macOS user who just wants `ros2` to work. Also any Linux user outside Ubuntu.

[Pixi](https://pixi.sh) installs ROS 2 and every dependency as conda packages
([RoboStack](https://robostack.github.io/)) into a `.pixi/` folder next to your code.
There's no root, no system packages and no `source /opt/ros/...`. Everything is pinned
in `pixi.lock`, for every platform.

| | |
|---|---|
| ROS 2 distro | rolling |
| Platforms | `linux-64` (tested), `osx-arm64`, `win-64` (lockfile resolves, not run yet) |
| Root needed | No |
| Disk | `.pixi/` 4.4 GB + workspace ~1 GB |
| Time (16 cores) | `pixi install` 1.5 min · build 2.5 min · tests 4 min |

## Two ways to use EasyNav with pixi

### 1. Just use it: `consumer/`

EasyNav is published as conda packages in the IRL channel (linux-64 only, for now).
This is the [official install method](https://easynavigation.github.io/0.5.0/build_install/binaries.html)
for rolling, which has no apt packages:

```bash
cd consumer
pixi install          # ~15 s with a warm cache
pixi run run          # EasyNav with the Dummy* plugins
pixi shell            # or a shell with everything activated
```

### 2. Develop it: this directory

EasyNav's code lives in `src/` and is built with colcon. Pixi provides only its
dependencies.

## One-time setup

```bash
# Install pixi (Linux/macOS)
curl -fsSL https://pixi.sh/install.sh | sh
# Windows (PowerShell)
#   powershell -ExecutionPolicy ByPass -c "irm -useb https://pixi.sh/install.ps1 | iex"

cd demos/04_pixi
pixi install          # creates .pixi/ from pixi.lock
pixi run setup        # clones EasyNavigation + yaets into src/ (common/easynav.repos)
```

## Daily development loop

```bash
pixi run build        # colcon build (settings in common/colcon_defaults.yaml)
pixi run test         # colcon test + test-result
pixi run run          # system_main with common/params/dummy.params.yaml
pixi run demo         # all of the above (common/scripts/demo.sh or demo.ps1)
pixi run clean        # rm -rf build install log
```

Or work inside an activated shell, the way you would on Ubuntu:

```bash
pixi shell
colcon build --packages-select easynav_core
ros2 run easynav_system system_main --ros-args --params-file ../../common/params/dummy.params.yaml
```

Once `install/` exists, activation also sources the workspace overlay
(`install/setup.sh`, or `install/setup.bat` on Windows), so `ros2 run` finds EasyNav with
no manual sourcing.

## Adding a dependency

1. Add it to the `package.xml` as usual.
2. Either regenerate the dependency list:

   ```bash
   pixi ros init -d rolling -p linux-64 -p osx-arm64 -p win-64 \
     -c https://prefix.dev/fmrico/irl-rolling
   ```

   (this needs the [pixi-ros](https://github.com/prefix-dev/pixi-ros) extension:
   `pixi global install pixi-ros`), or add it by hand:
   `pixi add ros-rolling-<pkg>` / `pixi add <conda-pkg>` / `pixi add --pypi <pkg>`.
3. Commit `pixi.toml` **and** `pixi.lock`. Your colleagues get exactly the same versions.

`pixi ros init` rewrites `pixi.toml`, so re-apply the manual changes listed at the top
of the file:
- The IRL channel goes first.
- The three `python3-*` keys it can't map (`platformdirs`, `rich`,
  `typing-extensions`) are added under their conda-forge names.
- The tasks are restored.
- So are the per-platform activation scripts.

## IDE integration

- **VS Code / clangd:** `build/compile_commands.json` is generated on every build. Run
  `code .` from inside `pixi shell` so the editor sees the same environment.
- **Python:** select `.pixi/envs/default/bin/python` as the interpreter.

## Updating and cleaning

```bash
pixi update           # new versions within the constraints, rewrites pixi.lock
pixi run clean        # workspace build artifacts
rm -rf .pixi          # the whole environment (pixi install recreates it)
pixi clean cache      # global package cache (~/.cache/rattler)
```

## Known issues

- **Platforms outside linux-64 aren't tested yet.** The lockfile resolves for
  `osx-arm64` and `win-64` (every EasyNav dependency is in RoboStack), but nobody has
  built on them yet.
- **Flaky tests in parallel:** some node tests (e.g. `localizer_node_tests`) crash when
  colcon runs several packages' tests at once. The shared colcon defaults use
  `parallel-workers: 1`, like EasyNav's CI.
- **A ROS install sourced in `~/.bashrc`** gets mixed with the pixi environment. Remove
  it, or keep pixi in a clean shell.
- **`ros2 daemon`** survives across environments. If `ros2 node list` comes back empty
  after switching distros, run `ros2 daemon stop`.

## Pros and cons

| 👍 | 👎 |
|---|---|
| No root, no system changes, Linux/macOS/Windows from the same file | Only what RoboStack (or your channel) packages exists |
| `pixi.lock`: reproducible down to the last library | New distros/packages lag a bit behind the ROS buildfarm |
| Several distros side by side, one per folder | Several GB per environment (hard-linked from a shared cache) |
| Tasks (`pixi run build`) document the workflow | Another tool for the team to learn |
