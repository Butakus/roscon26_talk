# Development image for EasyNav: ROS 2 + every dependency of the workspace.
# The source code is NOT baked in: it is bind-mounted from the host, so you
# edit with your usual tools and build inside the container.
#
# Build context is the repository root (it needs common/easynav.repos):
#   docker build -f demos/02_containers/Dockerfile -t easynav-dev:rolling .
ARG ROS_DISTRO=rolling
FROM docker.io/library/ros:${ROS_DISTRO}-ros-base

# Dev tools on top of ros-base
RUN apt-get update && apt-get install -y --no-install-recommends \
      clangd \
      gdb \
      git \
      python3-colcon-common-extensions \
      python3-vcstool \
      sudo \
    && rm -rf /var/lib/apt/lists/*

# Install the workspace dependencies with rosdep from the package.xml files.
# Sources are cloned only for this step and then removed.
COPY common/easynav.repos /tmp/easynav.repos
RUN mkdir -p /tmp/deps_ws/src \
    && vcs import --input /tmp/easynav.repos /tmp/deps_ws/src \
    && apt-get update \
    && rosdep update --rosdistro "${ROS_DISTRO}" \
    && rosdep install --from-paths /tmp/deps_ws/src --ignore-src -y -r \
    && rm -rf /tmp/deps_ws /var/lib/apt/lists/*

# Non-root user. The Ubuntu base image already has "ubuntu" (UID/GID 1000),
# which matches the first user on most Linux hosts.
RUN echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu \
    && echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> /home/ubuntu/.bashrc \
    && echo '[ -f install/setup.bash ] && source install/setup.bash' >> /home/ubuntu/.bashrc
USER ubuntu

# The whole repository is mounted here (same path as a VS Code devcontainer)
ENV REPO=/workspaces/roscon26_talk
ENV COLCON_DEFAULTS_FILE=${REPO}/common/colcon_defaults.yaml
WORKDIR ${REPO}/demos/02_containers
CMD ["bash"]
