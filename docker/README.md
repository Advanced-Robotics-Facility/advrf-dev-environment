# Miranda development workspace

Three Dockerfiles follow this build order:

```text
Dockerfile.dependencies → Dockerfile.ethercat → Dockerfile.ros
```

Compose declares the image dependencies and builds them in that order. The files you need to understand are:

| File | Purpose |
| --- | --- |
| `Dockerfile.dependencies` | Install ROS build tools, system libraries, and Gazebo |
| `Dockerfile.ethercat` | Install the master and build the EtherCAT libraries and GUI |
| `Dockerfile.ros` | Build the ROS workspace and seed dummy defaults |
| `colcon.meta` | Container paths and non-RT ROS build settings |
| `setup.bash` | Load the environment in container shells |
| `compose.build.yaml` | Build the three images in dependency order |
| `compose.yaml` | Run the workspace, including networking and display forwarding |

## Build and open a shell

From this folder:

```bash
cd /path/to/docker
docker compose -f compose.build.yaml build workspace
docker compose up -d
docker compose exec workspace bash
```

Or run from any working directory:

```bash
docker compose -f /path/to/docker/compose.build.yaml build workspace
docker compose -f /path/to/docker/compose.yaml up -d
```

Build parallelism defaults to the CPU count available inside the build container
(`nproc`). Override it with
`BUILD_JOBS=8 docker compose -f compose.build.yaml build workspace`.

For a build without cached layers:

```bash
docker compose -f compose.build.yaml build --no-cache workspace
```

The runtime file has no build configuration or profiles. `docker compose up -d`
uses the existing workspace image; build it first with the build file above.


`docker compose exec` should use
`bash -ic 'command'` when running a ROS command directly, for example:

```bash
docker compose exec workspace bash -ic 'ros2 pkg list'
```

The entrypoint and every interactive Bash shell load ROS, EtherCAT,
Miranda configuration, and the ROS overlay. 

Stop with:

```bash
docker compose down
```