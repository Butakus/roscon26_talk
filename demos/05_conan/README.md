# Conan: ROS 2 as one more C++ dependency

> **Fits:** any of the five, with caveats (kilted only, and the first build compiles
> ROS 2). It shines when the project is C++ and already lives in the Conan world, e.g. a
> company with its own Conan server: ROS 2 becomes one more dependency.

[ros-conan](https://github.com/conan-io/ros-conan) builds ROS 2 **from source** with
Conan: no `rosdep`, `apt`, `brew` or `choco`. Third-party libraries (OpenCV, PCL, Boost,
Qt…) come from ConanCenter. Each binary is built once, cached, and can be uploaded to a
company server so nobody has to build it again.

| | |
|---|---|
| ROS 2 distro | **kilted** (the only distro ros-conan offers) · EasyNav branch `kilted` |
| Platforms | Linux (tested) · Windows, macOS (supported by ros-conan, not tested here) |
| Root needed | No (except possibly system dev packages: see `profiles/ros`) |
| Disk | Conan package ~1.7 GB, but **~13 GB** of build folders in the cache |
| Time (16 cores) | `conan install --build=missing` ~15 min* · workspace build ~2 min · tests 3.5 min |

\* The cache already held some dependencies (from an earlier `core` build). Expect more
from scratch, and close to zero once the binaries are on a Conan server.

## Files

| File | What it does |
|---|---|
| `conanfile.py` | `ros-kilted` (variant `desktop`) plus the libraries EasyNav needs (see below) |
| `profiles/ros` | Based on ros-conan's profile: C++17, Python 3.12, system packages in `check` mode |
| `requirements.txt` | colcon, linters and `ros2cli` runtime deps for a Python 3.12 venv (pins from the recipe) |
| `colcon_defaults.yaml` | `common/colcon_defaults.yaml` plus what this workspace needs |
| `env.sh` | Activates venv + Conan environment + colcon settings + overlay |
| `../../common/easynav_kilted.repos` | EasyNav and yaets (`kilted`) + `vision_msgs`, which `desktop` doesn't include |

## One-time setup

```bash
# 1. Conan 2 and the ros-conan recipes (a local recipe index)
pip install conan            # or pipx / uv tool
conan profile detect
git clone https://github.com/conan-io/ros-conan ~/conan/ros-conan
conan remote add ros-conan ~/conan/ros-conan --type=local-recipes-index

# 2. Build/fetch ROS 2 kilted and the dependencies (the slow part, run it once)
cd demos/05_conan
conan install . --profile=./profiles/ros --build=missing

# 3. Python 3.12 venv (must match ros-kilted's python_version)
python3.12 -m venv .venv
.venv/bin/pip install -r requirements.txt

# 4. Sources
mkdir -p src && vcs import --input ../../common/easynav_kilted.repos src
```

On Windows, replace step 3 with `py -3.12 -m venv .venv` and use the `.bat` scripts in
`build\generators\` (`conanrosenv.bat`, `conanbuild.bat`) instead of `env.sh`.

## Daily development loop

```bash
source env.sh                    # venv + conanbuild.sh + conanrosenv.sh + overlay
colcon build                     # flags in colcon_defaults.yaml
colcon test && colcon test-result --verbose
ros2 run easynav_system system_main --ros-args --params-file ../../common/params/dummy.params.yaml

../../common/scripts/demo.sh     # all of the above
```

`ros2`, `colcon` and the ROS libraries come from the Conan cache.
`build/Release/generators/` is Conan's, while every other folder under `build/` is
colcon's. They share `build/` without problems.

## Adding a dependency

- **A ROS package that ros-kilted doesn't ship** (like `vision_msgs`): add its repo to
  `common/easynav_kilted.repos` and build it in the workspace.
- **A C/C++ library:** add `self.requires("lib/x.y.z")` to `conanfile.py`, run
  `conan install` again, and `find_package()` it as usual (CMakeDeps generates the config).
- **A Python package:** add it to `requirements.txt`.
- **A whole stack:** change the `ros-kilted/*:variant` option (`core`, `base`,
  `desktop`, `desktop_full` (WIP)) and rebuild the cache.

## What it took to get EasyNav building (talk material)

Each of these is in `conanfile.py`, with a comment explaining it:

1. **Missing configs.** `ros-kilted` doesn't propagate some of its requirements
   (console_bridge, Eigen, fmt, spdlog, tinyxml2, yaml-cpp), but the CMake configs it
   installs still `find_package()` them. They have to be required again, **at the same
   version** as the recipe.
2. **Missing headers.** OpenCV and PCL arrive with `headers=False` through ros-kilted,
   while the `cv_bridge` and `pcl_conversions` headers include theirs. Fix: require them
   directly.
3. **Static libraries.** Everything in ConanCenter is static by default, and the ROS
   `.so` files don't re-export those symbols:
   - Libraries used from headers compiled into EasyNav (OpenCV, PCL, tinyxml2,
     console_bridge) must be linked.
   - The rest go in with `libs=False`.
4. **`CMAKE_BUILD_TYPE`.** `easynav_sensors/CMakeLists.txt` forces it to `DEBUG`, and
   Conan targets only define their Release properties.
   `-DCMAKE_MAP_IMPORTED_CONFIG_DEBUG=Release` (in `colcon_defaults.yaml`) maps one onto
   the other. *That line should be removed from EasyNav itself.*
5. **Python.** colcon, the linters and `ros2cli`'s deps must live in a **Python 3.12**
   venv. Without `psutil`, `ros2 node list` fails with `KeyError: 'list'`, because
   `ros2cli` silently drops verbs that fail to import.

## IDE integration

Run `source env.sh` and launch the editor from that shell (`code .`).
`build/compile_commands.json` is generated by colcon. On Windows, open a "Developer
PowerShell", because `VCVars` (generated by Conan) sets up MSVC.

## Updating and cleaning

```bash
conan install . --profile=./profiles/ros --build=missing --update   # newer recipes
rm -rf install log && find build -mindepth 1 -maxdepth 1 ! -name Release -exec rm -rf {} +   # workspace only
conan cache clean "*" --build --temp    # free the ~13 GB of build folders
conan remove "ros-kilted/*" -c          # remove ROS from the cache entirely
```

## Known issues

- **Crash on exit in some tests** (`double free or corruption` in
  `rcl_logging_spdlog`): every gtest passes, but 11 binaries abort after the last test.
  The backtrace shows the destruction order at exit, between `rclcpp::Context` and the
  copy of spdlog that ros-kilted links statically into `librcl_logging_spdlog.so`.
  `system_main` isn't affected. This is a ros-conan issue to report upstream.
- `Unable to Register SHM Transport`: Fast DDS in ros-kilted is built without shared
  memory, so it falls back to UDP. Harmless.
- `vision_msgs_rviz_plugins` doesn't build (Qt headers): skipped in `colcon_defaults.yaml`.
- The kilted branch has fewer tests than rolling (1429 vs 1762).

## Pros and cons

| 👍 | 👎 |
|---|---|
| The same tool the company already uses for C++ | ROS 2 builds from source the first time (slow, big cache) |
| Binaries can be shared through a Conan server | Only kilted, and `desktop_full` is still WIP |
| Windows/macOS/Linux, with no system ROS | ROS + Conan packaging gaps (see above): you become the integrator |
| Fine-grained control over every library and its options | The Python side (venv, versions) is managed by hand |
