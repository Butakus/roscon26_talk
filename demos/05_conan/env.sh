# Development environment for the Conan workspace (Linux/macOS).
#   source env.sh
# Run "conan install" first (see README.md).
_ws="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"

# 1. Python 3.12 venv with colcon and the linters (same Python ros-kilted was built for)
source "${_ws}/.venv/bin/activate"
# 2. ROS 2 kilted from the Conan cache (+ CMAKE_TOOLCHAIN_FILE) and build tools (uncrustify)
source "${_ws}/build/Release/generators/conanbuild.sh"
source "${_ws}/build/Release/generators/conanrosenv.sh"
# 3. colcon settings for this workspace
export COLCON_DEFAULTS_FILE="${_ws}/colcon_defaults.yaml"
# 4. The workspace overlay, once built
if [ -f "${_ws}/install/setup.sh" ]; then
  COLCON_CURRENT_PREFIX="${_ws}/install" . "${_ws}/install/setup.sh"
fi
unset _ws
