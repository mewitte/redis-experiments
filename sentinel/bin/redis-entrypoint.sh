#!/bin/bash
set -e

IP=$(hostname -i | awk '{print $1}')
REDIS_DIR=${REDIS_DIR:-"/data"}
REDIS_PORT=${REDIS_PORT:-"6379"}
SENTINEL_PORT=${SENTINEL_PORT:-"26379"}
SENTINEL_CLUSTER=${SENTINEL_CLUSTER:-"redis-cluster"}

REDIS_ACL_FILE="/etc/redis/acl.conf"
REDIS_CONF_FILE="/etc/redis/redis.conf"

# first argument should be the username
# second argument should be the password
# third argument should be the acl configuration
function add_user() {
  echo "user $1 on >$2 $3" | tee -a $REDIS_ACL_FILE
}

# since replicas can become the master, both will get the same acl.conf
function generate_acl_conf() {
  echo "user default off" | tee $REDIS_ACL_FILE

  # user for sentinel instances
  sentinel_acl_conf="allchannels +multi +slaveof +ping +exec +subscribe +config|rewrite +role +publish +info +client|setname +client|kill +script|kill"
  add_user "${SENTINEL_USER}" "${SENTINEL_PASSWORD}" "${sentinel_acl_conf}"

  # user for replica instances
  replica_acl_conf="+psync +replconf +ping"
  add_user "${REPLICA_USER}" "${REPLICA_PASSWORD}" "${replica_acl_conf}"

  # debug user
  add_user "admin_user" "admin_pass" "+@all"

  write_conf "aclfile $REDIS_ACL_FILE"
}

# first argument should be the command to write
function write_conf() {
  echo $1 | tee -a $REDIS_CONF_FILE
}

function generate_redis_conf() {
  echo "redis ip: $IP"
  echo "redis port: $REDIS_PORT"

  write_conf "dir $REDIS_DIR"
  write_conf "port $REDIS_PORT"
  write_conf "protected-mode no"
}

function get_master_info() {
  local MASTER_INFO_CMD="redis-cli -h $SENTINEL_IP -p $SENTINEL_PORT --user $SENTINEL_USER --pass $SENTINEL_PASSWORD sentinel get-master-addr-by-name $SENTINEL_CLUSTER"

  until [ "$(redis-cli -h $SENTINEL_IP -p $SENTINEL_PORT --user $SENTINEL_USER --pass $SENTINEL_PASSWORD ping)" = "PONG" ]; do
    echo "$SENTINEL_IP is unavailable - trying again in 5 seconds"
    sleep 5
  done

  MASTER_INFO=($($MASTER_INFO_CMD))
  until [ "$MASTER_INFO" ]; do
    echo "master info not found yet for cluster $SENTINEL_CLUSTER - waiting 5 seconds"
    sleep 5
    MASTER_INFO=($($MASTER_INFO_CMD))
  done

  REDIS_MASTER_IP=${MASTER_INFO[0]}
}

function generate_replica_conf() {
  write_conf "replica-announce-ip $IP"
  write_conf "replica-announce-port $REDIS_PORT"
  write_conf "save 60 10000"
  write_conf "replicaof $REDIS_MASTER_IP $REDIS_PORT"

  write_conf "masteruser $REPLICA_USER"
  write_conf "masterauth $REPLICA_PASSWORD"

  echo "Replicating $REDIS_MASTER_IP:$REDIS_PORT"
}

function setup_replica() {
  echo "start setting up replica"

  generate_redis_conf
  generate_acl_conf
  get_master_info
  generate_replica_conf
}

function setup_master() {
  echo "start setting up master"

  generate_redis_conf
  generate_acl_conf
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
