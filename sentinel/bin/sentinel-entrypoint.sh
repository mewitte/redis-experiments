#!/bin/bash
set -e

IP=$(hostname -i | awk '{print $1 }')
REDIS_DIR=${REDIS_DIR:-"/data"}
REDIS_PORT=${REDIS_PORT:-"6379"}
REDIS_MASTER_IP=${REDIS_MASTER_IP:-""}
REDIS_USER=${REDIS_USER:-""}
REDIS_PASSWORD=${REDIS_PASSWORD:-""}
SENTINEL_CLUSTER=${SENTINEL_CLUSTER:-"redis-cluster"}
SENTINEL_DOWN_AFTER=${SENTINEL_DOWN_AFTER:-"5000"}
SENTINEL_FAILOVER_TIMEOUT=${SENTINEL_FAILOVER_TIMEOUT:-"380000"}
SENTINEL_IP=${SENTINEL_IP:-""}
SENTINEL_PARALLEL_SYNCS=${SENTINEL_PARALLEL_SYNCS:-"1"}
SENTINEL_PORT=${SENTINEL_PORT:-"26379"}
SENTINEL_QUORUM=${SENTINEL_QUORUM:-"2"}
SENTINEL_USER=${SENTINEL_USER:-""}
SENTINEL_PASSWORD=${SENTINEL_PASSWORD:-""}
SENTINEL_ADMIN_USER=${SENTINEL_ADMIN_USER:-""}
SENTINEL_ADMIN_PASSWORD=${SENTINEL_ADMIN_PASSWORD:-""}


SENTINEL_ACL_FILE="/etc/redis/acl.conf"
SENTINEL_CONF_FILE="/etc/redis/sentinel.conf"

# first argument should be the command to write
function write_conf() {
  echo $1 | tee -a $SENTINEL_CONF_FILE
}

# first argument should be the username
# second argument should be the password
# third argument should be the acl configuration
function add_user() {
  echo "$1 on >$2 $3" | tee -a $SENTINEL_ACL_FILE
}

# Get current master if the initial master has perished
if [ "$(redis-cli -h $REDIS_MASTER -p $REDIS_MASTER_PORT --user $SENTINEL_USER --pass $SENTINEL_PASS ping)" = "PONG" ]; then
  echo "pinging $REDIS_MASTER on $REDIS_PORT got PONG"
else
  # Get other sentinel IPs with Docker DNS lookup
  SENTINEL_IPS=$(drill tasks.$SENTINEL_IP | grep tasks.$SENTINEL_IP | tail -n +2 | awk '{print $5}')
  for ip in $SENTINEL_IPS; do
    echo "try to get master info from $ip"
    MASTER_INFO_CMD="redis-cli -h $ip -p $SENTINEL_PORT --user $SENTINEL_USER --pass $SENTINEL_PASSWORD sentinel get-master-addr-by-name $SENTINEL_CLUSTER"
    MASTER_INFO=$($MASTER_INFO_CMD)
    if [ "$(redis-cli -h ${MASTER_INFO[0]} -p ${MASTER_INFO[1]} --user $SENTINEL_USER --pass $SENTINEL_PASSWORD ping)" = "PONG" ]; then
      export REDIS_MASTER=${MASTER_INFO[0]}
      export REDIS_PORT=${MASTER_INFO[1]}
      echo "pinging $REDIS_MASTER on $REDIS_PORT got PONG"
      break
    fi
  done
fi

# wait until master is available
if [ ! $MASTER_INFO ]; then
  until [ "$(redis-cli -h "${REDIS_MASTER}" -p "${REDIS_MASTER_PORT}" ${REDIS_USER:+--user $REDIS_USER} ping)" = "PONG" ]; do
    echo "${REDIS_MASTER} on port ${REDIS_PORT} is unavailable - sleeping"
    sleep 5
  done
fi

echo "start setting up sentinel"
echo "sentinel ip: $IP"
echo "sentinel port: $SENTINEL_PORT"
echo "redis port: $REDIS_PORT"

write_conf "bind 127.0.0.1 $IP"
write_conf "port $SENTINEL_PORT"
write_conf "dir $REDIS_DIR"

write_conf "sentinel announce-ip $IP"
write_conf "sentinel announce-port $SENTINEL_PORT"
write_conf "sentinel down-after-milliseconds $SENTINEL_DOWN_AFTER"
write_conf "sentinel failover-timeout $SENTINEL_FAILOVER_TIMEOUT"
write_conf "sentinel monitor $SENTINEL_CLUSTER $REDIS_MASTER $REDIS_PORT $REDIS_SENTINEL_QUORUM"
write_conf "sentinel parallel-syncs $SENTINEL_CLUSTER 1"

# User for master and replicas
write_conf "sentinel auth-user $SENTINEL_CLUSTER $SENTINEL_USER"
write_conf "sentinel auth-pass $SENTINEL_CLUSTER $SENTINEL_PASSWORD"

# User for other sentinel instances
write_conf "sentinel sentinel-user $SENTINEL_ADMIN_USER"
write_conf "sentinel sentinel-pass $SENTINEL_ADMIN_PASSWORD"

# Generate sentinel acl file
echo "default off" | tee $SENTINEL_ACL_FILE

# admin user for communication in between sentinels
sentinel_admin_acl_conf="allchannels +@all"
add_user $SENTINEL_ADMIN_USER $SENTINEL_ADMIN_PASSWORD $sentinel_acl_conf

# sentinel user for clients
sentinel_user_acl_conf="-@all +auth +client|getname +client|id +client|setname +command +hello +ping +role +sentinel|get-master-addr-by-name +sentinel|master +sentinel|myid +sentinel|replicas +sentinel|sentinels"
add_user  $SETNINEL_USER $SENTINEL_PASSWORD $sentinel_user_acl_conf

write_conf "aclfile $SENTINEL_ACL_FILE"

redis-sentinel $SENTINEL_CONF_FILE
