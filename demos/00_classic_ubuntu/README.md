# The classic way: Ubuntu + apt

> **Fits:** Paco (Ubuntu). It's the only persona apt works for at all. This is the
> reference point, the "install Ubuntu and forget about it" that the talk starts from.

On a Tier 1 platform ([REP-2000](https://www.ros.org/reps/rep-2000.html)), ROS 2 comes
as official binary packages. For rolling, that platform is Ubuntu 26.04. This is the
path the documentation recommends, and the one every other demo is measured against.

No demonstrator here: the [container](../02_containers/) and
[distrobox](../03_distrobox/) demos run exactly these steps, just inside an Ubuntu
container.

## Setup

```bash
# ROS 2 apt repository
sudo apt install software-properties-common curl
sudo add-apt-repository universe
export ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F "tag_name" | awk -F\" '{print $4}')
curl -L -o /tmp/ros2-apt-source.deb "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo ${UBUNTU_CODENAME:-${VERSION_CODENAME}})_all.deb"
sudo dpkg -i /tmp/ros2-apt-source.deb

# ROS 2 + development tools
sudo apt update
sudo apt install ros-rolling-ros-base ros-dev-tools
source /opt/ros/rolling/setup.bash

# Workspace and its dependencies
cd demos/00_classic_ubuntu
mkdir -p src && vcs import --input ../../common/easynav.repos src
sudo rosdep init && rosdep update
rosdep install --from-paths src --ignore-src -y
```

Rolling has no EasyNav apt packages. On humble/jazzy/kilted/lyrical,
`sudo apt install ros-<distro>-easynav` installs it without building anything.

## Daily development loop

```bash
source /opt/ros/rolling/setup.bash
export COLCON_DEFAULTS_FILE=../../common/colcon_defaults.yaml
colcon build
colcon test && colcon test-result --verbose
source install/setup.bash
ros2 run easynav_system system_main --ros-args --params-file ../../common/params/dummy.params.yaml
```

## Pros and cons

| 👍 | 👎 |
|---|---|
| The path that's documented and tested by the buildfarm | Only the matching Ubuntu (one Ubuntu per ROS distro) |
| Binary packages: zero build time for ROS itself | One distro per system, and it changes the system (`/opt`, `apt`) |
| What every tutorial assumes | Upgrading the OS means changing ROS distro |
