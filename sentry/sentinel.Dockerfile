FROM redis:6.2.6-bullseye

ENV SENTINEL_QUORUM 2
ENV SENTINEL_DOWN_AFTER 5000
ENV SETINEL_FAILOVER 380000

COPY sentinel.conf /etc/redis/

RUN chown redis:redis /etc/redis && \
    chmod +x /usr/local/bin/sentinel-entrypoint.sh

EXPOSE 26379
ENTRYPOINT ["sentinel-entrypoint.sh"]
