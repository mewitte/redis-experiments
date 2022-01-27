FROM docker.io/redis:6.2.6-bullseye

ENV REDIS_PORT=${REDIS_PORT:-6379}

RUN apt-get update && \
    apt-get install -y \
    ldnsutils \
    dnsutils \
    net-tools \
    wget && \
    apt-get clean

COPY conf/redis.conf /etc/redis/redis.conf
COPY conf/redis-acl.conf /etc/redis/redis-acl.conf
COPY bin/redis-entrypoint.sh /usr/local/bin/redis-entrypoint.sh

RUN chown -R redis:redis /etc/redis/ && \
    chmod +x /usr/local/bin/redis-entrypoint.sh

USER redis
EXPOSE 6379
ENTRYPOINT ["/usr/local/bin/redis-entrypoint.sh"]
