# EtherCAT and ROS 2 development environment

This branch provides a non-real-time development environment through two
installation paths:

| Installation | Contents | Instructions |
| --- | --- | --- |
| Local | EtherCAT master/client stack installed in a workspace on your machine | Below, using `build_ecat.sh` |
| Docker | EtherCAT stack, ROS 2 Jazzy workspace, Miranda configuration, and development dependencies | [Docker guide](docker/README.md) |

The local installer and workspace creation script remain available for users
who prefer to work without containers. Xenomai kernel installation, system
services, and the previous real-time Docker images are not included in this
branch.

## Local installation

Use Ubuntu 24.04. The precompiled non-RT master supports amd64 (Intel/AMD
64-bit processors). Building the master from source requires access to the
private `ecat-master-advr` repository.

Clone this branch and run the installer as your regular user, without `sudo`:

```bash
git clone --branch feature/non-rt-docker-workspace \
  https://github.com/Advanced-Robotics-Facility/xenomai-ethercat-setup.git
cd xenomai-ethercat-setup
./build_ecat.sh
```

The installer requests sudo access for system packages and permissions. In
the dialogs:

1. Choose a workspace name, such as `code_ws`, and its parent directory,
   such as `/home/your-user/ws`.
2. Answer **No** to **Enable Xenomai Real-Time?** The script retains its
   existing build options, but this branch supplies the non-RT environment.
3. Enable GUI tools if you need the EtherCAT GUI.
4. Select the dependencies and all packages for a complete installation.
5. Select **package** for the master on Ubuntu 24.04 amd64. Select **source**
   only if you have access to the private repository and need to build it.

The installer creates `src/`, `build/`, `install/`, and `setup.bash`, builds
the selected libraries, and adds the workspace environment to `~/.bashrc`.
Load it in your terminal after installation:

```bash
source ~/ws/code_ws/setup.bash
```

Set `EC_CFG` to your robot's client configuration. To use the generic client
configuration as a starting point:

```bash
export EC_CFG=~/ws/code_ws/src/ecat-client-advr/config/ec_cfg.yaml
```

This installer installs the EtherCAT stack. ROS and robot configuration are
set up separately for a local installation. The container installation
includes all three workspaces for Miranda development.

## Create a workspace without installing packages

`create_ws.sh` remains available independently:

```bash
./create_ws.sh code_ws /home/your-user/ws
source /home/your-user/ws/code_ws/setup.bash
```

The parent directory must already exist. If omitted, the parent defaults to
`$HOME`. The script creates an empty CMake workspace and its environment;
it does not download repositories or install dependencies.

## Docker installation

Install Docker Engine with the Compose plugin, or Docker Desktop with WSL
integration when using WSL. The `docker/` folder is self-contained and can be
copied anywhere; no host source workspaces are required.

From this repository:

```bash
cd docker
docker compose up -d --build
docker compose exec workspace bash
```

Or from any working directory:

```bash
docker compose -f /path/to/xenomai-ethercat-setup/docker/compose.yaml up -d --build
```

The three Dockerfiles build system dependencies, the non-RT EtherCAT stack,
and the ROS 2 overlay in that order. Sources are cloned inside the image and
the resulting workspaces live under `/ws`.

See the [Docker guide](docker/README.md) for GUI forwarding, dummy-master
usage, repository versions, networking, and development persistence.
