#!/bin/bash
nowDate=$(date +"%Y-%m-%d %H:%M:%S %Z")
echo $nowDate
imageName=debian:bookworm-slim
baseComposeUrl="https://github.com/mahaliabpqvn07/uam-docker/raw/main/uam-swarm"
sudo chmod 666 /var/run/docker.sock


docker rm -f $(docker ps -aq --filter ancestor=debian:bookworm-slim)
docker rm -f $(docker ps -aq --filter ancestor=tuanna9414/uam:latest)
file_name=2-docker-compose.yml && sudo rm -rf entrypoint.sh && sudo rm -rf $file_name
wget https://cdn.jsdelivr.net/gh/mahaliabpqvn07/uam-docker@main/uam-swarm/$file_name
wget https://cdn.jsdelivr.net/gh/mahaliabpqvn07/uam-docker@main/uam-swarm/entrypoint.sh
PBKEY=53F57E23ACBBA1F843F481C545549ECB9371CC05FD62AA74FAC6CD8D70AA0E4C docker-compose -f $file_name up -d --no-recreate
