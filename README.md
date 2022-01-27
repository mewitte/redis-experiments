# Redis Experiments

In this repository I want to test redis running in containers and different functionalities of it. The tests will be run using the 6.2.6-alpine image. I will run three main experiments:

1. Running one Standalone Redis container
2. Running a sentry setup with one master, two replica and three/five sentinel nodes
3. Running the sentry setup in a swarm setting with hostnames instead of IP

## Container Toolchain

For testing the Redis setup, I will be using the `redis-cli` command. On Debian 11, install it by running `sudo apt install redis-tools`.

I use [podman](https://podman.io/) to run the containers. Podman is similar to Docker, but does not require root privileges to build and run containers and images. In Debian 11, simply run `sudo apt install podman`. You might run into issues on WSL, since it does not use systemd. Podman by default uses systemd as a cgroups manager and logs with journald, which are not available in WSL. Simply add the following file on `~/.config/containers/containers.conf` to overwrite these settings:
```yaml
[engine]
    cgroup_manager = "cgroupfs"
    events_logger = "file"
```
Or with a terminal command:
```bash
cat > ~/.config/containers/containers.conf <<EOF     
[engine]
    cgroup_manager = "cgroupfs"
    events_logger = "file"
EOF

```
