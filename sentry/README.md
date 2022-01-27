# Sentry Redis

For this experiment, I want to run one redis master, 2 redis replica and 3/5 sentinels. This should run in swarm mode, so I will need to figure out how to set the annouce-ip and announce-port for the images. I will use an overlay network called redis and use the docker swarm dns 
