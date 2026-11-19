source /opt/ros/jazzy/setup.bash
export ECAT_INSTALL_PREFIX=/ws/code_ws/install
export CMAKE_PREFIX_PATH="${ECAT_INSTALL_PREFIX}${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}"
export LD_LIBRARY_PATH="${ECAT_INSTALL_PREFIX}/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PATH="${ECAT_INSTALL_PREFIX}/bin:$PATH"
export PKG_CONFIG_PATH="${ECAT_INSTALL_PREFIX}/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
source /ws/configs/ecat-miranda-config/setup.sh
source /ws/ros2_ws/install/setup.bash

if [ -f /ws/user_ros2_ws/install/setup.bash ]; then
    source /ws/user_ros2_ws/install/setup.bash
fi