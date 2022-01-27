#!/bin/bash

set -e

IP=$(ifconfig | grep inet | awk '{print $2}' | cut -d ':' -f 2 | sed '/^[[:space:]]*$/d' | sed '/127.0.0.1*$/d' | head -n 1)
PORT=${REDIS_PORT:-"6379"}

setup_replica() {
    echo "Start setting up replica"

    echo "replica ip: $IP"
    echo "redis port: $PORT"

    echo "replica-announce-ip $REPLICA_ANNOUNCE_IP" >> /etc/redis/redis.conf
    echo "replica-annoucne-port ${REDIS_PORT}" >> /etc/redis/redis.conf
    echo "port $REDIS_PORT" >> /etc/redis/redis.conf
}

setup_master() {
    echo "start setting up master"
    echo "master ip: $IP"
    echo "redis port: $REDIS_PORT"

    echo "bind 127.0.0.1 $IP" >> /etc/redis/redis.conf
    echo "port $REDIS_PORT" >> /etc/redis/redis.conf
}

if [[ ${REDIS_MODE} == "master" ]]; then
    setup_master
    redis-server /etc/redis/redis.conf
elif [[ ${REDIS_MODE} == "replica" ]]; then
    setup_replica
    redis-server /etc/redis/redis.conf
else
    redis-server
fi
