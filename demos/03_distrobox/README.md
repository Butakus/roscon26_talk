# Distrobox: Ubuntu inside your Fedora/Arch, with no barriers

> **Persona:** the pragmatic Fedora (or Arch, or openSUSE…) user who wants ROS 2 *now*,
> from official packages, without leaving their desktop.

[Distrobox](https://distrobox.it/) creates a container (Podman or Docker) that is
**integrated with the host**: same user, same `$HOME`, same network, display and USB
devices. Underneath, it's a real Ubuntu where `apt install ros-rolling-*` works.

| | |
|---|---|
| ROS 2 distro | rolling (official `ros:rolling-ros-base` image, Ubuntu 26.04) |
| Platforms | Linux only (any distro with Podman or Docker) |
| Root needed | No (rootless Podman). `sudo` inside the box works without a password |
| Disk | Container 4.4 GB + workspace ~1 GB |
| Time (16 cores) | Create 1.5 min · rosdep 3 min · build 2.5 min · tests 4 min |

## One-time setup

```bash
cd demos/03_distrobox
distrobox assemble create --file distrobox.ini    # creates the "easynav-rolling" box
mkdir -p src && vcs import --input ../../common/easynav.repos src

distrobox enter easynav-rolling
# --- now inside Ubuntu, in the same folder ---
source /opt/ros/rolling/setup.bash
sudo apt update
rosdep update
rosdep install --from-paths src --ignore-src -y
```

To get ROS sourced automatically **only inside the box**, add this to your `~/.bashrc`
(it's the same file as on the host):

```bash
if [ "${CONTAINER_ID:-}" = "easynav-rolling" ]; then
  source /opt/ros/rolling/setup.bash
  export COLCON_DEFAULTS_FILE=~/roscon26_talk/common/colcon_defaults.yaml
fi
```

## Daily development loop

```bash
distrobox enter easynav-rolling
colcon build
colcon test && colcon test-result --verbose
source install/setup.bash
ros2 run easynav_system system_main --ros-args --params-file ../../common/params/dummy.params.yaml

../../common/scripts/demo.sh    # all of the above
```

Or run a single command from the host without entering:

```bash
distrobox enter easynav-rolling -- bash -c 'source /opt/ros/rolling/setup.bash && colcon build'
```

You edit with the host's editor (the files are the same). `build/` and `install/`
belong to your user.

## Adding a dependency

Same as on Ubuntu: add it to the `package.xml` and run `rosdep install` inside the box.
To make it reproducible, add it to `additional_packages` in `distrobox.ini` (or
recreate the box and rerun `rosdep`).

## IDE integration

- **Editor on the host:** `compile_commands.json` uses `/opt/ros/rolling` paths, which
  only exist inside the box. Two options:
  - Export clangd from the box: `distrobox-export --bin /usr/bin/clangd` inside the box.
    The host's clangd then runs inside the box.
  - Or launch the editor from the box itself: `distrobox enter easynav-rolling -- code .`.
- **GUI apps** (rviz2, rqt) work out of the box: `distrobox-export --app rviz2` even adds
  them to the host's menu.

## Updating and cleaning

```bash
distrobox enter easynav-rolling -- bash -c 'sudo apt update && sudo apt upgrade -y'
distrobox assemble create --replace --file distrobox.ini   # recreate from scratch
distrobox rm easynav-rolling                               # remove it
```

## Known issues

- The box shares `$HOME` with the host. A `source /opt/ros/...` without the
  `CONTAINER_ID` check above breaks your host shell.
- Any ROS state under `~/.ros` (logs, rosdep cache) is shared with the host and with
  other boxes.
- The `ros2 daemon` keeps running between sessions. If you switch distros, run
  `ros2 daemon stop`.

## Pros and cons

| 👍 | 👎 |
|---|---|
| Official ROS packages on any Linux, in two minutes | Linux only |
| Transparent: GUI, USB, network and home just work | Less isolation: a shared home means config files can clash |
| No Dockerfile: it behaves like a normal Ubuntu | Less reproducible than an image (state changes inside the box) |
| Easy to keep several distros (one box each) | Host tools (clangd, IDE) need integrating with the box |
