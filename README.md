# Is there life beyond Ubuntu?

Demonstrators for the ROSCon España 2026 talk *"¿Hay vida más allá de Ubuntu?"*: a
survival guide to **developing** (not deploying) ROS 2 from whatever system you like.

The same project, [EasyNavigation](https://github.com/EasyNavigation/EasyNavigation) +
[yaets](https://github.com/fmrico/yaets), is built, tested and run in every environment,
so each comparison runs the same workload.

## Who are you?

| Persona | System | Main demo | Alternatives |
|---|---|---|---|
| 🏢 **Corporate dev**: "Windows only, and no admin rights" | Windows 11 | [Pixi](demos/04_pixi/) | [Containers](demos/02_containers/) (WSL2) · [Conan](demos/05_conan/) if the company already uses it |
| 🍎 **Mac user**: wants `ros2` to just work | macOS (Apple Silicon) | [Pixi](demos/04_pixi/) | [Conan](demos/05_conan/) · [Containers](demos/02_containers/) (with networking/GUI caveats) |
| 🐧 **"I use Arch, BTW"**: everything native or nothing | Arch Linux | [Distrobox](demos/03_distrobox/) | Nix (see below) · ROS 2 from source on the system (slides only, not recommended) |
| 🔧 **The contributor**: the latest ROS 2 from source, same setup as CI | any (Docker/Podman) | [From source, nav2-style](demos/01_source_build/) | [Containers](demos/02_containers/) |
| 🎩 **The Fedora pragmatist** | Fedora | [Distrobox](demos/03_distrobox/) | [Containers](demos/02_containers/) (Podman) · [Pixi](demos/04_pixi/) |
| 📏 **Baseline** | Ubuntu 26.04 | [Classic apt](demos/00_classic_ubuntu/) | — |

## The demo (same everywhere)

[`common/scripts/demo.sh`](common/scripts/demo.sh)
([`demo.ps1`](common/scripts/demo.ps1) on Windows), run from the root of each
environment's workspace, does the following:

1. `colcon build` (settings in [`common/colcon_defaults.yaml`](common/colcon_defaults.yaml))
2. `colcon test` + `colcon test-result`
3. `ros2 run easynav_system system_main` with the **Dummy\*** plugins
   ([`common/params/dummy.params.yaml`](common/params/dummy.params.yaml)): no robot,
   no simulator, no map.
4. `ros2 easynav plugins`, `ros2 node list`, `ros2 lifecycle get /system_node` (→
   `active`) and `ros2 easynav nav_state`.

Sources come from [`common/easynav.repos`](common/easynav.repos) (rolling) or
[`common/easynav_kilted.repos`](common/easynav_kilted.repos) (Conan).

## Comparison

Measured on Fedora 44, 16 cores, 15 GB RAM, October 2026.

| | Classic apt | From source (nav2) | Containers | Distrobox | Pixi | Conan |
|---|---|---|---|---|---|---|
| ROS distro | rolling | rolling | rolling | rolling | rolling | **kilted** |
| Linux / macOS / Windows | Ubuntu only | ✅ / via VM / via WSL2 | ✅ / via VM / via WSL2 | ✅ / ❌ / ❌ | ✅ / ✅* / ✅* | ✅ / ✅* / ✅* |
| Root needed | yes | no (Podman) | no (Podman) | no | **no** | no |
| Setup (ROS + deps) | minutes | 15 min (ROS 2 from source; 2.5 with ccache) | 4 min | 1.5 + 3 min | **1.5 min** | ~15 min** |
| EasyNav build | — | 3 min | 2.5 min | 2.5 min | 2.5 min | 2 min |
| Disk | ~1 GB | 7.1 GB image | 5.3 GB image | 4.4 GB | 4.4 GB | 1.7 GB + 13 GB cache |
| Reproducibility | apt | **image + CI** | image | medium | **lockfile** | lockfile/recipes |
| Integration with host | native | low | low | **high** | high | high |
| Status here | reference | ✅ 1737 tests OK | ✅ 1762 tests OK | ✅ 1762 tests OK | ✅ 1756 tests OK | ✅ runs (see notes) |

\* The lockfile resolves (Pixi) or ros-conan supports it (Conan), but it hasn't been run
on that platform yet.
\*\* Building ROS 2 from source with a partially warm cache. With a company Conan
server, it's a download.

Conan notes: every gtest passes, but 11 binaries crash on exit (spdlog statically linked
inside `rcl_logging_spdlog`). See [its README](demos/05_conan/README.md#known-issues).

## Bonus: Nix (slides only)

[nix-ros-overlay](https://github.com/lopsided98/nix-ros-overlay) packages ROS 2 for Nix:
`nix develop` gives a reproducible environment with a binary cache, on NixOS and on any
Linux (and partly macOS). It's the natural next step for the "Arch BTW" persona, but it
has no demonstrator here.

## Lessons learned (for the talk)

- **Shared setup.** One `colcon_defaults.yaml` + one params file + one script makes the
  comparison honest. The differences show up *only* in how you get into the environment.
- **ros2 daemon.** The daemon outlives your environment. After switching distros, an
  empty `ros2 node list` means `ros2 daemon stop`.
- **Parallel tests.** Some EasyNav node tests are flaky when run in parallel, so
  `parallel-workers: 1` is used (same as upstream CI).
- **Pixi.** The tool where everything worked on the first try (once the 3 `python3-*`
  rosdep keys were mapped to their conda-forge names).
- **Conan** surfaced real bugs, e.g. EasyNav's `easynav_sensors` forces
  `CMAKE_BUILD_TYPE=DEBUG`, and ros-kilted has packaging gaps.
  [Five workarounds](demos/05_conan/README.md#what-it-took-to-get-easynav-building-talk-material)
  later, it builds.
- **From source, nav2-style** (`tools/source.Dockerfile`). All of ROS 2 from source
  (`ros2.repos` pruned to 169 packages with `colcon list --packages-skip-up-to`) +
  underlay + overlay, in a multi-stage image that serves dev (devcontainer) and CI
  alike. It's 15 min the first time, and ROS 2 rebuilds in 2.5 min with ccache. Building all of ROS 2 natively on a non-Tier-1 system (we tried on
  Fedora 44: 150 packages, 39 `dnf` dependencies, Python 3.14/GCC 16) gets a mention in
  the slides as "possible, but not recommended".
