# Miranda development workspace

This folder is a self-contained build definition. Copy it anywhere; no sibling
`code_ws/`, `ros2_ws/`, or `configs/` directories are required. The build
clones their repositories and initializes submodules inside the image.
The image contains
`/ws/code_ws`, `/ws/ros2_ws`, and `/ws/configs`, with Ubuntu 24.04,
ROS 2 Jazzy, the non-RT EtherCAT stack, Qt GUI tools, Gazebo Harmonic, and
XBot gravity-compensation dependencies. It runs as root for development.
`/ws` holds the editable project; `/opt/ros` and `/opt/xbot`
hold installed dependencies. This directory choice does not add persistence:
the workspace is cloned into the image as described below.

Three Dockerfiles follow this build order:

```text
Dockerfile.dependencies → Dockerfile.ethercat → Dockerfile.ros
```

Compose declares the image dependencies and builds them in that order.
ROS builds can reuse the EtherCAT image. The build context is this folder.
All installation and build commands are written directly in the Dockerfiles.
There are no build helper scripts. The files you need to understand are:

| File | Purpose |
| --- | --- |
| `Dockerfile.dependencies` | Install ROS build tools, system libraries, Gazebo, and XBot |
| `Dockerfile.ethercat` | Install the master and build the EtherCAT libraries and GUI |
| `Dockerfile.ros` | Build the ROS workspace and seed dummy defaults |
| `colcon.meta` | Container paths and non-RT ROS build settings |
| `setup.bash` | Load the environment in container shells |
| `compose.yaml` | Build and run the container, including networking and display forwarding |

The `.dockerignore` file sends only the Dockerfiles, `colcon.meta`, and
`setup.bash` to the builder. There are no host source mounts or absolute
paths to a developer checkout. Git metadata is retained in the cloned
repositories so developers can use Git inside the container.

## Build and open a shell

From this folder:

```bash
cd /path/to/docker
docker compose build workspace
docker compose up -d
docker compose exec workspace bash
```

Or run from any working directory:

```bash
docker compose -f /path/to/docker/compose.yaml up -d --build
```

Compose resolves the build context relative to its file, so your current
working directory does not affect which files are built.

Use Docker Compose 2.17 or newer with BuildKit for the `additional_contexts`
build dependencies. The `dependencies` and `ethercat` services have the
`build` profile so their containers are excluded from normal `up` commands.
They are still included automatically when building `workspace`. You do not
need to enable that profile for the commands above.
This uses Docker's [dependent image builds](https://docs.docker.com/compose/how-tos/dependent-images/).

The entrypoint and every interactive Bash shell load ROS, XBot, EtherCAT,
Miranda configuration, and the ROS overlay. `docker compose exec` should use
`bash -ic 'command'` when running a ROS command directly, for example:

```bash
docker compose exec workspace bash -ic 'ros2 pkg list'
```

Build parallelism defaults to four jobs to limit memory use. Override it with
`BUILD_JOBS=4 docker compose build`. `BUILD_GUI=OFF`
disables the EtherCAT Qt GUI compilation. ROS GUI packages remain available.

The precompiled master is pinned to release 1.0.0 and supports amd64 only.
No private master checkout or SSH credentials are required. The `*_REF`
build arguments in the EtherCAT and ROS Dockerfiles select repository branches,
tags, or commits. The ROS checkout pins its recursive submodules. The defaults
track development branches; use commit hashes when you need fixed source
versions. Override a ref when building, for example:

```bash
docker compose build --build-arg ROS_WS_REF=jazzy_ec/main workspace
```

Host source edits are not included in the build. Rebuilding an unchanged
ref reuses the cached clone; a branch ref can also remain cached.
Use `docker compose build --no-cache workspace` to refresh a branch checkout.
The build needs network access to GitHub and package repositories. Apt/rosdep
dependencies and base-image tags are not locked to a snapshot.

## Dummy master and ROS control

In one container shell:

```bash
repl -d
```

In another container shell:

```bash
ros2 launch advrf_ros2_miranda_bringup miranda.launch.py \
  start_bridge:=true use_joy:=false active_tx_on_first_msg:=true \
  control_mode:=position
```

Master defaults are seeded in `/root/.ecat_master/configs` during the image
build. The non-RT interface is set to `lo` for dummy development, and the dummy
device list is copied from your Miranda configuration. The client protocol
and robot settings come from the selected configuration repository. Edit the container's
master defaults if your dummy setup needs different devices or an interface.
Use the same container for the dummy master and bridge so they share the
non-RT pipes under `/tmp`.

The ROS build uses this folder's `colcon.meta`, with explicit `/ws` paths and
`XENOMAI=OFF`. No host workspace configuration is read. If you add
other package build options, add the container equivalents to this file.

## GUI forwarding

Display forwarding is included in the same Compose file. On Linux with an
accessible X11 socket (including WSLg), use the normal commands:

```bash
docker compose up -d
docker compose exec workspace bash
```

`DISPLAY` and `XAUTHORITY` are forwarded from the host. If your X server uses
an authentication file, export `XAUTHORITY` with its absolute path before
starting Compose. WSLg normally supplies the display socket itself. GPU
acceleration and joystick devices require host-specific device mappings.
Set `X11_SOCKET_DIR` if the host's socket directory is somewhere other than
`/tmp/.X11-unix`. When no authentication file is specified, `/dev/null` is
mounted in its place. With `DISPLAY` unset, the same Compose file supports
terminal-only use; it does not start or require an X server. The short bind
mount syntax may create an empty host socket directory if it is absent.

## Rebuild, persistence, and host requirements

After changing Dockerfiles, build refs, or container build settings, rebuild
and recreate with `docker compose up -d --build`. Edit and build project
sources inside `/ws` during development. Host workspace edits
are independent of these clones. Do not mount a host workspace over
`/ws`: it would hide the libraries built into the image.
Container edits survive stopping, but are lost when the container is removed
or recreated. Copy anything you need to keep back to the host first.

Host networking is used for ROS discovery. Set `ROS_DOMAIN_ID` when starting
Compose to match other ROS machines. Docker Desktop requires host-networking
support to be enabled for communication with external ROS machines.

On WSL, enable Docker Desktop integration for this distro before building.
This branch supports non-RT PC development. It does not include Xenomai
kernel installation or real-time container support.

Stop with `docker compose down`.
