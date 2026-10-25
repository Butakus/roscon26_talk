# syntax=docker/dockerfile:1
#
# EasyNav on top of ROS 2 built entirely from source, following navigation2's
# tools/source.Dockerfile:
# https://github.com/ros-navigation/navigation2/blob/main/tools/source.Dockerfile
#
#   osrf/ros2:devel             build tools only (colcon, rosdep, vcs): no ROS packages
#   └── ros2_ws     /opt/ros2_ws      ROS 2 rolling from ros2.repos (pruned to what EasyNav needs)
#       └── underlay /opt/underlay_ws  non-core dependencies (underlay.repos)
#           └── overlay /opt/overlay_ws src/EasyNavigation, the code you work on
#
# Build context is this directory. Needs BuildKit (default in Docker; Podman supports
# the cache mounts too).
#
#   docker build --target dever -t easynav:source-dever .                            # devcontainer
#   docker build --target overlay_tester --build-arg RUN_TESTS=1 -t easynav:source-tester .   # CI
ARG FROM_IMAGE=docker.io/osrf/ros2:devel
ARG ROS2_WS=/opt/ros2_ws
ARG UNDERLAY_WS=/opt/underlay_ws
ARG OVERLAY_WS=/opt/overlay_ws

# multi-stage for caching
FROM $FROM_IMAGE AS cacher

# clone ros2 source
ARG ROS2_WS
ARG ROS2_BRANCH=rolling
ARG ROS2_REPO=https://github.com/ros2/ros2.git
WORKDIR $ROS2_WS/src
RUN git clone $ROS2_REPO -b $ROS2_BRANCH && \
    vcs import ./ < ros2/ros2.repos && \
    find ./ -name ".git" | xargs rm -rf

# clone underlay source
ARG UNDERLAY_WS
WORKDIR $UNDERLAY_WS/src
COPY ./underlay.repos ../
RUN vcs import ./ < ../underlay.repos && \
    find ./ -name ".git" | xargs rm -rf

# copy overlay source
ARG OVERLAY_WS
WORKDIR $OVERLAY_WS/src
COPY ./src/EasyNavigation ./EasyNavigation
COPY ./keep-packages.txt /tmp/
RUN colcon list --names-only | cat >> /opt/packages.txt && \
    grep -v '^#' /tmp/keep-packages.txt >> /opt/packages.txt

# remove skipped packages: ignored ones, the RMWs we do not build, and every
# package that neither the overlay nor keep-packages.txt depends on (most of ros2.repos)
WORKDIR /opt
COPY ./rmw-ignore.txt /tmp/
RUN find ./ \
      -name "AMENT_IGNORE" -o \
      -name "CATKIN_IGNORE" -o \
      -name "COLCON_IGNORE" \
      | xargs dirname | xargs rm -rf || true && \
    colcon list --paths-only \
      --packages-select $(grep -v '^#' /tmp/rmw-ignore.txt | xargs) \
      | xargs rm -rf && \
    colcon list --paths-only \
      --packages-skip-up-to \
        $(cat packages.txt | xargs) \
      | xargs rm -rf

# copy manifests for caching
RUN mkdir -p /tmp/opt && \
    find ./ -name "package.xml" | \
      xargs cp --parents -t /tmp/opt

# multi-stage for ros2 dependencies
FROM $FROM_IMAGE AS ros2_depender
ARG DEBIAN_FRONTEND=noninteractive

# edit apt for caching
RUN cp /etc/apt/apt.conf.d/docker-clean /etc/apt/ && \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' \
      > /etc/apt/apt.conf.d/docker-clean

# install packages
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && apt-get install -q -y \
      ccache \
      lld \
    && rosdep update --rosdistro rolling

ENV ROS_VERSION=2 \
    ROS_PYTHON_VERSION=3 \
    ROS_DISTRO=rolling

# install ros2 dependencies
ARG ROS2_WS
WORKDIR $ROS2_WS
COPY --from=cacher /tmp/opt/ros2_ws ./
COPY ./skip-keys.txt /tmp/
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && rosdep install -q -y \
      --from-paths src \
      --ignore-src \
      --skip-keys " \
        $(grep -v '^#' /tmp/skip-keys.txt | xargs) \
        "

# multi-stage for building ros2
FROM ros2_depender AS ros2_builder

# build ros2 source (ROS 2's own tests are not built: they double the build time)
ARG ROS2_WS
COPY --from=cacher $ROS2_WS ./
ARG ROS2_MIXINS="release ccache lld"
RUN --mount=type=cache,target=/root/.ccache \
    colcon build \
      --symlink-install \
      --mixin $ROS2_MIXINS \
      --cmake-args -DBUILD_TESTING=OFF

# multi-stage for underlay dependencies
FROM ros2_depender AS underlay_depender

# install underlay dependencies
ARG UNDERLAY_WS
WORKDIR $UNDERLAY_WS
COPY --from=cacher /tmp/opt/underlay_ws ./
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && rosdep install -q -y \
      --from-paths src \
        $ROS2_WS/src \
      --ignore-src \
      --skip-keys " \
        $(grep -v '^#' /tmp/skip-keys.txt | xargs) \
      "

# multi-stage for building underlay
FROM underlay_depender AS underlay_builder

# copy workspace for caching
ARG ROS2_WS
COPY --from=ros2_builder $ROS2_WS $ROS2_WS

# build underlay source
COPY --from=cacher $UNDERLAY_WS ./
ARG UNDERLAY_MIXINS="release ccache lld"
RUN --mount=type=cache,target=/root/.ccache \
    . $ROS2_WS/install/setup.sh && \
    colcon build \
      --symlink-install \
      --mixin $UNDERLAY_MIXINS \
      --cmake-args -DBUILD_TESTING=OFF

# multi-stage for overlay dependencies
FROM underlay_depender AS overlay_depender

# copy manifests for caching
ARG UNDERLAY_WS
COPY --from=cacher /tmp/opt/underlay_ws $UNDERLAY_WS

# install overlay dependencies
ARG OVERLAY_WS
WORKDIR $OVERLAY_WS
COPY --from=cacher /tmp/opt/overlay_ws ./
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && rosdep install -q -y \
      --from-paths src \
        $ROS2_WS/src \
        $UNDERLAY_WS/src \
      --ignore-src \
      --skip-keys " \
        $(grep -v '^#' /tmp/skip-keys.txt | xargs) \
      "

# copy built workspaces
ARG ROS2_WS
COPY --from=ros2_builder $ROS2_WS $ROS2_WS
COPY --from=underlay_builder $UNDERLAY_WS $UNDERLAY_WS
ENV ROS2_WS=$ROS2_WS \
    UNDERLAY_WS=$UNDERLAY_WS \
    OVERLAY_WS=$OVERLAY_WS

# multi-stage for building overlay
FROM overlay_depender AS overlay_builder

# build overlay source
COPY --from=cacher $OVERLAY_WS ./
ARG OVERLAY_MIXINS="release ccache lld"
RUN --mount=type=cache,target=/root/.ccache \
    . $UNDERLAY_WS/install/setup.sh && \
    colcon build \
      --symlink-install \
      --mixin $OVERLAY_MIXINS

# multi-stage for testing overlay
FROM overlay_builder AS overlay_tester

# test overlay build
ARG RUN_TESTS
ARG FAIL_ON_TEST_FAILURE
RUN if [ -n "$RUN_TESTS" ]; then \
        . install/setup.sh && \
        colcon test --parallel-workers 1 && \
        colcon test-result \
          || ([ -z "$FAIL_ON_TEST_FAILURE" ] || exit 1) \
    fi

# multi-stage for developing (devcontainer target)
FROM overlay_depender AS dever

# restore apt for docker
RUN mv /etc/apt/docker-clean /etc/apt/apt.conf.d/

# install developer dependencies
RUN apt-get update && \
    apt-get install -y \
      bash-completion \
      clangd \
      gdb

# source underlay for shell
RUN echo 'source "$UNDERLAY_WS/install/setup.bash"' >> /etc/bash.bashrc
