# Containers: Docker / Podman + Dev Containers

> **Fits:** Paco, Javi and Marta. On Bluefin, containers are how you're meant to work.
> Lucía only through Docker Desktop's VM. Not Sara: WSL2 and Docker Desktop need admin
> rights. Also for any team that wants everyone on exactly the same Ubuntu.

The image holds Ubuntu 26.04 + ROS 2 rolling + every dependency of EasyNav (installed
with `rosdep`). **The code is not inside the image**: the repository is bind-mounted,
so you edit on the host and build in the container.

This is the simple version: a single image used as an environment. For dependencies
built from source and a CI image, see the [navigation2-style version](../01_source_build/).

| | |
|---|---|
| ROS 2 distro | rolling (`ROS_DISTRO` build arg: any distro with an official `ros` image) |
| Platforms | Linux (Docker or rootless Podman, tested) · Windows (Docker Desktop/WSL2) · macOS (Docker Desktop/OrbStack) |
| Root needed | No with rootless Podman; Docker needs its daemon |
| Disk | Image 5.3 GB (base `ros:rolling-ros-base` 1.1 GB) + workspace ~1 GB |
| Time (16 cores) | Image build 4 min · colcon build 2.5 min · tests 4 min |

## Files

| File | What it does |
|---|---|
| `Dockerfile` | `ros:rolling-ros-base` + dev tools + `rosdep install` of EasyNav's dependencies |
| `compose.yaml` | Run it without VS Code (`docker compose` / `podman compose`) |
| `.devcontainer/devcontainer.json` | VS Code: *Dev Containers: Reopen in Container* |

## One-time setup

**VS Code:** install the *Dev Containers* extension, open `demos/02_containers` and run
*Reopen in Container*. The first time, it builds the image and clones the sources
(`postCreateCommand`). With Podman, set `"dev.containers.dockerPath": "podman"` and add
`--userns=keep-id` to `runArgs`.

**Terminal:**

```bash
cd demos/02_containers
mkdir -p src && vcs import --input ../../common/easynav.repos src   # on the host
docker compose build          # or: podman compose build
```

## Daily development loop

```bash
docker compose run --rm dev   # a shell in the container, already in demos/02_containers
colcon build
colcon test && colcon test-result --verbose
ros2 run easynav_system system_main --ros-args --params-file ../../common/params/dummy.params.yaml

../../common/scripts/demo.sh  # all of the above
```

Without compose (rootless Podman), from the repository root:

```bash
podman build -f demos/02_containers/Dockerfile -t easynav-dev:rolling .
podman run --rm -it --network=host --ipc=host --userns=keep-id \
  -v "$PWD":/workspaces/roscon26_talk:z easynav-dev:rolling
```

`build/` and `install/` live on the host (in the mounted folder), so they survive the
container. With `--userns=keep-id` (Podman) or UID 1000 (Docker), they belong to your user.

## Adding a dependency

1. Add it to the `package.xml`.
2. In the running container, to test right away:
   `sudo apt update && rosdep install --from-paths src --ignore-src -y`.
3. To make it permanent for everyone, rebuild the image (`docker compose build`).
   The `rosdep install` in the Dockerfile picks it up from the `package.xml` files.

## IDE integration

- **Dev Containers:** VS Code runs *inside* the container, with clangd and ROS
  extensions. `build/compile_commands.json` works directly.
- **Without VS Code:** any editor on the host. Paths in `compile_commands.json` are
  container paths (`/workspaces/...`), so clangd on the host needs the same path or a
  path mapping.

## Updating and cleaning

```bash
docker compose build --pull --no-cache   # new ROS packages / base image
rm -rf build install log                 # workspace
docker image rm easynav-dev:rolling
```

## Known issues

- **GUI tools (rviz2, rqt):**
  - Linux: also mount `/tmp/.X11-unix` (or the Wayland socket).
  - Windows: WSLg handles it.
  - macOS: you need an X server (XQuartz).

  This demo doesn't need a GUI.
- **DDS between containers and the host:** `network_mode: host` makes it simple. On
  Docker Desktop (Windows/macOS), "host" is the Linux VM, not your machine.
- **Official Docker setup with Zenoh** (cross-distro):
  [easynavigation.github.io/0.5.0/howtos/docker_crossdistro.html](https://easynavigation.github.io/0.5.0/howtos/docker_crossdistro.html).

## Pros and cons

| 👍 | 👎 |
|---|---|
| Real Ubuntu + official apt packages: ROS 2's Tier 1 | Another layer: GUI, devices and networking need extra flags |
| Same image for everyone, and for CI | Large images; rebuild for every dependency change |
| Works on Windows/macOS through Docker Desktop | Docker Desktop needs a license in large companies, plus a VM |
| Host stays clean; throw away and start over | Two worlds (host/container) for paths, users and editors |
