# ROS 2 from source, the navigation2 way: everything in Docker

> **Persona:** the contributor. Someone who works against the **latest ROS 2 code**
> (unreleased fixes, a patch in `rclcpp`, a not-yet-released distro), and wants the
> whole team and the CI to get exactly the same result.

ROS 2 is built **from source** from `ros2.repos`, but inside a multi-stage image instead
of directly on your system. This copies navigation2's
[`tools/source.Dockerfile`](https://github.com/ros-navigation/navigation2/blob/main/tools/source.Dockerfile),
with a devcontainer in the style of
[nav2's](https://github.com/ros-navigation/navigation2/tree/main/.devcontainer):

```
osrf/ros2:devel                 Ubuntu 26.04 + build tools (colcon, rosdep, vcs). No ROS packages
└── /opt/ros2_ws                ROS 2 rolling from ros2.repos, pruned to what EasyNav needs (169 packages)
    └── /opt/underlay_ws        non-core dependencies from source (underlay.repos: perception, yaets…)
        └── /opt/overlay_ws     src/EasyNavigation, the code you work on
```

> nav2 actually has **two** Dockerfiles. The main one (used by its devcontainer and its
> CI image) starts from `ros:rolling` **binaries** and only builds the underlay from
> source. `tools/source.Dockerfile` builds all of ROS 2. This demo uses the second one,
> plus nav2's devcontainer approach.

| | |
|---|---|
| ROS 2 distro | rolling, from the `rolling` branch of `ros2/ros2` (`ROS2_BRANCH` build arg) |
| Platforms | Linux (Docker, tested) · Windows (Docker Desktop/WSL2) · macOS (Docker Desktop) |
| Root needed | Docker's daemon, or rootless Podman |
| Disk | Image `dever` 7.1 GB (`overlay_tester` 8.2 GB) + overlay and ccache volumes |
| Time (16 cores) | Image from scratch 15 min (ROS 2: 6 min) · with warm ccache, ROS 2 in 2.5 min · EasyNav 3 min |

## Why not build ROS 2 from source directly on your system?

That was the first version of this demo, on Fedora 44. It's possible:
- Without root you get almost everything done (venv, `ROSDEP_SOURCE_PATH`, building
  only the necessary packages).
- But you still need 39 system packages through `dnf`.
- rosdep rules for non-Tier-1 distros are incomplete.
- Fedora's toolchain (Python 3.14, GCC 16, CMake 4.3) is newer than any Tier 1 platform.
- Every developer ends up with a slightly different setup.

Inside Docker, the same build runs on the Tier 1 Ubuntu, identical for everyone.
**Building natively on the host only appears in the slides, as "not recommended".**

## Dockerfile stages

| Stage | What it does |
|---|---|
| `cacher` | Clones `ros2.repos` and `underlay.repos`, and copies `src/EasyNavigation`. **Prunes**: removes the RMWs that aren't built (`rmw-ignore.txt`) and any package that neither the overlay nor `keep-packages.txt` depends on (`colcon list --packages-skip-up-to`). Extracts the `package.xml` files so dependency layers are only redone when they change |
| `ros2_depender` → `ros2_builder` | `rosdep install` and build of ROS 2 (`release ccache lld`, no tests) |
| `underlay_depender` → `underlay_builder` | Same for the underlay, on top of `ros2_ws` |
| `overlay_depender` | Overlay dependencies, plus the already built `ros2_ws` and `underlay_ws` |
| `overlay_builder` → `overlay_tester` | Builds EasyNav and, with `RUN_TESTS=1`, runs the tests. This is what the CI uses |
| `dever` | `overlay_depender` + dev tools. The devcontainer target |

ccache and apt use BuildKit cache mounts (`--mount=type=cache`), the same as in nav2. When
`ros2.repos` changes, rebuilding the image recompiles with a warm ccache.

## Files

| File | What it does |
|---|---|
| `Dockerfile` | The stages above |
| `underlay.repos` | Non-core dependencies, from source: yaets, vision_opencv, perception_pcl, pcl_msgs, vision_msgs, python_cmake_module |
| `rmw-ignore.txt` | RMWs left out: Zenoh needs Rust, Connext needs RTI, Cyclone pulls iceoryx. Only Fast DDS is built |
| `keep-packages.txt` | Packages kept even if EasyNav doesn't depend on them: the `ros2` CLI (`ros2cli_common_extensions`). Without it, the pruning removes `ros2 run`, `ros2 node`… |
| `skip-keys.txt` | rosdep keys not to install (as in nav2's `tools/skip_keys.txt`) |
| `.devcontainer/devcontainer.json` | Target `dever`. Only `src/EasyNavigation` is bind-mounted; the overlay lives in a volume |
| `compose.yaml` | `dev` (the same as the devcontainer) and `test` (CI image, profile `ci`) without VS Code |

## One-time setup

```bash
cd demos/01_source_build
git clone -b rolling https://github.com/EasyNavigation/EasyNavigation.git src/EasyNavigation
```

**VS Code:** open `demos/01_source_build` → *Dev Containers: Reopen in Container*. The
first time, VS Code:
1. Builds the image, including all of ROS 2 (the long part).
2. Creates the `overlay` and `ccache` volumes.
3. Builds EasyNav (`updateContentCommand`).

**Terminal:**

```bash
docker compose build dev
```

## Daily development loop

Inside the devcontainer (or `docker compose run --rm dev`):

```bash
cd $OVERLAY_WS
colcon build --symlink-install --mixin $OVERLAY_MIXINS
colcon test --parallel-workers 1 && colcon test-result --verbose
source install/setup.bash
ros2 run easynav_system system_main --ros-args --params-file /opt/common/params/dummy.params.yaml

COLCON_DEFAULTS_FILE=/opt/common/colcon_defaults.yaml /opt/common/scripts/demo.sh   # the shared demo
```

You edit `src/EasyNavigation` on the host. `build/`, `install/` and `log/` live in the
`overlay` volume (the repo stays clean, and they survive image rebuilds). ccache uses
another volume.

**CI** (or "does it pass against the latest ROS 2?"):

```bash
docker compose --profile ci build test
# or: docker build --target overlay_tester --build-arg RUN_TESTS=1 --build-arg FAIL_ON_TEST_FAILURE=1 .
```

## Updating ROS 2

The ROS 2 sources are cloned while the image builds. To pick up the latest `rolling`:

```bash
docker build --no-cache-filter cacher --target dever -t easynav:source-dever .   # re-clone; ccache does the rest
```

To pin a specific moment, use a fork or a pinned copy of `ros2.repos`
(`--build-arg ROS2_REPO=... --build-arg ROS2_BRANCH=...`).

## Adding a dependency

- **Part of ROS 2 core** (it's in `ros2.repos`): just add it to the `package.xml`. The
  pruning stops discarding it as soon as EasyNav depends on it.
- **A non-core ROS package:** add its repo to `underlay.repos`.
- **A system library:** add it to the `package.xml`, and rosdep installs it with apt.
- **A patch to ROS 2:** point `ROS2_REPO`/`ROS2_BRANCH` (or `underlay.repos`) at your fork.

## IDE integration

The devcontainer installs clangd and generates `/opt/overlay_ws/build/compile_commands.json`
(`compile-commands` mixin). Since ROS 2 is in `/opt/ros2_ws/src`, you can also step
into ROS's own code with the debugger: it's a `release` build, so for proper debugging
change `ROS2_MIXINS` to `debug`.

## Known issues

- Mixins (`colcon mixin`) are configured for `root`, and the container runs as `root`,
  the same as in nav2.
- Some EasyNav node tests are flaky when run in parallel (`--parallel-workers 1`).
- Rolling from source can break on any given day (it's the latest code). That's the
  point of this setup for a contributor, but not for someone who just wants to develop.
  For that, use the [simple container version](../02_containers/) with binaries.

## Measurements

Fedora 44 host, Docker 29.9 (BuildKit), 16 cores. `osrf/ros2:devel` already downloaded.

| Step | Result |
|---|---|
| `overlay_tester` image from scratch (`RUN_TESTS=1`) | **15 min**: ROS 2 rosdep 4 min · ROS 2 build (145 pkgs) 6 min · underlay 30 s · EasyNav 3 min · tests 4 min |
| Same, after changing `ros2_ws` (warm ccache) | 9 min: ROS 2 (169 pkgs) in **2.5 min** |
| Tests | 1737 tests, 0 errors, 0 failures |
| `devcontainer up` (Dev Containers CLI, first time) | 3 min (builds EasyNav in the volume) |
| `devcontainer up --remove-existing-container` | 47 s: the overlay volume survives, so EasyNav rebuilds in 29 s |
| `docker compose run --rm dev` with a new volume | 3 min to build + `demo.sh run` → `active` |
| Shared demo inside the devcontainer | 8 nodes, `/system_node` → `active` |

## Pros and cons

| 👍 | 👎 |
|---|---|
| The latest ROS 2, or your patched fork, built from source but reproducibly | First build: all of ROS 2 (even pruned, it's long) |
| Pruning: only the 169 packages you need, not ~380 | Rolling breaks from time to time: you find out before everyone else |
| Same image for dev (devcontainer) and CI (`overlay_tester`) | Multi-stage, underlay/overlay, BuildKit: a learning curve |
| The host stays clean: no ROS installed, and build artifacts live in volumes | The usual container drawbacks: GUI, devices, networking |
