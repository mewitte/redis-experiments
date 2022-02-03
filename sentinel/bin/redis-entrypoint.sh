#!/bin/bash
set -e

IP=$(hostname -i | awk '{print $1}')
REDIS_DIR=${REDIS_DIR:-"/data"}
REDIS_PORT=${REDIS_PORT:-"6379"}
REPLICA_USER={REPLICA_USER:-""}
REPLICA_USER={REPLICA_USER:-""}
SENTINEL_USER={$SENTINEL_USER:-""}
SENTINEL_PASSWORD={$SENTINEL_PASSWORD:-""}

REDIS_ACL_FILE="/etc/redis/acl.conf"
REDIS_CONF_FILE="/etc/redis/redis.conf"

# first argument should be the username
# second argument should be the password
# third argument should be the acl configuration
function add_user() {
  echo "$1 on >$2 $3" | tee -a $SENTINEL_ACL_FILE
}

# since replicas can become the master, both will get the same acl.conf
function generate_acl_conf() {
  echo "default off" | tee $REDIS_ACL_FILE

  # user for sentinel instances
  sentinel_acl_conf="allchannels +multi +slaveof +ping +exec +subscribe +config|rewrite +role +publish +info +client|setname +client|kill +script|kill"
  add_user $SENTINEL_USER $SENTINEL_PASSWORD $sentinel_acl_conf

  # user for replica instances
  replica_acl_conf="+psync +replconf +ping"
  add_user $REPLICA_USER $REPLICA_PASSWORD $replica_acl_conf

  # debug user
  add_user "admin_user" "admin_pass" "+@all"
}

# first argument should be the command to write
function write_conf() {
  echo $1 | tee -a $REDIS_CONF_FILE
}

function setup_replica() {
  # TODO
}

function setup_master() {
  echo "start setting up master"
  echo "master ip: $IP"
  echo "redis port: $REDIS_PORT"

  write_conf "bind 127.0.0.1 $IP"
  write_conf "port $REDIS_PORT"
  write_conf "dir $REDIS_DIR"

  write_conf "cluster-announce-ip $IP"
  write_conf "cluster-announce-port $REDIS_PORT"

  generate_acl_conf
  write_conf "aclfile $REDIS_ACL_FILE"
}

if [[ $REDIS_MODE == "master" ]]; then
  setup_master
  redis-server $REDIS_CONF_FILE
elif [[ $REDIS_MODE == "replica" ]]; then
  setup_replica
  redis-server $REDIS_CONF_FILE
else
  redis-server
fi
