#!/bin/bash

setup_replica() {
    echo "Start setting up replica"

    REPLICA_ANNOUNCE_IP = $(ifconfig | grep inet | awk '{print $2}' | cut -d ':' -f 2 | sed '/^[[:space:]]*$/d' | sed '/127.0.0.1*$/d')
    REDIS_PORT=${REDIS_PORT:-"6379"}

    echo "REPLICA_ANNOUNCE_IP: $REPLICA_ANNOUNCE_IP"
    echo "REDIS_PORT: $REDIS_PORT"

    echo "replica-announce-ip $REPLICA_ANNOUNCE_IP" >> /etc/redis/redis.conf
    echo "replica-annoucne-port ${REDIS_PORT}" >> /etc/redis/redis.conf
    echo "port $REDIS_PORT" >> /etc/redis/redis.conf
}

setup_master() {
    echo "start setting up master"
    echo "REDIS_PORT: $REDIS_PORT"

    echo "port $REDIS_PORT" >> /etc/redis/redis.conf
}

if [[ ${REDIS_MODE} == "master" ]]; then
    setup_master
    redis-server /etc/redis/redis.conf
else
    setup_replica
    redis-server /etc/redis/redis.conf
fi
