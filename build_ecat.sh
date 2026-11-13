#!/bin/bash
set -e

# Branch versions
SOEM_VERSION=xeno3
MATLOGGER2_VERSION=master
CPPZMQ_VERSION=master
ECAT_MASTER_ADVR_VERSION=main
ECAT_CLIENT_ADVR_VERSION=main

# Precompiled master release (Ubuntu 24.04, amd64, non-RT)
MASTER_BINARY_VERSION=1.0.0
MASTER_BINARY_TAG="master-v${MASTER_BINARY_VERSION}"
MASTER_BINARY_REPO=Advanced-Robotics-Facility/at-setup
MASTER_BINARY_ARCHIVE="ecat-master-${MASTER_BINARY_VERSION}-ubuntu24.04-amd64-nrt.tar.gz"
MASTER_BINARY_URL="https://github.com/${MASTER_BINARY_REPO}/releases/download/${MASTER_BINARY_TAG}/${MASTER_BINARY_ARCHIVE}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if (( $EUID == 0 )); then
    echo "Please do NOT run as root"
    exit
fi

sudo apt install -y dialog

PASSWD="$(dialog --stdout --insecure --passwordbox "Enter ${USER} password:" 0 0)"
clear

echo "### Keep sudo session alive..."
echo "$PASSWD" | sudo -S -v
while true; do
    sudo -nv; sleep 200
    kill -0 $$ 2>/dev/null || exit
done &

# Clean up the download directory and sudo keepalive on exit.
SUDO_KEEPALIVE_PID=$!
MASTER_DOWNLOAD_DIR=""
cleanup() {
    kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    if [ -n "$MASTER_DOWNLOAD_DIR" ]; then
        rm -rf -- "$MASTER_DOWNLOAD_DIR"
    fi
}
trap cleanup EXIT

######################################################################
# Workspace
######################################################################
WS_NAME="$(dialog --stdout --inputbox "Workspace name:" 0 0 "ecat_ws")"
WS_DIR="$(dialog --stdout --inputbox "Workspace parent directory:" 0 0 "$HOME")"
clear

bash "$SCRIPT_DIR/create_ws.sh" "$WS_NAME" "$WS_DIR"

WS_ROOT="$WS_DIR/$WS_NAME"
INSTALL_PREFIX="$WS_ROOT/install"
SRC_DIR="$WS_ROOT/src"
BUILD_DIR="$WS_ROOT/build"

# source the workspace so CMAKE_PREFIX_PATH etc. are set for this session
source "$WS_ROOT/setup.bash"

######################################################################
# Options
######################################################################
if dialog --yesno "Enable Xenomai Real-Time ?" 5 35; then
    USE_XENO=ON
    INFO="RT (Xenomai ON)"
else
    USE_XENO=OFF
    INFO="Non-RT (Xenomai OFF)"
fi

if dialog --yesno "Build GUI tools ?\n(not needed on headless embedded targets)" 7 45; then
    BUILD_GUI=ON
    INFO="$INFO | GUI ON"
else
    BUILD_GUI=OFF
    INFO="$INFO | GUI OFF"
fi

# Xenomai currently requires a source build.
MASTER_INSTALL_METHOD=source

CHOICES="$(dialog --stdout --separate-output --backtitle "${INFO}" \
                  --checklist "Select packages to install/build:" 0 0 0 \
  1 "Install Dependencies" off \
  2 "SOEM" off \
  3 "cppzmq" off \
  4 "MatLogger2" off \
  5 "ecat-master-advr" off \
  6 "ecat-client-advr" off \
  )"
clear

# Ask only when the non-RT master was selected.
if [ "$USE_XENO" = "OFF" ] && printf '%s\n' "$CHOICES" | grep -qx '5'; then
    MASTER_INSTALL_METHOD="$(dialog --stdout --backtitle "${INFO}" \
        --radiolist "How should ecat-master-advr be installed?\n\nPackage: Ubuntu 24.04 amd64, no private repository access needed.\nSource: requires access to the private master repository." \
        15 78 2 \
        package "Download precompiled non-RT package" on \
        source "Build from the private repository" off)"
    clear
fi

######################################################################
# Install Dependencies
######################################################################
install_pkgs() {
    echo "### Installing Required Dependencies"
    sudo apt update
    sudo apt install -y git gitg git-gui build-essential curl cmake cmake-curses-gui libgtest-dev \
                        net-tools openssh-server sshpass curl gnome-terminal terminator \
                        libyaml-cpp-dev libfmt-dev \
                        libzmq3-dev protobuf-compiler libmsgpack-dev libboost-system-dev \
                        libeigen3-dev \
                        libmatio-dev python3-pip \
                        qt6-tools-dev qt6-declarative-dev libqt6charts6-dev uuid-dev libtiff-dev qttools5-dev
}

######################################################################
# SOEM
######################################################################
build_soem() {
    echo "### Building SOEM"
    if [ ! -d $SRC_DIR/SOEM ]; then
        git clone -b ${SOEM_VERSION} https://github.com/alessiomargan/SOEM $SRC_DIR/SOEM
    fi
    mkdir -p $BUILD_DIR/SOEM
    cd $BUILD_DIR/SOEM
    cmake $SRC_DIR/SOEM \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
        -DCMAKE_USE_XENOMAI=$USE_XENO
    make -j$(nproc)
    make install
}

######################################################################
# cppzmq
######################################################################
build_cppzmq() {
    echo "### Building cppzmq"
    if [ ! -d $SRC_DIR/cppzmq ]; then
        git clone -b ${CPPZMQ_VERSION} https://github.com/zeromq/cppzmq $SRC_DIR/cppzmq
    fi
    mkdir -p $BUILD_DIR/cppzmq
    cd $BUILD_DIR/cppzmq
    cmake $SRC_DIR/cppzmq \
        -DCMAKE_BUILD_TYPE="Release" \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
        -DCPPZMQ_BUILD_TESTS=OFF
    make -j$(nproc)
    make install
}

######################################################################
# MatLogger2
######################################################################
build_matlogger() {
    echo "### Building MatLogger2"
    sudo apt install -y libmatio-dev python3-pybind11
    if [ ! -d $SRC_DIR/MatLogger2 ]; then
        git clone -b ${MATLOGGER2_VERSION} https://github.com/ADVRHumanoids/MatLogger2 $SRC_DIR/MatLogger2
    fi
    mkdir -p $BUILD_DIR/MatLogger2
    cd $BUILD_DIR/MatLogger2
    cmake $SRC_DIR/MatLogger2 \
        -DCMAKE_BUILD_TYPE="Release" \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
        -DCOMPILE_PY_BINDINGS=OFF
    make -j$(nproc)
    make install
}

######################################################################
# ecat-master-advr: build from source (RT or non-RT)
######################################################################
build_ecat_master() {
    echo "### Building ecat-master-advr"
    if [ ! -d $SRC_DIR/ecat-master-advr ]; then
        git clone -b ${ECAT_MASTER_ADVR_VERSION} https://github.com/Advanced-Robotics-Facility/ecat-master-advr $SRC_DIR/ecat-master-advr
    fi
    mkdir -p $BUILD_DIR/ecat-master-advr
    cd $BUILD_DIR/ecat-master-advr
    cmake $SRC_DIR/ecat-master-advr \
        -DCMAKE_BUILD_TYPE="Release" \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
        -DBUILD_UDP_SRV=ON \
        -DENABLE_XENO=$USE_XENO
    make -j$(nproc)
    touch install_manifest.txt  # workaround: prevent cmake making it root-owned
    make install
}

######################################################################
# ecat-master-advr: install precompiled package (non-RT only)
######################################################################
install_ecat_master_package() {
    if [ "$USE_XENO" != "OFF" ]; then
        echo "The precompiled master supports only non-RT installations." >&2
        return 1
    fi

    local os_id os_version
    os_id="$(. /etc/os-release; printf '%s' "$ID")"
    os_version="$(. /etc/os-release; printf '%s' "$VERSION_ID")"

    if [ "$os_id" != "ubuntu" ] || [ "$os_version" != "24.04" ] || \
       [ "$(dpkg --print-architecture)" != "amd64" ]; then
        echo "The precompiled master requires Ubuntu 24.04 amd64." >&2
        echo "Run the installer again and select a source build." >&2
        return 1
    fi

    echo "### Installing precompiled ecat-master-advr ${MASTER_BINARY_VERSION}"
    if ! command -v curl >/dev/null 2>&1; then
        sudo apt install -y curl
    fi

    MASTER_DOWNLOAD_DIR="$(mktemp -d)"
    if ! curl --fail --location --retry 3 \
        "$MASTER_BINARY_URL" -o "$MASTER_DOWNLOAD_DIR/$MASTER_BINARY_ARCHIVE"; then
        echo "Failed to download the master package. Check the release URL:" >&2
        echo "$MASTER_BINARY_URL" >&2
        return 1
    fi

    # The archive must contain installation contents directly (bin/, lib/,
    # share/, etc.), without an enclosing workspace or install directory.
    tar -tzf "$MASTER_DOWNLOAD_DIR/$MASTER_BINARY_ARCHIVE" >/dev/null
    mkdir -p "$INSTALL_PREFIX"
    tar --no-same-owner -xzf "$MASTER_DOWNLOAD_DIR/$MASTER_BINARY_ARCHIVE" \
        -C "$INSTALL_PREFIX"

    # Apply scheduling and SOEM network permissions after extracting the binary.
    local repl_bin
    repl_bin="$(readlink -f "$INSTALL_PREFIX/bin/repl")"
    if [ ! -x "$repl_bin" ]; then
        echo "The master package did not install an executable at $INSTALL_PREFIX/bin/repl" >&2
        return 1
    fi
    if ! command -v setcap >/dev/null 2>&1; then
        sudo apt install -y libcap2-bin
    fi
    sudo setcap cap_sys_nice,cap_net_raw,cap_net_admin=ep "$repl_bin"
    getcap "$repl_bin"

    rm -rf -- "$MASTER_DOWNLOAD_DIR"
    MASTER_DOWNLOAD_DIR=""
    echo "### Master installed into $INSTALL_PREFIX"
}

######################################################################
# ecat-client-advr
######################################################################
build_ecat_client() {
    echo "### Building ecat-client-advr"
    if [ ! -d $SRC_DIR/ecat-client-advr ]; then
        git clone -b ${ECAT_CLIENT_ADVR_VERSION} https://github.com/Advanced-Robotics-Facility/ecat-client-advr $SRC_DIR/ecat-client-advr
    fi

    if [ "$BUILD_GUI" = "ON" ]; then
        sudo apt install -y qt6-tools-dev qt6-declarative-dev libqt6charts6-dev \
            uuid-dev libtiff-dev qttools5-dev
    fi

    mkdir -p $BUILD_DIR/ecat-client-advr
    cd $BUILD_DIR/ecat-client-advr
    cmake $SRC_DIR/ecat-client-advr \
        -DCMAKE_BUILD_TYPE="Release" \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
        -DCMAKE_USE_XENOMAI=$USE_XENO \
        -DENABLE_XENO=$USE_XENO \
        -DCOMPILE_GUI=$BUILD_GUI
    make -j$(nproc)
    make install
}

######################################################################
# Run selected steps
######################################################################
for CH in ${CHOICES}; do
    case ${CH} in
        1) install_pkgs ;;
        2) build_soem ;;
        3) build_cppzmq ;;
        4) build_matlogger ;;
        5)
            if [ "$MASTER_INSTALL_METHOD" = "package" ]; then
                install_ecat_master_package
            else
                build_ecat_master
            fi
            ;;
        6) build_ecat_client ;;
        *) ;;
    esac
done

######################################################################
sudo ldconfig

if ! grep -q "$WS_ROOT/setup.bash" ~/.bashrc; then
    echo "source $WS_ROOT/setup.bash" >> ~/.bashrc
    echo "### Added workspace to ~/.bashrc: source $WS_ROOT/setup.bash"
fi

#EC_CFG_PATH="$SRC_DIR/ecat-client-advr/config/ec_cfg.yaml"
#if ! grep -q "EC_CFG" ~/.bashrc; then
#    echo "export EC_CFG=$EC_CFG_PATH" >> ~/.bashrc
#    echo "### Added EC_CFG to ~/.bashrc"
#fi

echo ""
echo "### Done. Run: source ~/.bashrc"

sudo apt autoremove -y
