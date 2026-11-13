# Miranda development workspace

Three Dockerfiles follow this build order:

```text
Dockerfile.dependencies → Dockerfile.ethercat → Dockerfile.ros
```

Compose declares the image dependencies and builds them in that order. The files you need to understand are:

| File | Purpose |
| --- | --- |
| `Dockerfile.dependencies` | Install ROS build tools, system libraries, Gazebo, and XBot (momentarily) |
| `Dockerfile.ethercat` | Install the master and build the EtherCAT libraries and GUI |
| `Dockerfile.ros` | Build the ROS workspace and seed dummy defaults |
| `colcon.meta` | Container paths and non-RT ROS build settings |
| `setup.bash` | Load the environment in container shells |
| `compose.yaml` | Build and run the container, including networking and display forwarding |

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

**Note:** Build parallelism defaults to four jobs to limit memory use. Override it with
`BUILD_JOBS=8 docker compose build`.


`docker compose exec` should use
`bash -ic 'command'` when running a ROS command directly, for example:

```bash
docker compose exec workspace bash -ic 'ros2 pkg list'
```

The entrypoint and every interactive Bash shell load ROS, XBot, EtherCAT,
Miranda configuration, and the ROS overlay. 

Stop with:

```bash
docker compose down
```