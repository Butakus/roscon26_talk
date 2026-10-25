from conan import ConanFile
from conan.tools.cmake import cmake_layout


class EasyNavWorkspace(ConanFile):
    """ROS 2 kilted (ros-conan) + the third-party libraries EasyNav needs."""

    settings = "os", "arch", "compiler", "build_type"
    generators = "CMakeToolchain", "CMakeDeps", "VCVars", "ROSEnv"

    # "desktop" brings OpenCV, PCL, cv_bridge and pcl_conversions.
    # vision_msgs is not included: it is built in the workspace (common/easynav_kilted.repos).
    default_options = {"ros-kilted/*:variant": "desktop"}

    def requirements(self):
        self.requires("ros-kilted/2026.06.17")

        # ros-kilted does not propagate the headers of these libraries, but the
        # headers and CMake configs it installs (class_loader, cv_bridge, rcl_logging...)
        # still need them. They are static and already linked inside the ROS
        # shared libraries: linking them again gives "double free" crashes at exit.
        # Headers only, same versions as the ros-kilted recipe.
        for ref in ("eigen/3.4.0", "fmt/10.2.1",
                    "spdlog/1.12.0", "yaml-cpp/0.8.0"):
            self.requires(ref, headers=True, libs=False)

        # These are used from headers compiled into EasyNav (cv_bridge, pluginlib
        # templates, PCL) and the ROS libraries do not export their symbols:
        # they must be linked.
        self.requires("console_bridge/1.0.2")
        self.requires("opencv/4.12.0")
        self.requires("tinyxml2/10.0.0")
        self.requires("pcl/1.14.1")

    def build_requirements(self):
        # Needed by the ament_uncrustify linter (colcon test)
        self.tool_requires("uncrustify/0.78.1")

    def layout(self):
        cmake_layout(self)
