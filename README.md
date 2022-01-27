# Redis Experiments

In this repository I want to test redis running in containers and different functionalities of it. The tests will be run using the 6.2.6-bullseye image. This is what I want to try:

1. Running one Standalone Redis container
2. (HA setup) Running a sentry setup with one master, two replica and three/five sentinel nodes in swarm mode with no added configuration

## Container Toolchain

For testing the Redis setup, I will be using the `redis-cli` command. On Debian 11, install it by running `sudo apt install redis-tools`.

I use [podman](https://podman.io/) to run the containers. Podman is similar to Docker, but does not require root privileges to build and run containers and images. In Debian 11, simply run `sudo apt install podman`. You might run into issues on WSL, since it does not use systemd.

To add [podman autocompletion](https://github.com/containers/podman/blob/main/docs/source/markdown/podman-completion.1.md) for zsh, run

```bash
echo "autoload -U compinit; compinit" >> ~/.zshrc # just run this if you didn't already enable it in your .zshrc
podman completion -f "${fpath[1]}/_podman" zsh # this does not need to be in your .zshrc
```

Podman by default uses systemd as a cgroups manager and logs with journald, which are not available in WSL. Simply add the following file on `~/.config/containers/containers.conf` to overwrite these settings:
```yaml
[engine]
    cgroup_manager = "cgroupfs"
    events_logger = "file"
```
Or with a terminal command:
```bash
mkdir -p ~/.config/containers
cat > ~/.config/containers/containers.conf <<EOF
[engine]
    cgroup_manager = "cgroupfs"
    events_logger = "file"
EOF

```

Podman does not automatically resolve unqualified search names like redis:latest. You can either use fully qualified search names like docker.io/redis:latest or run the following to add docker.io as a host to resolve unqualified search names:

```bash
echo "unqualified-search-registries = ['docker.io']" | sudo tee /etc/containers/registries.conf
```

## Docker Lab Environment

Podman can run the standalone setup just fine. To get a real docker swarm I use [Play with Docker](https://labs.play-with-docker.com/). This gives you a sandbox environment to play with docker server. The website will give you 4 hours to play around. On the top left, next to instances, you can click on the wrench and start a 5 manager node cluster from a template. This will also give you an ssh link to connect from a shell.
