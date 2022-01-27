# Sentry Redis

For this experiment, I want to run one redis master, 2 redis replica and 3/5 sentinels. This should run in swarm mode, so I will need to figure out how to set the annouce-ip and announce-port for the images. I will use an overlay network called redis and use the docker swarm. The basic idea of the setup is the following:

We will start a master node `redis_master`. This node will be reachable in the cluster by the DNS Name `master`. THe sentinel nodes (reachable by cluster DNS `sentinel`) will then monitor the master. The replicas will use sentinels `SENTINEL get-master-addr-by-name sentinel-cluster` command to get the master's IP and port. They will then use this information to start replicating it. After the initial setup is done, there is the option to remove the initial master node, so that one of the replicas will become the master. With this setup you can scale up the replicas by one and have one less service on your cluster. If a master fails and gets restarted by docker, it will also automatically rejoin the replicas.

## Building and publishing images

I created a repository on hub.docker.com for my images with the account name `mewitte1`. This allows me to use podman for building and deploy the service to a sandbox server on [Play with Docker](https://labs.play-with-docker.com/) Creating an image has the following workflow:

```bash
podman login docker.io
TAG=0.1
podman build -t mewitte1/redis-experiment:$TAG -t mewitte1/redis-experiment:latest . -f redis.Dockerfile
podman push mewitte1/redis-experiment:$TAG
podman push mewitte1/redis-experiment # this will automatically push the latest tag
```

There will be a service called `redis_control`. This will be used to run redis-cli checks from inside the network. My aim is to test redis as a database for services running in a swarm.

## Docker Swarm setup

We will need to first initalize the swarm and then create the redis network. I use [Play with Docker](https://labs.play-with-docker.com/) for my swarm deployment. It is really easy to use, you can create a 5 manager nodes swarm on ubuntu instances with two clicks. To deploy the stackfile on there, we need to go through the following steps (get the scp user and host from the ssh copy/paste):

```bash
# on your machine
scp redis-stack.yml ip172-18-0-62-c7phlc7njsv000aihia0@direct.labs.play-with-docker.com:~/
ssh ip172-18-0-62-c7phlc7njsv000aihia0@direct.labs.play-with-docker.com
```

```bash
# then on the machine
docker network create -d overlay redis
docker stack deploy -c redis-stack.yml redis
```

Then get the node that the control is running on with
```bash
docker service ps redis_container
exit # run the rest on the website, ssh consoles tend to go unresponsive
```

and go to that manager. You can connect to the container with

```bash
docker exec -it control.1... bash # use tab for autocomplete on the container name
```

Then you can test the connection with

```bash
redis-cli -h master --user redis-user --pass redis-pass ping # should give PONG
```
