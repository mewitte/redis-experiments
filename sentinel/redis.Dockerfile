FROM docker.io/redis:6.2.6-bullseye

ENV REDIS_PORT 6379
ENV REDIS_DIR "/data"

RUN apt-get update && \
    apt-get install -y \
    ldnsutils \
    dnsutils \
    nano \
    net-tools \
    wget && \
    apt-get clean

COPY bin/redis-entrypoint.sh /usr/local/bin/redis-entrypoint.sh

RUN mkdir -p /etc/redis && \
    chown -R redis:redis /etc/redis/ && \
    chmod +x /usr/local/bin/redis-entrypoint.sh

USER redis
EXPOSE 6379
ENTRYPOINT ["/usr/local/bin/redis-entrypoint.sh"]
