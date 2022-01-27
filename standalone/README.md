# Standalone Redis

## No changes

The standalone Redis without additional configuration does not need a separate Dockerfile. Simply run `podman run --name standalone_redis --rm --publish 6379:6379 --detach redis:6.2.6-alpine`. This starts Redis 6.2.6 and publishes the internal port 6379 to the same port externally. To test if it is up, run `redis-cli ping` and you should get a PONG back.

## Config changes

The Dockerfile basically copies the redis.conf into the container and overrides the entrypoint to use it. You can build it with `podman build -t standalone_redis:<tag> -f ./Dockerfile`. You can check it afterwards with `podman image ls` and run it with `podman run --name standlone_redis --rm --publish 6379:6379 --detach standalone_redis:<tag>`. The full configuration example with explanations can be found [here](https://raw.githubusercontent.com/redis/redis/6.2/redis.conf). Notable config options include:

* `include` statements to include other configs
* `loadmodule` to load [modules](https://redis.io/modules)
* `bind` for listening on specific interfaces, default listens only on the loopback interface, for a web setup you need to change that
* `port 6379` is the default TCP port. `port 0` won't listen on TCP
* `tls-port` can be used to enable SSL/TLS with the following configurations needed:
    * `tls-cert-file /path/to/redis.crt `
    * `tls-key-file /path/to/redis.key`
    * If the key is encrypted: `tls-key-file-pass secret`
    * If you need to split client and server certs, please read the documentation
* One of the following two directions is needed for CA settings, Redis won't use the system settings
    * `tls-ca-cert-file ca.crt`
    * `tls-ca-cert-dir /etc/ssl/certs`
* `timeout 0` is the default. If you want to close idle connections, set this value in seconds
* `pidfile /var/run/redis.pid` to set a custom pid file, default is `redis_6379.pid`
* `loglevel notice` is the default log level. The options are `debug`, `verbose`, `notice`, `warning` with decreasing verbosity
* `logfile ""` is by default logging to stdout.
* `save <seconds> <changes>` will check after <seconds> to see if a number of <changes> changes occured and write to a file specified with `dbfilename dump.rdb` in the directory specified with `dir ./`
* `replicaof <masterip> <masterport>`
* `masteruser user` when using 
* `masterauth password`
* `replica-serve-stale-data yes`
