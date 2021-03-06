# Sentinel Redis

For this experiment, I want to run one redis master, 2 redis replica and 3/5 sentinels. This should run in swarm mode, so I will need to figure out how to set the annouce-ip and announce-port for the images. I will use an overlay network called redis and use the docker swarm. The basic idea of the setup is the following:

We will start a master node `redis_master`. This node will be reachable in the cluster by the DNS Name `master`. The sentinel nodes (reachable by cluster DNS `sentinel`) will then monitor the master. The replicas will use sentinels `sentinel get-master-addr-by-name sentinel-cluster` command to get the master's IP and port. They will then use this information to start replicating it. This ensures that, if the initial master is down, the replica can still join the sentinel cluster. Replication starts in a read-only mode.

After the initial setup is done, there is the option to remove the initial master node, so that one of the replicas will become the master. With this setup you can scale up the replicas by one and have one less service on your cluster. If a master fails and gets restarted by docker, it will also automatically rejoin the replicas.

Redis will log `redis mode: standalone` on the master. This will only change for sentinels or if multiple masters run together as a redis cluster. 

## Variables

* `IP`=$(hostname -i | awk '{print $1 }') discovers the IP of the instance inside the docker network and is used for all instances. Might behave differently if the instance is part of two networks

The other variables can be overwritten by setting them in the environment section of the service in the stack file. Users and `SENTINEL_IP` and `REDIS_MASTER_IP` need to be set since they do not have defaults declared.

### Master and Replica variables

Functional parameters:
* `REDIS_MODE`: either `master` or `replica` for their function
* `REDIS_DIR`: dictionary for redis data
* `REDIS_PORT`: port for redis master and replica instances
* `SENTINEL_IP`: sentinel service name without the stack name (`sentinel` in this case, not `redis_sentinel`)
* `SENTINEL_PORT`: port for sentinel instances

Users (see ACL below for more infos):
* `SENTINEL_USER` and `SENTINEL_PASSWORD`: user for sentinel instances to authenticate on the master instances and for replica instances to authenticate on the sentinels
* `REPLICA_USER` and `REPLICA_PASSWORD`: user for replica instances to authenticate on the master and sentinel instance

### Sentinel variables

Functional parameters:
* `REDIS_MASTER_IP`: inital master's service name (without the stack name in front. So `master` in this case, not `redis_master`)
* `REDIS_DIR`: dictionary for redis data
* `REDIS_PORT`: port for redis master and replica instances
* `SENTINEL_CLUSTER`: sentinel cluster name
* `SENTINEL_DOWN_AFTER`: time in ms after which sentinel sends a `+sdown` message, indicating that it no longer can reach the master
* `SENTINEL_FAILOVER_TIMEOUT`: timeout in ms after which the failover process fails
* `SENTINEL_PARALLEL_SYNCS`: number of replicas that can sync with the master at the same time
* `SENTINEL_PORT`: port for sentinel instances
* `SENTINEL_QUORUM`: quorum needed (+sdown messages received) to start the failover process

Users (see ACL below for more infos):
* `SENTINEL_USER` and `SENTINEL_PASSWORD`: sentinel user on replica and master instances. In this configuration, it doubles as the authentication user for clients trying to access the database over sentinel instances
* `SENTINEL_ADMIN_USER` and `SENTINEL_ADMIN_PASSWORD`: sentinel admin user to communicate with other sentinel instances

## Protected Mode

In Redis, there is a setting for [protected mode](https://redis.io/topics/security). If enabled Redis will only allow connections on the loopback interfaces. This must be turned off (`protected-mode no` in redis.conf) for the docker swarm environment, since we will be using DNS names for discovering the IPs and accessing the Redis instances over a different interface. If enabled, the instances will initally allow the connection, but for Sentinel, they will get disconnected from each other after some time. Security is managed by ACL and the default user being turned off.

## ACL

Since version 6, redis supports authentication via an [ACL](https://redis.io/topics/acl). The sentinel instances have different required users compared to the master and replica instances. They are read from environment variables. You can use Docker Swarm Secrets to protect those variables. Another option is to add the ACL as a file via Docker Secrets. I decided against that and write the ACL file dynamically since I would need to keep the ACL file and the secret for the users up to date in two different secrets.

### Sentinel

According to the documentation [Configuring Sentinel instances with authentication](https://redis.io/topics/sentinel#configuring-sentinel-instances-with-authentication) sentinel will need two users in it's ACL:
* One admin user to communicate with other sentinel instances. This user should have the same name and password on all sentinel instances and use the following acl rules: `allchannels +@all`
* One sentinel user which authenticates incoming client connections with the following acl rules: `-@all +auth +client|getname +client|id +client|setname +command +hello +ping +role +sentinel|get-master-addr-by-name +sentinel|master +sentinel|myid +sentinel|replicas +sentinel|sentinels`

### Master and Replicas

Following the section [ACL rules for Sentinel and Replicas](https://redis.io/topics/acl#acl-rules-for-sentinel-and-replicas), the master needs two users, one for replica instances and one for sentinel instances. The master does not need a dedicated user since

> the master is always authenticated as the root user from the point of view of replicas.

Since any replica can take over as the new master, both master and replicas will have the same acl file with two users:
* One replica user that only allows replication and synchronization with the following acl rules: `+psync +replconf +ping`
* One sentinel user with the following acl rules: `+multi +slaveof +ping +exec +subscribe +config|rewrite +role +publish +info +client|setname +client|kill +script|kill`

### Control

There will be a service called `redis_control`. This will be used to run redis-cli checks from inside the network. This service does not need any acl configured, as it is only used for using the `redis-cli` command to run checks and simulate an outside container accessing redis.

## Building and publishing images

I created a repository on hub.docker.com for my images with the account name `mewitte1`. This allows me to use podman for building and deploy the service to a sandbox server on [Play with Docker](https://labs.play-with-docker.com/). First, login to the docker registry of your choice (`podman login docker.io` for me). Creating an image has the following workflow:

```bash
TAG=1
podman build -t mewitte1/redis-experiment:$TAG -t mewitte1/redis-experiment:latest . -f redis.Dockerfile
podman push mewitte1/redis-experiment:$TAG
podman push mewitte1/redis-experiment # this will automatically push the latest tag
```

```bash
TAG=1
podman build -t mewitte1/redis-experiment-sentinel:$TAG -t mewitte1/redis-experiment-sentinel:latest . -f sentinel.Dockerfile
podman push mewitte1/redis-experiment-sentinel:$TAG
podman push mewitte1/redis-experiment-sentinel # this will automatically push the latest tag
```

## Docker Swarm setup

We will need to first initalize the swarm and then create the redis network. I use [Play with Docker](https://labs.play-with-docker.com/) for my swarm deployment. It is really easy to use, you can create a 5 manager nodes swarm on ubuntu instances with two clicks. To deploy the stackfile on there, we need to go through the following steps (get the scp user and host from the ssh copy/paste):

```bash
# on your machine
scp redis-stack.yml ip172-18-0-51-c83u3ilmrepg008d8ti0@direct.labs.play-with-docker.com:~/
ssh ip172-18-0-51-c83u3ilmrepg008d8ti0@direct.labs.play-with-docker.com
```

If scp does not work, use `touch redis-stack.yml` to create a file and use the Editor button above the command line on the website to paste your file in.

```bash
# then on the machine
docker network create -d overlay redis
docker stack deploy -c redis-stack.yml redis
```

Then get the node that the control is running on with
```bash
docker service ps redis_control
exit # run the rest on the website, ssh consoles tend to go unresponsive
```

and go to that manager. You can connect to the container with

```bash
docker exec -it redis_control.1... bash # use tab for autocomplete on the container name
```

Then you can test the connection with

```bash
redis-cli -h master --user replica-user --pass replica-pass ping # should give PONG
```

If you want to try out a new configuration with a different build:
