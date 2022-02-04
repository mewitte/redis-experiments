FROM docker.io/redis:6.2.6-bullseye

ENV REDIS_DIR "/data"
ENV REDIS_PORT 6379
ENV SENTINEL_CLUSTER "redis-cluster"
ENV SENTINEL_DOWN_AFTER 5000
ENV SENTINEL_FAILOVER_TIMEOUT 380000
ENV SENTINEL_PARALLEL_SYNCS 1
ENV SENTINEL_PORT 26379
ENV SENTINEL_QUORUM 2

RUN apt-get update && \
    apt-get install -y \
    ldnsutils \
    dnsutils \
    nano \
    net-tools \
    wget && \
    apt-get clean

COPY bin/sentinel-entrypoint.sh /usr/local/bin/sentinel-entrypoint.sh

RUN mkdir -p /etc/redis && \
    chown redis:redis /etc/redis && \
    chmod +x /usr/local/bin/sentinel-entrypoint.sh

USER redis
EXPOSE 26379
ENTRYPOINT ["/usr/local/bin/sentinel-entrypoint.sh"]
