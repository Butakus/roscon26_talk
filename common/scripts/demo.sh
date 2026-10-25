#!/usr/bin/env bash
# Shared EasyNav demo: build -> test -> run with the Dummy* plugins.
# Run it from a colcon workspace root, inside an environment where ROS 2 is
# already available (sourced, pixi shell, distrobox, container...).
#
#   demo.sh [build|test|run|all]   (default: all)
set -euo pipefail

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PARAMS="${COMMON_DIR}/params/dummy.params.yaml"
RUN_SECONDS="${RUN_SECONDS:-15}"
# Environments with special needs (Conan) bring their own defaults file
export COLCON_DEFAULTS_FILE="${COLCON_DEFAULTS_FILE:-${COMMON_DIR}/colcon_defaults.yaml}"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

do_build() {
  step "colcon build"
  colcon build
}

do_test() {
  step "colcon test"
  colcon test --packages-select-regex 'easynav.*|yaets' --event-handlers console_cohesion- || true
  colcon test-result --verbose || echo "WARNING: some tests failed (see above)"
}

do_run() {
  step "ros2 run easynav_system system_main (${RUN_SECONDS}s)"
  # setup scripts are not 'set -u' safe
  set +u
  # shellcheck disable=SC1091
  source install/setup.bash
  set -u
  # A daemon left running by another environment (e.g. another distro)
  # answers with a stale graph: always start from a fresh one.
  ros2 daemon stop >/dev/null 2>&1 || true
  step "ros2 easynav plugins"
  ros2 easynav plugins
  timeout --signal=INT "${RUN_SECONDS}" \
    ros2 run easynav_system system_main --ros-args --params-file "${PARAMS}" &
  local pid=$!
  sleep 5
  step "ros2 node list"
  ros2 node list
  step "ros2 lifecycle get /system_node"
  ros2 lifecycle get /system_node || true
  step "ros2 easynav nav_state"
  ros2 easynav nav_state --duration 3 || true
  wait "${pid}" || true
}

case "${1:-all}" in
  build) do_build ;;
  test)  do_test ;;
  run)   do_run ;;
  all)   do_build; do_test; do_run ;;
  *) echo "usage: $0 [build|test|run|all]" >&2; exit 1 ;;
esac
