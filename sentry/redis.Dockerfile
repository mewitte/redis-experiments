FROM docker.io/redis:6.2.6-bullseye

RUN apt-get update && \
    apt-get install -y \
    net-tools

COPY conf/redis.conf /etc/redis/redis.conf
COPY conf/redis-acl.conf /etc/redis/redis-acl.conf
COPY bin/redis-entrypoint.sh /usr/local/bin/redis-entrypoint.sh

RUN chown redis:redis /etc/redis/ && \
    chmod +x /usr/local/bin/redis-entrypoint.sh

USER redis
ENTRYPOINT ["/usr/local/bin/redis-entrypoint.sh"]
